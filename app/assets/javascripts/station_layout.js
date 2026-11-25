/* global Highcharts */
(() => {
  'use strict';
  const byId = id => document.getElementById(id), views = ['now','tides','weather','history'];
  let view = 'now', drawer, lastStation;
  const positions = new Map();
  function reflow() {
    requestAnimationFrame(() => (window.Highcharts?.charts || []).filter(c => c && c.renderTo.offsetParent !== null).forEach(c => c.reflow()));
  }
  function closeDrawer(restore = false) {
    const old = drawer;
    ['filters','list'].forEach(name => {
      byId(name === 'filters' ? 'station-filters' : 'station-list').hidden = true;
      byId(`toggle-${name}`).setAttribute('aria-expanded','false');
    });
    drawer = null;
    if (restore && old) byId(`toggle-${old}`).focus({preventScroll:true});
  }
  function openDrawer(name, focus = false) {
    closeDrawer(); drawer = name;
    const panel = byId(name === 'filters' ? 'station-filters' : 'station-list');
    panel.hidden = false; byId(`toggle-${name}`).setAttribute('aria-expanded','true');
    if (focus) panel.querySelector('select,button').focus({preventScroll:true});
  }
  function showView(name, focus = false) {
    if (!views.includes(name)) return;
    if (byId(`tab-${name}`).hidden) name = 'now';
    const body = byId('station-panel').querySelector('.station-body'), changed = view !== name;
    if (changed) positions.set(view, body.scrollTop);
    view = name;
    views.forEach(value => {
      byId(`view-${value}`).hidden = value !== name;
      const tab = byId(`tab-${value}`); tab.setAttribute('aria-selected',String(value === name)); tab.tabIndex = value === name ? 0 : -1;
    });
    const url = new URL(location.href);
    if (name === 'now') url.searchParams.delete('tab'); else url.searchParams.set('tab',name);
    history.replaceState(null,'',url);
    if (name === 'history') byId('historical-explorer').open = true;
    if (focus) byId(`tab-${name}`).focus({preventScroll:true});
    byId('station-panel').dataset.view = name; reflow();
    if (changed) body.scrollTop = positions.get(name) || 0;
  }
  document.addEventListener('DOMContentLoaded', () => {
    if (!byId('station-explorer')) return;
    const params = new URLSearchParams(location.search), initial = params.get('tab');
    view = views.includes(initial) ? initial : params.has('begin_date') ? 'history' : 'now';
    ['filters','list'].forEach(name => byId(`toggle-${name}`).addEventListener('click', () => drawer === name ? closeDrawer() : openDrawer(name)));
    document.querySelectorAll('[data-close-drawer]').forEach(button => button.addEventListener('click', () => closeDrawer(true)));
    document.querySelectorAll('.drawer').forEach(panel => panel.addEventListener('keydown', event => {
      if (event.key === 'Escape') {event.stopPropagation(); closeDrawer(true);}
    }));
    byId('station-search').addEventListener('input', () => openDrawer('list'));
    byId('station-search').addEventListener('keydown', event => {
      if (event.key === 'ArrowDown') {event.preventDefault(); openDrawer('list'); byId('station-results').querySelector('button')?.focus();}
      if (event.key === 'Escape') closeDrawer(true);
    });
    views.forEach(name => {
      const tab = byId(`tab-${name}`); tab.addEventListener('click', () => showView(name));
      tab.addEventListener('keydown', event => {
        const visible = views.filter(value => !byId(`tab-${value}`).hidden), index = visible.indexOf(name);
        const next = event.key === 'ArrowRight' ? visible[(index+1)%visible.length] : event.key === 'ArrowLeft' ? visible[(index+visible.length-1)%visible.length] : event.key === 'Home' ? visible[0] : event.key === 'End' ? visible.at(-1) : null;
        if (next) {event.preventDefault(); showView(next,true);}
      });
    });
    byId('open-tides').addEventListener('click', () => showView('tides',true));
    byId('expand-station').addEventListener('click', () => {
      const expanded = byId('station-explorer').classList.toggle('panel-expanded');
      byId('expand-station').setAttribute('aria-expanded',String(expanded));
      byId('expand-station').setAttribute('aria-label',expanded ? 'Collapse station panel' : 'Expand station panel');
      byId('expand-station').textContent = expanded ? '⌄' : '⌃'; reflow();
    });
    window.addEventListener('resize',reflow);
    byId('display-options').addEventListener('toggle',reflow);
  });
  window.StationLayout = {
    showView, openDrawer, reflow,
    selected(station) {
      closeDrawer(); byId('station-explorer').classList.add('has-station');
      if (lastStation !== station.station_id) {positions.clear(); byId('station-panel').querySelector('.station-body').scrollTop = 0;}
      lastStation = station.station_id; showView(view);
    },
    closed() {
      closeDrawer(); byId('station-explorer').classList.remove('has-station','panel-expanded');
      byId('expand-station').setAttribute('aria-expanded','false'); byId('expand-station').setAttribute('aria-label','Expand station panel');
      byId('expand-station').textContent = '⌃'; lastStation = null; positions.clear(); reflow();
    }
  };
})();
