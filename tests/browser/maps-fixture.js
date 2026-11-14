// Minimal Maps adapter. Hosted checks exercise the real SDK separately.
(() => {
  class Map {
    constructor(element, options) {
      this.element = element; this.setZoom(options.zoom); this.setCenter(options.center);
      element.setAttribute('role', 'region'); element.setAttribute('aria-label', 'Map');
    }
    setZoom(value) { this.zoom = value; this.element.dataset.zoom = value; }
    getZoom() { return this.zoom; }
    setCenter(value) { this.element.dataset.center = JSON.stringify(value); }
    addListener() {}
  }
  class Marker {
    constructor(options) {
      Object.assign(this, options);
      this.button = document.createElement('button'); this.button.textContent = options.title;
      if (options.icon) {
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
  window.google = { maps: { Map, Marker, InfoWindow } };
  window.initMap();
})();
