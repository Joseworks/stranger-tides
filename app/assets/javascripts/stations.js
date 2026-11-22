/* global google, Highcharts */
(() => {
  'use strict';
  let stations = [], filtered = [], visibleCount = 100, map, infoWindow, spread, markers = new Map();
  let selected, report, pending, generation = 0, chart, savedFocus;
  const weatherCharts = new Map();
  let lastLayer = 'waterlevels';
  let measurementLimit = 1000;
  const extras = station => (station.additional_products || []).length > 0;
  const productUnits = product => window.StationExtras.products(report.units === 'metric')[product]?.[1] || '';
  const byId = id => document.getElementById(id);
  const text = (id, value) => { byId(id).textContent = value; };
  const capabilities = station => station.capabilities || ['waterlevels'];
  const stationLabel = station => station.state && !station.station_name.endsWith(`, ${station.state}`) ? `${station.station_name}, ${station.state}` : station.station_name;
  const zone = () => byId('display-zone').value === 'station' ? report?.station_timezone || 'UTC' :
    byId('display-zone').value === 'utc' ? 'UTC' : Intl.DateTimeFormat().resolvedOptions().timeZone;
  const date = (value, timeZone = zone()) => new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short', timeZone }).format(new Date(value));
  const quality = value => ({ p: 'Preliminary', v: 'Verified' }[value] || 'Quality not provided');
  const unit = () => (report?.units || byId('height-units').value) === 'metric' ? 'm' : 'ft';
  function element(tag, value, className) {
    const node = document.createElement(tag); node.textContent = value;
    if (className) node.className = className;
    return node;
  }
  function clearChart() {
    if (chart) chart.destroy();
    chart = null; window.chart_graph_partial = null;
    byId('graph-partial').replaceChildren();
    weatherCharts.forEach(weatherChart => weatherChart.destroy()); weatherCharts.clear();
    byId('weather-charts').replaceChildren(); byId('weather-charts').hidden = true;
  }
  function numeric(value) {
    const number = value === null || value === undefined || value === '' ? null : Number(value);
    return Number.isFinite(number) ? number : null;
  }
  function observedPoints(values, field = 'value') {
    const points = [];
    values.forEach((point, index) => {
      const previous = values[index - 1];
      if (previous && point.timestamp - previous.timestamp > 6 * 60000) {
        points.push([previous.timestamp + 6 * 60000, null]);
      }
      points.push([point.timestamp, numeric(point[field])]);
    });
    return points;
  }
  function updateUrl() {
    const url = new URL(window.location.href);
    for (const [key, value] of Object.entries({ station: selected?.station_id, hours: byId('history-hours').value,
      future_hours: byId('future-hours').value, units: byId('height-units').value, zone: byId('display-zone').value })) {
      if (value) url.searchParams.set(key, value); else url.searchParams.delete(key);
    }
    window.history.replaceState(null, '', url);
  }
  function renderResults() {
    const search = byId('station-search').value.trim().toLocaleLowerCase();
    const layer = byId('station-layer').value;
    if (layer !== 'additional') lastLayer = layer;
    byId('extra-products-toggle').setAttribute('aria-pressed', String(layer === 'additional'));
    filtered = stations.filter(s => (layer === 'all' || (layer === 'additional' ? extras(s) : capabilities(s).includes(layer))) &&
      `${s.station_name} ${s.station_id} ${s.state || ''}`.toLocaleLowerCase().includes(search));
    text('result-count', `${filtered.length} matching locations`);
    byId('station-results').replaceChildren(...filtered.slice(0, visibleCount).map(s => {
      const item = document.createElement('li'); const button = element('button', `${stationLabel(s)} ${s.station_id}`);
      button.type = 'button'; button.classList.toggle('extra-products', extras(s)); button.dataset.stationId = s.station_id;
      button.append(element('small', `${s.state || ''} · ${capabilities(s).includes('waterlevels') ? 'Water-level observations' : 'Prediction / weather location'}`));
      if (extras(s)) button.append(element('small', `Additional: ${s.additional_products.map(p => p.replaceAll('_', ' ')).join(', ')}`, 'extra-label'));
      button.addEventListener('click', () => selectStation(s)); item.append(button); return item;
    }));
    byId('more-stations').hidden = filtered.length <= visibleCount;
    renderMarkers(true);
  }
  function renderMarkers(force = false) {
    if (!map) return;
    if (force) spread?.close();
    const bounds = map.getBounds?.();
    const visible = filtered.filter(s => !bounds || bounds.contains({lat: Number(s.latitude), lng: Number(s.longitude)}));
    const ids = new Set(visible.map(s => s.station_id));
    markers.forEach((marker, id) => {
      if (!ids.has(id)) {if (marker.setMap) marker.setMap(null); else marker.map = null; markers.delete(id);}
    });
    visible.forEach(station => {
      if (markers.has(station.station_id)) return;
      const hasExtras = extras(station), title = `${stationLabel(station)} ${station.station_id}`;
      const position = {lat: Number(station.latitude), lng: Number(station.longitude)};
      const advanced = byId('full_map').dataset.mapId && google.maps.marker?.AdvancedMarkerElement;
      let marker;
      if (advanced) {
        const content = element('button', hasExtras ? '+' : '●', `map-pin individual-pin${hasExtras ? ' extra-pin' : ''}`);
        content.type = 'button'; content.setAttribute('aria-label', title);
        marker = new google.maps.marker.AdvancedMarkerElement({map, position, title, content, zIndex: hasExtras ? 1000 : 1});
      } else {
        marker = new google.maps.Marker({map, position, title, optimized: false, zIndex: hasExtras ? 1000 : 1,
          icon: hasExtras ? byId('full_map').dataset.extraMarkerIcon : byId('full_map').dataset.markerIcon});
      }
      marker.addListener('click', () => spread.open(station, filtered));
      markers.set(station.station_id, marker);
    });
  }
  window.initMap = () => {
    try {
      map = new google.maps.Map(byId('full_map'), { center: { lat: 38.88, lng: -98.35 }, zoom: 3,
        ...(byId('full_map').dataset.mapId ? { mapId: byId('full_map').dataset.mapId } : {}) });
      infoWindow = new google.maps.InfoWindow({disableAutoPan: true});
      spread = window.StationSpread.create({map, host: byId('full_map'), label: stationLabel, extras,
        select: station => selectStation(station, {preserveViewport: true})});
      positionSelectedStation();
      map.addListener?.('idle', () => renderMarkers());
      byId('map-status').hidden = true; renderMarkers(true);
    } catch (_) { text('map-status', 'The map is unavailable. Use the station list to explore data.'); }
  };
  window.gm_authFailure = () => { byId('map-status').hidden = false; text('map-status', 'The map is unavailable. Use the station list to explore data.'); };
  function positionSelectedStation({preserveViewport = false} = {}) {
    if (!map || !selected) return;
    const position = { lat: Number(selected.latitude), lng: Number(selected.longitude) };
    if (!preserveViewport) {map.setCenter(position); map.setZoom(8);}
    infoWindow.setContent(element('div', `${stationLabel(selected)} · ${selected.station_id}`));
    infoWindow.setPosition?.(position); infoWindow.open(map);
  }
  function selectStation(station, {preserveViewport = false} = {}) {
    spread?.close();
    measurementLimit = 1000; byId('observations-table').open = false;
    savedFocus = document.activeElement; selected = station; report = null; window.StationExtras.reset(); updateStationZone();
    byId('station-panel').hidden = false; text('station-heading', `${stationLabel(station)} ${station.station_id}`);
    byId('noaa-station-link').href = `https://tidesandcurrents.noaa.gov/stationhome.html?id=${encodeURIComponent(station.station_id)}`;
    positionSelectedStation({preserveViewport});
    const heading = byId('station-heading'), bounds = heading.getBoundingClientRect();
    if (bounds.top >= 0 && bounds.bottom <= window.innerHeight) heading.focus({ preventScroll: true });
    updateUrl(); loadReport();
  }
  async function loadReport() {
    pending?.abort(); const token = ++generation; pending = new AbortController();
    const updating = Boolean(report);
    if (!updating) {
      clearChart(); byId('station-summary').replaceChildren(); byId('measurement-rows').replaceChildren();
      byId('observations-table').hidden = true;
    }
    byId('retry-report').hidden = true;
    byId('station-charts').setAttribute('aria-busy', 'true');
    text('report-status', updating ? 'Updating station charts…' : 'Loading NOAA station data…');
    try {
      const params = new URLSearchParams({ hours: byId('history-hours').value, future_hours: byId('future-hours').value, units: byId('height-units').value });
      const response = await fetch(`/stations/${encodeURIComponent(selected.station_id)}/report?${params}`, { signal: pending.signal });
      if (!response.headers.get('content-type')?.includes('application/json')) throw new Error('Station data is unavailable. Please try again.');
      const payload = await response.json();
      if (token !== generation) return;
      if (!response.ok) throw new Error(payload.error || 'Station data is unavailable.');
      report = payload; renderReport();
    } catch (error) {
      if (error.name === 'AbortError' || token !== generation) return;
      text('report-status', `${error.message || 'Station data is unavailable. Please try again.'}${updating ? ' Previous charts are still displayed.' : ''}`);
      byId('retry-report').hidden = false;
    } finally { if (token === generation) byId('station-charts').removeAttribute('aria-busy'); }
  }
  function renderWeatherCharts() {
    const metric = report.units === 'metric';
    const products = window.StationExtras.products(metric);
    const available = Object.entries(report.weather_series || {}).filter(([product, values]) =>
      products[product] && values.some(point => point.value !== null ||
        (product === 'wind' && (numeric(point.gust) !== null || numeric(point.direction) !== null))));
    const active = new Set(available.map(([product]) => product));
    weatherCharts.forEach((weatherChart, product) => {
      if (!active.has(product)) { weatherChart.destroy(); byId(`weather-${product}`).remove(); weatherCharts.delete(product); }
    });
    byId('weather-charts').hidden = !available.length;
    available.forEach(([product, values]) => {
      const [title, units] = products[product];
      const series = [{ id: product, name: title, data: observedPoints(values), connectNulls: false }];
      const axes = [{ id: 'measurement', title: { text: `${title} (${units})` } }];
      if (product === 'wind') {
        const gusts = observedPoints(values, 'gust');
        if (gusts.some(point => point[1] !== null)) series.push({ id: 'gust', name: 'Wind gust', data: gusts, connectNulls: false });
        const directions = observedPoints(values, 'direction').filter(point => point[1] !== null);
        if (directions.length) {
          axes.push({ id: 'direction', title: { text: 'Direction (°)' }, opposite: true, min: 0, max: 360, tickInterval: 90 });
          series.push({ id: 'direction', name: 'Wind direction', type: 'scatter', yAxis: 'direction',
            data: directions, tooltip: { valueSuffix: '°' }, marker: { radius: 2 } });
        }
      }
      const options = {
        chart: { type: 'line', animation: false, height: 300 }, title: { text: title },
        subtitle: { text: `Past ${report.hours} hours · ${stationLabel(selected)}` }, time: { timezone: zone() },
        xAxis: { type: 'datetime' }, yAxis: axes,
        tooltip: { xDateFormat: '%e %b %Y %H:%M', valueSuffix: ` ${units}` },
        credits: { enabled: false }, series
      };
      const existing = weatherCharts.get(product);
      if (existing) existing.update(options, true, true, false);
      else {
        const node = document.createElement('div'); node.id = `weather-${product}`;
        node.className = 'weather-chart'; node.dataset.product = product; node.setAttribute('aria-label', `${title} history`);
        byId('weather-charts').append(node); weatherCharts.set(product, Highcharts.chart(node, options));
      }
    });
  }
  function updateNextEvents() {
    if (!report || !byId('next-events')) return;
    const next = report.events.filter(point => point.value !== null && Date.parse(point.time) >= Date.now());
    const nodes = ['H', 'L'].flatMap(type => {
      const event = next.find(point => point.type === type);
      return event ? [element('p', `Next predicted ${type === 'H' ? 'high' : 'low'}: ${date(event.time)} · ${event.value.toFixed(2)} ${unit()}`)] : [];
    });
    if (report.events.length && !nodes.length) {
      nodes.push(element('p', 'Upcoming predictions have passed. Refresh station data for the next events.', 'muted'));
      byId('retry-report').hidden = false;
    }
    byId('next-events').replaceChildren(...nodes);
  }
  function updateFreshness() {
    updateNextEvents();
    if (!report?.latest || !byId('reading-age')) return;
    const age = Math.max(0, Math.floor((Date.now() - Date.parse(report.latest.time)) / 60000));
    text('reading-age', `Observed ${date(report.latest.time)} · ${age} minutes ago`);
    const stale = Date.parse(report.latest.time) < Date.now() - 18 * 60000;
    byId('reading-freshness').hidden = !stale;
    text('reading-freshness', stale ? 'This observation is now stale. Check timestamps before using these data.' : '');
  }
  function renderMeasurements() {
    if (!report || !byId('observations-table').open) return;
    const products = [
      { name: 'Observed water level', values: report.observations, units: unit() },
      { name: 'Predicted water level', values: report.predictions, units: unit(), predicted: true },
      { name: 'Future tide prediction', values: report.future_predictions || [], units: unit(), predicted: true },
      { name: 'Observed minus predicted', values: report.differences || [], units: unit() },
      ...Object.entries(report.weather_series || {}).map(([product, values]) => ({
        name: product.replaceAll('_', ' '), values, units: productUnits(product)
      })),
      ...['gust', 'direction'].flatMap(field => {
        const values = report.weather_series?.wind || [];
        return values.some(point => numeric(point[field]) !== null) ? [{
          name: field === 'gust' ? 'Wind gust' : 'Wind direction',
          units: field === 'direction' ? '°' : report.units === 'metric' ? 'm/s' : 'knots',
          values: values.map(point => ({ ...point, value: numeric(point[field]) }))
        }] : [];
      })
    ];
    const rows = products.flatMap(product => product.values.map(point => ({ ...product, point })))
      .sort((a, b) => a.point.timestamp - b.point.timestamp);
    text('measurement-page', `Showing ${Math.min(rows.length, measurementLimit)} of ${rows.length} measurements.`);
    byId('more-measurements').hidden = rows.length <= measurementLimit;
    byId('measurement-rows').replaceChildren(...rows.slice(0, measurementLimit).map(({ name, units, predicted, point }) => {
      const row = document.createElement('tr');
      const event = predicted ? ({ H: 'High', L: 'Low' }[point.type] || 'Prediction') : quality(point.quality);
      row.append(element('td', date(point.time)), element('td', name), element('td', point.value === null ? 'Missing' : `${point.value} ${units}`), element('td', event));
      return row;
    }));
  }
  function updateStationZone() {
    const option = byId('display-zone').querySelector('option[value="station"]');
    option.disabled = !report?.station_timezone;
    option.textContent = report?.station_timezone ? `Station local time (${report.station_timezone})` :
      report ? 'Station local time unavailable (UTC)' : 'Station local time';
  }
  function renderReport() {
    updateStationZone();
    updateUrl(); const summary = byId('station-summary'); summary.replaceChildren();
    const latest = report.latest;
    text('report-status', report.stale ? 'No recent observation. Check timestamps before using these data.' : 'Station data loaded.');
    if (report.warnings.length) {
      summary.append(element('p', report.warnings.map(w => `${w.product.replaceAll('_', ' ')}: ${w.message}`).join(' '), 'muted report-warning'));
      byId('retry-report').hidden = false;
    }
    summary.append(element('p', latest ? `${latest.value.toFixed(2)} ${unit()} above ${report.datum} · ${quality(latest.quality)}` : 'No water-level observation available.', 'latest-reading'));
    if (latest) {
      const age = element('p', ''); age.id = 'reading-age'; summary.append(age);
      const freshness = element('p', '', 'report-warning'); freshness.id = 'reading-freshness';
      freshness.setAttribute('role', 'status'); summary.append(freshness); updateFreshness();
    }
    if (report.datum) summary.append(element('p', `Height reference: ${report.datum} · Times: ${zone()}`, 'muted'));
    if (report.datum === 'IGLD') {
      summary.append(element('p', 'Lake-surface elevation relative to the International Great Lakes Datum (IGLD), rather than tide height. The variation below shows how much the water rose and fell during the selected period.', 'datum-explanation'));
    }
    const heights = report.observations.map(p => p.value).filter(v => v !== null);
    if (heights.length) summary.append(element('p', `Observed ${report.hours}-hour range: ${Math.min(...heights).toFixed(2)}–${Math.max(...heights).toFixed(2)} ${unit()} · Variation ${(Math.max(...heights) - Math.min(...heights)).toFixed(2)} ${unit()}`));
    const events = document.createElement('div'); events.id = 'next-events'; summary.append(events); updateNextEvents();
    Object.entries(report.weather).forEach(([product, reading]) => {
      const units = productUnits(product);
      const wind = product === 'wind' ? `${reading.direction ? ` · direction ${reading.direction}°` : ''}${reading.gust ? ` · gust ${reading.gust} ${units}` : ''}` : '';
      summary.append(element('p', `${product.replaceAll('_', ' ')}: ${reading.value} ${units}${wind} · ${date(reading.time)}`));
    });
    (report.sensors || []).filter(sensor => !sensor.enabled).forEach(sensor => {
      summary.append(element('p', `${sensor.name}: sensor disabled${sensor.message ? ` · ${sensor.message}` : ''}`, 'muted'));
    });
    const series = [ ['Observed water level', report.observations], ['Predicted water level', report.predictions] ]
      .filter(([, values]) => values.some(point => point.value !== null))
      .map(([name, values]) => ({ name: name === 'Predicted water level' && selected.prediction_type === 'S' ? 'Predicted high/low events' : name,
        type: name === 'Predicted water level' && selected.prediction_type === 'S' ? 'scatter' : 'line',
        data: name === 'Observed water level' ? observedPoints(values) : values.map(point => [point.timestamp, point.value]), connectNulls: false }));
    if (series.length) {
      const options = {
        chart: { type: 'line', animation: false }, title: { text: stationLabel(selected) },
        subtitle: { text: `Past ${report.hours} hours · Source: NOAA CO-OPS` }, time: { timezone: zone() },
        xAxis: { type: 'datetime' }, yAxis: { title: { text: `${report.datum === 'IGLD' ? 'Lake-level elevation' : 'Water level'} (${unit()}, ${report.datum})` } },
        tooltip: { xDateFormat: '%e %b %Y %H:%M', valueSuffix: ` ${unit()}` },
        credits: { enabled: false }, series
      };
      if (chart) chart.update(options, true, true, false);
      else chart = Highcharts.chart('graph-partial', options);
      window.chart_graph_partial = chart;
    } else if (chart) {
      chart.destroy(); chart = null; window.chart_graph_partial = null;
    }
    renderWeatherCharts();
    window.StationExtras.update({ selected, report, zone, date, unit });
    byId('observations-table').hidden = ![report.observations, report.predictions, ...Object.values(report.weather_series || {})].some(values => values.length);
    renderMeasurements();
  }
  function closeStation() {
    generation++; pending?.abort(); spread?.close(); selected = null; report = null; clearChart(); window.StationExtras.reset(); infoWindow?.close();
    byId('station-panel').hidden = true; updateUrl();
    if (savedFocus?.isConnected) savedFocus.focus(); else byId('station-search').focus();
  }
  function locateStations() {
    const button = byId('locate');
    if (button.disabled) return;
    if (!window.isSecureContext || !navigator.geolocation) {
      text('location-status', 'Location is unavailable in this browser or connection. Search by name or state.'); return;
    }
    const finish = message => { button.disabled = false; text('location-status', message); };
    button.disabled = true; text('location-status', `Requesting location for ${window.location.host}…`);
    try {
      navigator.geolocation.getCurrentPosition(position => {
        const { latitude: lat, longitude: lng } = position.coords;
        stations.sort((a, b) => distance(a, lat, lng) - distance(b, lat, lng)); renderResults();
        map?.setCenter({ lat, lng }); map?.setZoom(8); finish('Stations sorted by distance from you.');
      }, error => finish(({
        1: `Location access for ${window.location.host} was declined. You can allow it in your browser's site settings.`,
        2: 'Your location could not be determined. Try again or search by name or state.',
        3: 'Finding your location timed out. Try again or search by name or state.'
      })[error.code] || 'Location is unavailable. Try again or search by name or state.'),
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 });
    } catch (_) { finish('Location is unavailable. Try again or search by name or state.'); }
  }
  async function start() {
    if (!byId('station-explorer')) return;
    text('location-origin', window.location.host);
    const params = new URL(window.location.href).searchParams;
    for (const [key, id] of [['hours', 'history-hours'], ['future_hours', 'future-hours'], ['units', 'height-units'], ['zone', 'display-zone']]) {
      const value = params.get(key); if ([...byId(id).options].some(o => o.value === value)) byId(id).value = value;
    }
    byId('station-search').addEventListener('input', () => { visibleCount = 100; renderResults(); });
    byId('station-layer').addEventListener('change', () => { visibleCount = 100; renderResults(); });
    byId('extra-products-toggle').addEventListener('click', () => { byId('station-layer').value = byId('station-layer').value === 'additional' ? lastLayer : 'additional'; visibleCount = 100; renderResults(); });
    byId('more-stations').addEventListener('click', () => { visibleCount += 100; renderResults(); });
    byId('close-station').addEventListener('click', closeStation);
    byId('station-panel').addEventListener('keydown', event => { if (event.key === 'Escape') closeStation(); });
    for (const id of ['history-hours', 'height-units', 'future-hours']) byId(id).addEventListener('change', () => { updateUrl(); if (selected) { measurementLimit = 1000; loadReport(); } });
    byId('display-zone').addEventListener('change', () => { if (report) renderReport(); });
    byId('retry-report').addEventListener('click', loadReport);
    byId('observations-table').addEventListener('toggle', renderMeasurements);
    byId('more-measurements').addEventListener('click', () => {
      measurementLimit += 1000; renderMeasurements();
      if (byId('more-measurements').hidden) byId('observations-table').querySelector('summary').focus({preventScroll: true});
    });
    document.addEventListener('visibilitychange', updateFreshness); setInterval(updateFreshness, 60000);
    byId('share-station').addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(window.location.href); text('report-status', 'Station link copied.'); }
      catch (_) { text('report-status', 'Copy the station link from your address bar.'); }
    });
    byId('locate').addEventListener('click', locateStations);
    try {
      const response = await fetch('/stations.json'); if (!response.ok) throw new Error('Catalog unavailable');
      const payload = await response.json(); stations = payload.stations;
      text('catalog-status', payload.status.refreshed_at ? `Catalog refreshed ${date(payload.status.refreshed_at, 'UTC')} UTC${payload.status.stale ? ' · Refresh overdue' : ''}` : 'Saved station inventory · Automatic refresh not yet initialized');
      renderResults();
      if (payload.products_warning) byId('catalog-status').append(element('span', ' · Additional product discovery unavailable; station search remains available.'));
      if (!stations.length) text('catalog-status', 'No stations are available. Please try again later.');
      const initial = stations.find(s => s.station_id === params.get('station'));
      if (initial) selectStation(initial);
    } catch (_) { text('catalog-status', 'The station catalog is unavailable. Please reload to retry.'); }
    const key = byId('full_map').dataset.mapsKey;
    if (!key) { text('map-status', 'The map is unavailable. Use the station list to explore data.'); return; }
    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?${new URLSearchParams({ key, callback: 'initMap', loading: 'async', ...(byId('full_map').dataset.mapId ? { libraries: 'marker' } : {}) })}`;
    script.async = true; script.onerror = window.gm_authFailure; document.head.append(script);
  }
  function distance(station, lat, lng) {
    const radians = degrees => degrees * Math.PI / 180;
    const dlat = radians(Number(station.latitude) - lat), dlng = radians(Number(station.longitude) - lng);
    return Math.sin(dlat / 2) ** 2 + Math.cos(radians(lat)) * Math.cos(radians(Number(station.latitude))) * Math.sin(dlng / 2) ** 2;
  }
  document.addEventListener('DOMContentLoaded', start);
})();
