/* global google, Highcharts */
(() => {
  'use strict';
  let stations = [], filtered = [], visibleCount = 100, map, infoWindow, markers = [];
  let selected, report, pending, generation = 0, chart, savedFocus;
  const byId = id => document.getElementById(id);
  const text = (id, value) => { byId(id).textContent = value; };
  const capabilities = station => station.capabilities || ['waterlevels'];
  const stationLabel = station => station.state && !station.station_name.endsWith(`, ${station.state}`) ? `${station.station_name}, ${station.state}` : station.station_name;
  const zone = () => byId('display-zone').value === 'utc' ? 'UTC' : Intl.DateTimeFormat().resolvedOptions().timeZone;
  const date = value => new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short', timeZone: zone() }).format(new Date(value));
  const quality = value => ({ p: 'Preliminary', v: 'Verified' }[value] || 'Quality not provided');
  const unit = () => byId('height-units').value === 'metric' ? 'm' : 'ft';
  function element(tag, value, className) {
    const node = document.createElement(tag); node.textContent = value;
    if (className) node.className = className;
    return node;
  }
  function clearChart() {
    if (chart) chart.destroy();
    chart = null; window.chart_graph_partial = null;
    byId('graph-partial').replaceChildren();
  }
  function updateUrl() {
    const url = new URL(window.location.href);
    for (const [key, value] of Object.entries({ station: selected?.station_id, hours: byId('history-hours').value,
      units: byId('height-units').value, zone: byId('display-zone').value })) {
      if (value) url.searchParams.set(key, value); else url.searchParams.delete(key);
    }
    window.history.replaceState(null, '', url);
  }
  function renderResults() {
    const search = byId('station-search').value.trim().toLocaleLowerCase();
    const layer = byId('station-layer').value;
    filtered = stations.filter(s => (layer === 'all' || capabilities(s).includes(layer)) &&
      `${s.station_name} ${s.station_id} ${s.state || ''}`.toLocaleLowerCase().includes(search));
    text('result-count', `${filtered.length} matching locations`);
    byId('station-results').replaceChildren(...filtered.slice(0, visibleCount).map(s => {
      const item = document.createElement('li'); const button = element('button', `${stationLabel(s)} ${s.station_id}`);
      button.type = 'button'; button.dataset.stationId = s.station_id;
      button.append(element('small', `${s.state || ''} · ${capabilities(s).includes('waterlevels') ? 'Water-level observations' : 'Prediction / weather location'}`));
      button.addEventListener('click', () => selectStation(s)); item.append(button); return item;
    }));
    byId('more-stations').hidden = filtered.length <= visibleCount;
    renderMarkers();
  }
  function renderMarkers() {
    if (!map) return;
    markers.forEach(marker => { if (marker.setMap) marker.setMap(null); else marker.map = null; }); markers = [];
    const cell = 360 / 2 ** ((map.getZoom?.() || 3) + 2);
    const groups = new Map();
    filtered.forEach(s => {
      const key = `${Math.floor(Number(s.latitude) / cell)},${Math.floor(Number(s.longitude) / cell)}`;
      if (!groups.has(key)) groups.set(key, []); groups.get(key).push(s);
    });
    groups.forEach(group => {
      const station = group[0], count = group.length;
      const position = { lat: group.reduce((n, s) => n + Number(s.latitude), 0) / count,
        lng: group.reduce((n, s) => n + Number(s.longitude), 0) / count };
      const title = count > 1 ? `${count} stations; zoom in` : `${stationLabel(station)} ${station.station_id}`;
      const advanced = byId('full_map').dataset.mapId && google.maps.marker?.AdvancedMarkerElement;
      let marker;
      if (advanced) {
        const content = element('button', count > 1 ? String(count) : '●', 'map-pin'); content.setAttribute('aria-label', title);
        marker = new google.maps.marker.AdvancedMarkerElement({ map, position, title, content });
      } else {
        marker = new google.maps.Marker({ map, position, title, optimized: false,
          ...(count > 1 ? { label: String(count) } : { icon: byId('full_map').dataset.markerIcon }) });
      }
      marker.addListener('click', () => {
        if (count > 1) { map.setCenter(position); map.setZoom((map.getZoom?.() || 3) + 2); }
        else selectStation(station);
      });
      markers.push(marker);
    });
  }
  window.initMap = () => {
    try {
      map = new google.maps.Map(byId('full_map'), { center: { lat: 38.88, lng: -98.35 }, zoom: 3,
        ...(byId('full_map').dataset.mapId ? { mapId: byId('full_map').dataset.mapId } : {}) });
      infoWindow = new google.maps.InfoWindow();
      map.addListener?.('idle', renderMarkers);
      byId('map-status').hidden = true; renderMarkers();
    } catch (_) { text('map-status', 'The map is unavailable. Use the station list to explore data.'); }
  };
  window.gm_authFailure = () => { byId('map-status').hidden = false; text('map-status', 'The map is unavailable. Use the station list to explore data.'); };
  function selectStation(station) {
    savedFocus = document.activeElement; selected = station; report = null;
    byId('station-panel').hidden = false; text('station-heading', `${stationLabel(station)} ${station.station_id}`);
    if (window.matchMedia('(max-width: 760px)').matches) byId('station-panel').scrollIntoView({ block: 'start' });
    if (map) {
      const position = { lat: Number(station.latitude), lng: Number(station.longitude) };
      map.setCenter(position); map.setZoom(8);
      infoWindow.setContent(element('div', `${stationLabel(station)} · ${station.station_id}`));
      infoWindow.setPosition?.(position); infoWindow.open(map);
    }
    byId('station-heading').focus({ preventScroll: true }); updateUrl(); loadReport();
  }
  async function loadReport() {
    pending?.abort(); const token = ++generation; pending = new AbortController();
    clearChart(); report = null; byId('station-summary').replaceChildren(); byId('measurement-rows').replaceChildren();
    byId('observations-table').hidden = true; byId('retry-report').hidden = true;
    byId('station-panel').setAttribute('aria-busy', 'true'); text('report-status', 'Loading NOAA station data…');
    try {
      const params = new URLSearchParams({ hours: byId('history-hours').value, units: byId('height-units').value });
      const response = await fetch(`/stations/${encodeURIComponent(selected.station_id)}/report?${params}`, { signal: pending.signal });
      if (!response.headers.get('content-type')?.includes('application/json')) throw new Error('Station data is unavailable. Please try again.');
      const payload = await response.json();
      if (token !== generation) return;
      if (!response.ok) throw new Error(payload.error || 'Station data is unavailable.');
      report = payload; renderReport();
    } catch (error) {
      if (error.name === 'AbortError' || token !== generation) return;
      text('report-status', error.message || 'Station data is unavailable. Please try again.'); byId('retry-report').hidden = false;
    } finally { if (token === generation) byId('station-panel').removeAttribute('aria-busy'); }
  }
  function renderReport() {
    clearChart(); updateUrl(); const summary = byId('station-summary'); summary.replaceChildren();
    const latest = report.latest;
    text('report-status', report.stale ? 'No recent observation. Check timestamps before using these data.' : 'Station data loaded.');
    if (report.warnings.length) {
      summary.append(element('p', report.warnings.map(w => `${w.product.replaceAll('_', ' ')}: ${w.message}`).join(' '), 'muted report-warning'));
      byId('retry-report').hidden = false;
    }
    summary.append(element('p', latest ? `${latest.value.toFixed(2)} ${unit()} above ${report.datum} · ${quality(latest.quality)}` : 'No water-level observation available.', 'latest-reading'));
    if (latest) summary.append(element('p', `Observed ${date(latest.time)} · ${Math.max(0, Math.floor((Date.now() - Date.parse(latest.time)) / 60000))} minutes ago`));
    if (report.datum) summary.append(element('p', `Height reference: ${report.datum} · Times: ${zone()}`, 'muted'));
    if (report.datum === 'IGLD') {
      summary.append(element('p', 'Lake-surface elevation relative to the International Great Lakes Datum (IGLD), rather than tide height. The variation below shows how much the water rose and fell during the selected period.', 'datum-explanation'));
    }
    const heights = report.observations.map(p => p.value).filter(v => v !== null);
    if (heights.length) summary.append(element('p', `Observed ${report.hours}-hour range: ${Math.min(...heights).toFixed(2)}–${Math.max(...heights).toFixed(2)} ${unit()} · Variation ${(Math.max(...heights) - Math.min(...heights)).toFixed(2)} ${unit()}`));
    const events = report.events.filter(e => e.value !== null && Date.parse(e.time) >= Date.now());
    for (const type of ['H', 'L']) {
      const event = events.find(e => e.type === type);
      if (event) summary.append(element('p', `Next predicted ${type === 'H' ? 'high' : 'low'}: ${date(event.time)} · ${event.value.toFixed(2)} ${unit()}`));
    }
    Object.entries(report.weather).forEach(([product, reading]) => {
      const units = ({ wind: report.units === 'metric' ? 'm/s' : 'knots', air_pressure: 'mb', humidity: '%' })[product] || (report.units === 'metric' ? '°C' : '°F');
      const wind = product === 'wind' ? `${reading.direction ? ` · direction ${reading.direction}°` : ''}${reading.gust ? ` · gust ${reading.gust} ${units}` : ''}` : '';
      summary.append(element('p', `${product.replaceAll('_', ' ')}: ${reading.value} ${units}${wind} · ${date(reading.time)}`));
    });
    (report.sensors || []).filter(sensor => !sensor.enabled).forEach(sensor => {
      summary.append(element('p', `${sensor.name}: sensor disabled${sensor.message ? ` · ${sensor.message}` : ''}`, 'muted'));
    });
    byId('noaa-station-link').href = report.source_url;
    const series = [ ['Observed water level', report.observations], ['Predicted water level', report.predictions] ]
      .filter(([, values]) => values.some(point => point.value !== null))
      .map(([name, values]) => ({ name: name === 'Predicted water level' && selected.prediction_type === 'S' ? 'Predicted high/low events' : name,
        type: name === 'Predicted water level' && selected.prediction_type === 'S' ? 'scatter' : 'line',
        data: values.map(point => [point.timestamp, point.value]), connectNulls: false }));
    if (series.length) {
      chart = Highcharts.chart('graph-partial', {
        chart: { type: 'line', animation: false }, title: { text: stationLabel(selected) },
        subtitle: { text: `Past ${report.hours} hours · Source: NOAA CO-OPS` }, time: { timezone: zone() },
        xAxis: { type: 'datetime' }, yAxis: { title: { text: `${report.datum === 'IGLD' ? 'Lake-level elevation' : 'Water level'} (${unit()}, ${report.datum})` } },
        tooltip: { xDateFormat: '%e %b %Y %H:%M', valueSuffix: ` ${unit()}` },
        credits: { enabled: false }, series
      });
      window.chart_graph_partial = chart;
    }
    byId('observations-table').hidden = !report.observations.length;
    byId('measurement-rows').replaceChildren(...report.observations.map(point => {
      const row = document.createElement('tr');
      row.append(element('td', date(point.time)), element('td', point.value === null ? 'Missing' : `${point.value} ${unit()}`), element('td', quality(point.quality)));
      return row;
    }));
  }
  function closeStation() {
    generation++; pending?.abort(); selected = null; report = null; clearChart(); infoWindow?.close();
    byId('station-panel').hidden = true; updateUrl();
    if (savedFocus?.isConnected) savedFocus.focus(); else byId('station-search').focus();
  }
  async function start() {
    if (!byId('station-explorer')) return;
    const params = new URL(window.location.href).searchParams;
    for (const [key, id] of [['hours', 'history-hours'], ['units', 'height-units'], ['zone', 'display-zone']]) {
      const value = params.get(key); if ([...byId(id).options].some(o => o.value === value)) byId(id).value = value;
    }
    byId('station-search').addEventListener('input', () => { visibleCount = 100; renderResults(); });
    byId('station-layer').addEventListener('change', () => { visibleCount = 100; renderResults(); });
    byId('more-stations').addEventListener('click', () => { visibleCount += 100; renderResults(); });
    byId('close-station').addEventListener('click', closeStation);
    byId('station-panel').addEventListener('keydown', event => { if (event.key === 'Escape') closeStation(); });
    for (const id of ['history-hours', 'height-units']) byId(id).addEventListener('change', () => { updateUrl(); if (selected) loadReport(); });
    byId('display-zone').addEventListener('change', () => { if (report) renderReport(); });
    byId('retry-report').addEventListener('click', loadReport);
    byId('share-station').addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(window.location.href); text('report-status', 'Station link copied.'); }
      catch (_) { text('report-status', 'Copy the station link from your address bar.'); }
    });
    byId('locate').addEventListener('click', () => {
      if (!navigator.geolocation) { text('location-status', 'Location is unavailable. Search by name or state.'); return; }
      text('location-status', 'Finding your location…');
      navigator.geolocation.getCurrentPosition(position => {
        const { latitude: lat, longitude: lng } = position.coords;
        stations.sort((a, b) => distance(a, lat, lng) - distance(b, lat, lng)); renderResults();
        map?.setCenter({ lat, lng }); map?.setZoom(8); text('location-status', 'Stations sorted by distance from you.');
      }, () => text('location-status', 'Location was unavailable or declined. Search by name or state.'), { timeout: 10000, maximumAge: 60000 });
    });
    try {
      const response = await fetch('/stations.json'); if (!response.ok) throw new Error('Catalog unavailable');
      const payload = await response.json(); stations = payload.stations;
      text('catalog-status', payload.status.refreshed_at ? `Catalog refreshed ${date(payload.status.refreshed_at)}${payload.status.stale ? ' · Refresh overdue' : ''}` : 'Saved station inventory · Automatic refresh not yet initialized');
      renderResults();
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
