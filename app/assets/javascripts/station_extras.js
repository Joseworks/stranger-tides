/* global Highcharts */
(() => {
  'use strict';
  const byId = id => document.getElementById(id);
  const charts = new Map(), requests = new Map(), results = new Map();
  let state, epoch = 0;
  const products = metric => ({
    wind: ['Wind speed', metric ? 'm/s' : 'knots'], gust: ['Wind gust', metric ? 'm/s' : 'knots'],
    wind_direction: ['Wind direction', '°'],
    air_temperature: ['Air temperature', metric ? '°C' : '°F'],
    water_temperature: ['Water temperature', metric ? '°C' : '°F'],
    air_pressure: ['Air pressure', 'hPa'], humidity: ['Relative humidity', '%'],
    conductivity: ['Conductivity', 'mS/cm'], salinity: ['Salinity', 'PSU'],
    specific_gravity: ['Specific gravity', ''], visibility: ['Visibility', metric ? 'km' : 'nmi'],
    air_gap: ['Bridge-to-water clearance', metric ? 'm' : 'ft'],
    wave_height: ['Significant wave height', metric ? 'm' : 'ft'],
    wave_period: ['Dominant wave period', 's'], average_period: ['Average wave period', 's'],
    wave_direction: ['Wave direction', '°']
  });
  function node(tag, value, className) {
    const el = document.createElement(tag); el.textContent = value;
    if (className) el.className = className;
    return el;
  }
  function block(parent, id) {
    let el = byId(id);
    if (!el) { el = document.createElement('div'); el.id = id; parent.append(el); }
    return el;
  }
  function label(parent, id, ...children) { block(parent, id).replaceChildren(...children); }
  function link(name, href) {
    const el = node('a', name); el.href = href; el.target = '_blank'; el.rel = 'noopener noreferrer'; return el;
  }
  function points(values, gapMinutes = 6) {
    const result = [];
    values.forEach((p, i) => {
      const previous = values[i - 1];
      if (previous && p.timestamp - previous.timestamp > gapMinutes * 60000) result.push([previous.timestamp + gapMinutes * 60000, null]);
      result.push([p.timestamp, p.value]);
    });
    return result;
  }
  function forecastCadence(values) {
    const intervals = values.slice(1).map((p, i) => (p.timestamp - values[i].timestamp) / 60000);
    return intervals.some(n => n > 0 && n <= 6) ? 6 : intervals.includes(60) ? 60 : 6;
  }
  function draw(parent, id, title, units, series, active, subtitle, extra = {}) {
    if (!series.some(s => s.data.some(p => p[1] !== null))) return;
    active.add(id);
    const options = {
      chart: { animation: false, height: 300 }, title: { text: title }, subtitle: { text: subtitle },
      time: { timezone: state.zone() }, xAxis: { type: 'datetime' },
      yAxis: { title: { text: units }, ...extra.axis },
      tooltip: { xDateFormat: '%e %b %Y %H:%M', valueSuffix: units ? ` ${units}` : '' },
      credits: { enabled: false }, series: series.map(s => ({ type: 'line', connectNulls: false, ...s }))
    };
    const existing = charts.get(id);
    if (existing) existing.update(options, true, true, false);
    else {
      const wrapper = block(parent, `${id}-block`);
      const el = block(wrapper, id); el.className = 'extra-chart'; el.setAttribute('aria-label', title);
      charts.set(id, Highcharts.chart(el, options));
    }
    dataTable(parent, id, title, units, series);
  }
  function dataTable(parent, id, title, units, series) {
    const wrapper = block(parent, `${id}-block`);
    let details = byId(`${id}-data`);
    if (!details) { details = node('details', ''); details.id = `${id}-data`; details.append(node('summary', 'View chart data as a table')); wrapper.append(details); }
    let limit = Number(details.dataset.limit) || 500;
    const fill = () => {
      if (!details.open) return;
      const rows = series.flatMap(s => s.data.map(p => ({time: p[0], value: p[1], name: s.name}))).sort((a, b) => a.time - b.time);
      const body = block(details, `${id}-data-body`); body.replaceChildren();
      const table = node('table', ''); table.append(node('caption', `${title} · Times: ${state.zone()}`));
      const header = node('tr', ''); ['Time', 'Product', 'Value'].forEach(t => {const th = node('th', t); th.scope = 'col'; header.append(th);});
      const head = node('thead', ''); head.append(header); table.append(head);
      const tbody = node('tbody', ''); rows.slice(0, limit).forEach(p => {
        const tr = node('tr', ''); [state.date(p.time), p.name, p.value === null ? 'Missing' : `${p.value} ${units}`].forEach(t => tr.append(node('td', t))); tbody.append(tr);
      }); table.append(tbody); const scroll = node('div', '', 'table-scroll'); scroll.append(table); body.append(scroll);
      body.append(node('p', `Showing ${Math.min(rows.length, limit)} of ${rows.length} measurements.`, 'muted'));
      if (rows.length > limit) {const button = node('button', 'Show more chart data'); button.type = 'button'; button.addEventListener('click', () => {limit += 500; details.dataset.limit = limit; fill(); (body.querySelector('button') || details.querySelector('summary')).focus({preventScroll: true});}); body.append(button);}
    };
    details.ontoggle = fill; fill();
  }
  function planning(active) {
    const {report, selected, unit} = state, parent = byId('planning-charts');
    const future = report.future_predictions || [], differences = report.differences || [];
    label(parent, 'planning-intro', node('h2', 'Tide planning & observed difference'),
      node('p', report.future_hours ? `Planning horizon: next ${report.future_hours / 24} days. Tide predictions describe astronomical tides; weather can change observed levels.` : 'Choose a planning period to view future tide predictions.', 'muted'));
    const subordinate = selected.prediction_type === 'S';
    draw(parent, 'future-tides', 'Future tide predictions', `${unit()}, ${report.datum}`, [{
      name: subordinate ? 'Predicted high/low events' : 'Astronomical tide prediction',
      type: subordinate ? 'scatter' : 'line', data: future.map(p => [p.timestamp, p.value])
    }], active, `NOAA CO-OPS · Times: ${state.zone()}`);
    const events = (report.events || []).filter(p => ['H', 'L'].includes(p.type) && Date.parse(p.time) >= Date.now());
    if (events.length) {
      const list = node('ul', '');
      events.forEach(p => list.append(node('li', `${state.date(p.time)} · ${p.type === 'H' ? 'High' : 'Low'} · ${p.value === null ? 'Missing' : p.value.toFixed(2)} ${unit()}`)));
      const holder = block(parent, 'planning-events');
      let details = holder.querySelector('details');
      if (!details) {details = node('details', ''); details.append(node('summary', '')); holder.append(details);}
      details.querySelector('summary').textContent = `High/low tide calendar (${events.length} events)`;
      details.querySelector('ul')?.remove(); details.append(list);
    } else byId('planning-events')?.remove();
    const valid = differences.filter(p => p.value !== null), latest = valid.at(-1);
    label(parent, 'departure-note', node('p', latest ?
      `Observed minus predicted: ${latest.value >= 0 ? '+' : ''}${latest.value.toFixed(2)} ${unit()} at ${state.date(latest.time)}. Only matching timestamps are compared.` :
      'An observed-versus-predicted difference requires matching water-level observations and continuous tide predictions; it is unavailable for this station or period.', 'muted'));
    draw(parent, 'tide-difference', 'Observed minus predicted water level', unit(), [{
      name: 'Observed minus predicted', data: points(differences)
    }], active, 'Difference from the astronomical tide · Missing or flagged comparisons remain gaps',
    {axis: {plotLines: [{value: 0, color: '#506976', width: 1}]}});
    if (report.future_hours && !future.length) block(parent, 'planning-intro').append(node('p', 'No future tide predictions are available for this station or period.', 'muted'));
  }
  function context(active) {
    const parent = byId('station-context'), result = results.get('context');
    label(parent, 'context-intro', node('h2', 'Forecasts & flood context'));
    if (!result || result.error) {byId('flood-outlook')?.remove(); byId('noaa-extra-products')?.remove();}
    if (!result) { block(parent, 'context-intro').append(node('p', 'Loading optional NOAA forecast and flood products…', 'muted')); return; }
    if (result.error) { block(parent, 'context-intro').append(node('p', result.error, 'muted')); return; }
    block(parent, 'context-intro').append(node('p', `Retrieved ${state.date(result.fetched_at)}. Model guidance and flood outlooks are separate products from astronomical tide predictions.`, 'muted'));
    (result.warnings || []).forEach(w => block(parent, 'context-intro').append(node('p', w, 'muted')));
    draw(parent, 'forecast-water-level', 'Water-level model forecast', `${state.unit()}, ${result.datum}`, [{
      name: 'NOAA OFS model guidance', data: points(result.forecast || [], forecastCadence(result.forecast || [])), dashStyle: 'Dash'
    }], active, 'Available guidance within the next 48 hours · NOAA CO-OPS');
    if (!(result.forecast || []).length) block(parent, 'context-intro').append(node('p', 'No water-level model forecast is available for this station.', 'muted'));
    draw(parent, 'one-minute-water-level', 'One-minute water-level observations', `${state.unit()}, ${result.datum}`, [{name: 'Observed water level (one minute)', data: points(result.one_minute || [], 1)}], active, 'Past 24 hours · NOAA CO-OPS · Preliminary');
    const outlook = block(parent, 'flood-outlook'); outlook.replaceChildren();
    if ((result.flood_outlook || []).length) {
      outlook.append(node('h3', 'High-tide flooding outlook'), node('p', `NOAA daily likelihood of exceeding the NOS minor threshold (${state.unit()} above MLLW). These are outlooks, not official weather warnings. Dates are NOAA calendar dates.`, 'muted'));
      const table = node('table', ''), header = node('tr', '');
      ['Date', 'Likelihood', 'Threshold', 'Model updated'].forEach(t => {const th = node('th', t); th.scope = 'col'; header.append(th);});
      const head = document.createElement('thead'); head.append(header); table.append(head);
      const body = document.createElement('tbody');
      result.flood_outlook.forEach(p => {
        const row = node('tr', '');
        [p.date, `${p.likelihood}%`, `${p.threshold.toFixed(2)} ${state.unit()}`, p.updated].forEach(t => row.append(node('td', t))); body.append(row);
      }); table.append(body); const scroll = node('div', '', 'table-scroll'); scroll.append(table); outlook.append(scroll);
    } else outlook.append(node('p', 'No high-tide flooding outlook is available for this station.', 'muted'));
    const links = block(parent, 'noaa-extra-products'), signature = JSON.stringify(result.products || []);
    if (links.dataset.products !== signature) {
      links.replaceChildren(); links.dataset.products = signature;
      if (result.products?.length) {
        const details = node('details', ''); details.append(node('summary', 'Other NOAA station products'));
        const list = node('ul', ''); result.products.forEach(p => { const li = node('li', ''); li.append(link(p.name, p.url)); list.append(li); });
        details.append(list); links.append(details);
      }
    }
  }

  function buoys(active) {
    const parent = byId('nearby-buoys'), result = results.get('nearby');
    label(parent, 'buoy-intro', node('h2', 'Nearby NOAA buoy observations'), node('p', 'These are separate instruments at nearby locations. Distance alone does not establish equivalent harbor or coastal conditions.', 'muted'));
    if (!result || result.error || !result.buoys?.length) {
      if (result) parent.querySelectorAll('.buoy-card').forEach(card => card.remove());
      block(parent, 'buoy-intro').append(node('p', result?.error || (result ? 'No reporting buoy data was found among the three nearest NOAA sites within 200 km.' : 'Loading nearby NOAA instruments…'), 'muted')); return;
    }
    const definitions = products(state.report.units === 'metric'), activeCards = new Set();
    result.buoys.forEach(buoy => {
      const id = `buoy-${buoy.id}`; activeCards.add(id);
      let card = byId(id);
      if (!card) {card = node('details', '', 'buoy-card'); card.id = id; card.append(node('summary', '')); parent.append(card); card.addEventListener('toggle', () => {render(); charts.forEach(c => c.reflow());});}
      card.querySelector('summary').textContent = `${buoy.name || buoy.id} (${buoy.id}) · ${buoy.distance_km} km away${buoy.stale ? ' · Stale observations' : ''}`;
      label(card, `${id}-source`, link('View this instrument at NOAA NDBC', buoy.source_url), node('p', `Latest available measurement: ${state.date(buoy.latest_at)} · Latitude ${buoy.latitude}, longitude ${buoy.longitude}.`, 'muted'));
      const grid = block(card, `${id}-charts`); grid.className = 'extra-grid';
      if (!card.open) return;
      Object.entries(buoy.series).forEach(([product, values]) => {
        const definition = definitions[product]; if (!definition) return;
        const [title, units] = definition, direction = product.endsWith('direction');
        draw(grid, `${id}-${product}`, title, units, [{name: title, type: direction ? 'scatter' : 'line', data: points(values, 60)}], active, `NOAA NDBC ${buoy.id} · Past ${result.hours} hours`, direction ? {axis: {min: 0, max: 360}} : {});
      });
    });
    parent.querySelectorAll('.buoy-card').forEach(card => {if (!activeCards.has(card.id)) card.remove();});
    if (result.warnings?.length) block(parent, 'buoy-intro').append(node('p', result.warnings.join(' '), 'muted'));
  }
  function render() {
    if (!state) return;
    const active = new Set(); planning(active); context(active); buoys(active);
    if ([...results.values()].some(value => value.error || value.warnings?.length)) {
      const button = node('button', 'Retry additional products'); button.type = 'button';
      button.addEventListener('click', () => { requests.forEach(r => r.controller.abort()); requests.clear(); results.clear(); window.StationExtras.update(state); });
      block(byId('station-context'), 'context-intro').append(button);
    }
    charts.forEach((chart, id) => {if (!active.has(id)) {chart.destroy(); byId(`${id}-block`)?.remove(); charts.delete(id);}});
  }
  function load(kind, key, url) {
    const old = requests.get(kind); if (old?.key === key) return;
    old?.controller.abort(); results.delete(kind);
    const controller = new AbortController(), token = epoch;
    requests.set(kind, {key, controller});
    fetch(url, {signal: controller.signal}).then(async response => {
      if (!response.headers.get('content-type')?.includes('application/json')) throw Error('Optional NOAA data is unavailable.');
      const payload = await response.json(); if (!response.ok) throw Error(payload.error || 'Optional NOAA data is unavailable.'); return payload;
    }).then(payload => {
      if (token === epoch && requests.get(kind)?.key === key) {results.set(kind, payload); render();}
    }).catch(error => {
      if (error.name !== 'AbortError' && token === epoch && requests.get(kind)?.key === key) {results.set(kind, {error: error.message}); render();}
    });
  }
  window.StationExtras = {
    products,
    reset() {
      epoch++; requests.forEach(r => r.controller.abort()); requests.clear(); results.clear(); state = null;
      charts.forEach(c => c.destroy()); charts.clear();
      ['planning-charts', 'station-context', 'nearby-buoys'].forEach(id => byId(id)?.replaceChildren());
    },
    update(value) {
      state = value;
      const id = encodeURIComponent(state.selected.station_id), units = state.report.units, hours = state.report.hours;
      load('context', `${id}:${units}`, `/stations/${id}/context?${new URLSearchParams({units})}`);
      load('nearby', `${id}:${units}:${hours}`, `/stations/${id}/nearby?${new URLSearchParams({units, hours})}`);
      render();
    }
  };
})();
