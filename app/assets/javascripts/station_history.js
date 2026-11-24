/* global Highcharts */
(() => {
  'use strict';
  const byId = id => document.getElementById(id), charts = new Map();
  let state, result, request, requestedUnits, version = 0, key, limit = 500, initialized = false;
  const node = (tag, value) => {const el = document.createElement(tag); el.textContent = value; return el;};
  const unit = () => result.units === 'metric' ? 'm' : 'ft';
  const monthly = () => result.window.calendar_months;
  const stamp = point => monthly() ? point.period : state.date(point.time);
  const observedName = () => monthly() ? 'Monthly mean water level (MSL)' : result.window.resolution === 'hourly' ? 'Verified hourly water level' : 'Observed water level';
  const datasets = () => [
    {name: observedName(), product: result.window.product, values: result.observations},
    {name: 'Tide prediction', product: 'predictions', values: result.predictions},
    {name: 'Observed minus predicted', product: 'observed_minus_predicted', values: result.differences}
  ];
  function destroy() {charts.forEach(c => c.destroy()); charts.clear();}
  function points(values) {
    const rows = [];
    values.forEach((point, i) => {
      const previous = values[i - 1];
      if (previous) {
        const next = monthly() ? Date.UTC(new Date(previous.timestamp).getUTCFullYear(), new Date(previous.timestamp).getUTCMonth() + 1) : previous.timestamp + result.window.interval_minutes * 60000;
        if (point.timestamp > next) rows.push([next, null]);
      }
      rows.push([point.timestamp, point.value]);
    });
    return rows;
  }
  function draw(id, title, series) {
    if (!series.some(s => s.data.some(p => p[1] !== null))) {charts.get(id)?.destroy(); charts.delete(id); return;}
    const options = {
      chart: {animation: false, height: 330}, title: {text: title},
      subtitle: {text: `${result.window.begin_date} to ${result.window.end_date} · ${result.datum} · NOAA CO-OPS`},
      time: {timezone: monthly() ? 'UTC' : state.zone()}, xAxis: {type: 'datetime'},
      yAxis: {title: {text: `${unit()}${id === 'history-chart' ? `, ${result.datum}` : ''}`}},
      tooltip: {xDateFormat: monthly() ? '%B %Y' : '%e %b %Y %H:%M', valueSuffix: ` ${unit()}`},
      credits: {enabled: false}, series: series.map(s => ({type: 'line', connectNulls: false, ...s}))
    };
    const chart = charts.get(id);
    if (chart) window.StationCharts.update(chart, options, true);
    else charts.set(id, Highcharts.chart(id, options));
  }
  function table() {
    if (!result || !byId('history-table').open) return;
    const rows = datasets().flatMap(d => d.values.map(point => ({...d, point}))).sort((a,b) => a.point.timestamp - b.point.timestamp);
    byId('history-rows').replaceChildren(...rows.slice(0,limit).map(({name, point}) => {
      const tr = node('tr','');
      [stamp(point), name, point.value === null ? 'Missing' : `${point.value} ${unit()}`,
        `${point.quality === 'v' ? 'Verified' : point.quality === 'p' ? 'Preliminary' : 'Not provided'} / ${point.flags || 'Not provided'}`].forEach(value => tr.append(node('td',value)));
      return tr;
    }));
    byId('history-page').textContent = `Showing ${Math.min(limit, rows.length)} of ${rows.length} measurements. CSV includes all loaded rows, including gaps and flags.`;
    byId('history-more').hidden = rows.length <= limit;
  }
  function render() {
    if (!result) return;
    const station = state.selected;
    const label = station.state && !station.station_name.endsWith(`, ${station.state}`) ? `${station.station_name}, ${station.state}` : station.station_name;
    byId('history-caption').textContent = `${label} · ${result.window.begin_date} to ${result.window.end_date} · ${result.window.resolution.replaceAll('_',' ')} · ${result.datum} · ${unit()} · ${monthly() ? 'Calendar months (no time zone conversion)' : `Dates bounded in UTC; timestamps shown in ${state.zone()}`}. Historical data do not auto-refresh.`;
    byId('history-table-caption').textContent = byId('history-caption').textContent;
    const subordinate = state.selected.prediction_type === 'S';
    draw('history-chart', observedName(), [
      {name: observedName(), data: points(result.observations)},
      {name: subordinate ? 'Predicted high/low events' : 'Tide prediction', type: subordinate ? 'scatter' : 'line',
        data: subordinate ? result.predictions.map(p => [p.timestamp, p.value]) : points(result.predictions)}
    ]);
    draw('history-difference-chart', 'Historical observed minus predicted', [{name: 'Observed minus predicted', data: points(result.differences)}]);
    byId('history-table').hidden = !datasets().some(d => d.values.length);
    table();
  }
  function parameters() {
    return new URLSearchParams({begin_date: byId('history-start').value, end_date: byId('history-end').value,
      resolution: byId('history-resolution').value, units: state.units});
  }
  function share(params) {
    const url = new URL(location.href);
    ['begin_date','end_date','resolution'].forEach(name => url.searchParams.set(name, params.get(name)));
    history.replaceState(null,'',url);
  }
  async function load() {
    if (!state) return;
    request?.abort(); const token = ++version, controller = new AbortController(); request = controller;
    const params = parameters(); key = `${state.selected.station_id}:${params}`; requestedUnits = state.units;
    byId('history-export').disabled = true; byId('history-results').setAttribute('aria-busy','true');
    byId('history-status').textContent = 'Loading fixed-date NOAA water levels…';
    try {
      const response = await fetch(`/stations/${encodeURIComponent(state.selected.station_id)}/history?${params}`, {signal: controller.signal});
      if (!response.headers.get('content-type')?.includes('application/json')) throw Error('Historical data are unavailable. Try again.');
      const payload = await response.json(); if (token !== version) return;
      if (!response.ok) throw Error(payload.error || 'Historical data are unavailable.');
      result = payload; destroy(); limit = 500; share(params); render();
      const present = datasets().some(d => d.values.some(p => p.value !== null));
      byId('history-status').textContent = `${present ? 'Historical data loaded.' : 'No historical values are available for these dates and resolution.'}${payload.warnings.length ? ` ${payload.warnings.map(w => `${w.product}: ${w.message}`).join(' ')}` : ''}${monthly() ? ' Monthly means have no tide predictions or departure calculation.' : ''}`;
      byId('history-export').disabled = !datasets().some(d => d.values.length);
    } catch (error) {
      if (error.name !== 'AbortError' && token === version) byId('history-status').textContent = `${error.message}${result ? ' Previous historical charts remain; CSV is disabled until a successful load.' : ''}`;
    } finally {
      if (token === version) {request = null; byId('history-results').setAttribute('aria-busy','false');}
    }
  }
  function exportCsv() {
    if (!result || byId('history-export').disabled) return;
    // Quote every cell and neutralize formula prefixes in untrusted text, preserving numeric negatives.
    const cell = value => `"${(typeof value === 'string' && /^[\s=+\-@]/.test(value) ? `'${value}` : String(value ?? '')).replaceAll('"','""')}"`;
    const headers = ['station_id','station_name','state','product','resolution','datum','units','requested_start_utc','requested_end_utc','time_utc_or_month','value','quality','flags','event_type','retrieved_at_utc','warnings'];
    const rows = datasets().flatMap(d => d.values.map(p => [result.station.station_id, result.station.station_name, result.station.state,
      d.product, result.window.resolution, result.datum, unit(), result.window.begin_date, result.window.end_date,
      monthly() ? p.period : p.time, p.value, p.quality, p.flags, p.type, result.fetched_at,
      result.warnings.map(w => `${w.product}: ${w.message}`).join(' ')]));
    const blob = new Blob(['\uFEFF', [headers, ...rows].map(row => row.map(cell).join(',')).join('\r\n') + '\r\n'], {type:'text/csv;charset=utf-8'});
    const url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = `stranger-tides-${result.station.station_id}-${result.window.begin_date}-${result.window.end_date}-${result.window.resolution}.csv`;
    document.body.append(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 60000);
  }
  function initialize() {
    if (initialized) return; initialized = true;
    const today = new Date().toISOString().slice(0,10), past = new Date(Date.now() - 29 * 86400000).toISOString().slice(0,10);
    const params = new URLSearchParams(location.search);
    byId('history-start').value = params.get('begin_date') || past; byId('history-end').value = params.get('end_date') || today;
    for (const id of ['history-start','history-end']) byId(id).max = today;
    if (['auto','six_minute','hourly','monthly'].includes(params.get('resolution'))) byId('history-resolution').value = params.get('resolution');
    byId('historical-explorer').open = byId('historical-explorer').open || params.has('begin_date') || params.has('end_date');
    byId('history-form').addEventListener('submit', event => {event.preventDefault(); load();});
    byId('history-export').addEventListener('click', exportCsv);
    byId('history-table').addEventListener('toggle', table);
    byId('history-more').addEventListener('click', () => {limit += 500; table();});
    ['history-start','history-end','history-resolution'].forEach(id => byId(id).addEventListener('input', () => {
      request?.abort(); version++; request = null; byId('history-results').setAttribute('aria-busy','false');
      byId('history-export').disabled = true; byId('history-status').textContent = 'Dates or resolution changed. Load historical data to apply them.';
    }));
  }
  window.StationHistory = {
    reset() {
      version++; request?.abort(); request = null; result = null; key = null; requestedUnits = null; state = null; destroy();
      byId('history-export').disabled = true; byId('history-caption').textContent = ''; byId('history-table').hidden = true;
      byId('history-rows').replaceChildren(); byId('history-status').textContent = 'Choose dates and load historical data.';
      byId('history-results').setAttribute('aria-busy','false');
    },
    update(value) {
      initialize(); state = value;
      if (!key && byId('historical-explorer').open) load();
      else if (key && requestedUnits !== state.units) load();
      else render();
    }
  };
})();
