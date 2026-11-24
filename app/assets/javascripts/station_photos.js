(() => {
  'use strict';
  const byId = id => document.getElementById(id);
  let station, request, generation = 0, loaded = false;
  function node(tag, value) {const el = document.createElement(tag); el.textContent = value; return el;}
  function gallery(url, count) {
    const link = node('a', count ? `View ${count > 1 ? `all ${count} photos` : 'photo'} at NOAA` : 'View this station at NOAA');
    link.href = url; link.target = '_blank'; link.rel = 'noopener noreferrer'; return link;
  }
  async function load() {
    if (!station || request || loaded) return;
    const current = station, token = ++generation, content = byId('station-photo-content');
    const controller = new AbortController(); request = controller;
    const timer = setTimeout(() => controller.abort(), 10000);
    content.replaceChildren(node('p','Loading NOAA station photo…')); content.setAttribute('aria-busy','true');
    try {
      const response = await fetch(`/stations/${encodeURIComponent(current.station_id)}/photo`,{signal:controller.signal});
      if (!response.ok) throw new Error('Photo unavailable');
      const payload = await response.json();
      if (token !== generation) return;
      if (payload.station_id !== current.station_id) throw new Error('Photo station mismatch');
      loaded = true;
      if (!payload.image_url) {
        content.replaceChildren(node('p','NOAA has no published station photo for this location.'),gallery(payload.gallery_url)); return;
      }
      const figure = document.createElement('figure'), image = document.createElement('img');
      const name = current.state && !current.station_name.endsWith(`, ${current.state}`) ? `${current.station_name}, ${current.state}` : current.station_name;
      image.alt = `NOAA photograph of ${name} (station ${current.station_id})`;
      image.loading = 'lazy'; image.decoding = 'async'; image.referrerPolicy = 'no-referrer';
      image.addEventListener('error', () => {
        if (token !== generation) return;
        content.replaceChildren(node('p','The NOAA photo could not be loaded.'),gallery(payload.gallery_url,payload.photo_count));
      },{once:true});
      image.src = payload.image_url;
      figure.append(image,node('figcaption','NOAA CO-OPS · Archive photograph, not a live camera.'));
      content.replaceChildren(figure,gallery(payload.gallery_url,payload.photo_count));
    } catch (_) {
      if (token !== generation) return;
      const retry = node('button','Retry station photo'); retry.type = 'button'; retry.addEventListener('click',load);
      const url = `https://tidesandcurrents.noaa.gov/stationphotos.html?id=${encodeURIComponent(current.station_id)}`;
      content.replaceChildren(node('p','The NOAA photo is unavailable right now. Station data remain available.'),retry,document.createTextNode(' '),gallery(url));
    } finally {
      clearTimeout(timer);
      if (token === generation) {request = null; content.removeAttribute('aria-busy');}
    }
  }
  document.addEventListener('DOMContentLoaded', () => {
    byId('station-photo')?.addEventListener('toggle',() => {if (byId('station-photo').open) load();});
  });
  window.StationPhotos = {reset(selected = null) {
    generation++; request?.abort(); request = null; station = selected; loaded = false;
    byId('station-photo').open = false; byId('station-photo-content').replaceChildren();
    byId('station-photo-content').removeAttribute('aria-busy');
  }};
})();
