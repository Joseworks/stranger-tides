// Minimal Maps adapter. Hosted checks exercise the real SDK separately.
(() => {
  class Map {
    constructor(element, options) {
      this.listeners = {}; window.fixtureMap = this;
      this.element = element; this.setZoom(options.zoom); this.setCenter(options.center);
      element.setAttribute('role', 'region'); element.setAttribute('aria-label', 'Map');
    }
    setZoom(value) { this.zoom = value; this.element.dataset.zoom = value; this.listeners.idle?.(); }
    getZoom() { return this.zoom; }
    setCenter(value) { this.element.dataset.center = JSON.stringify(value); this.listeners.idle?.(); }
    addListener(name, callback) { this.listeners[name] = callback; }
  }
  class Marker {
    constructor(options) {
      Object.assign(this, options);
      this.button = document.createElement('button'); this.button.textContent = options.title;
      if (typeof options.icon === 'string') {
        const image = document.createElement('img'); image.src = options.icon; image.alt = '';
        this.button.prepend(image);
      }
      options.map.element.append(this.button);
    }
    addListener(name, callback) { this.button.addEventListener(name, () => callback.call(this)); }
    setMap(map) { if (!map) this.button.remove(); }
  }
  class InfoWindow {
    close() { this.node?.remove(); }
    setContent(content) { this.content = content; }
    setPosition() {}
    open(map) {
      this.close(); this.node = document.createElement('div');
      this.node.append(this.content); this.node.setAttribute('role', 'dialog'); map.element.append(this.node);
    }
  }
  window.google = { maps: { Map, Marker, InfoWindow, SymbolPath: { CIRCLE: 0 } } };
  window.initMap();
})();
