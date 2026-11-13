// Minimal Maps adapter for deterministic application tests. Real SDK checks are separate.
(() => {
  class Map {
    constructor(element, options) {
      this.element = element; this.setZoom(options.zoom); this.setCenter(options.center);
      this.controls = { TOP_CENTER: { push: node => element.append(node) } };
      element.setAttribute('role', 'region'); element.setAttribute('aria-label', 'Map');
    }
    setZoom(value) { this.element.dataset.zoom = value; }
    setCenter(value) { this.element.dataset.center = JSON.stringify(value); }
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
    getMap() { return this.map; }
    getPosition() { return this.position; }
  }
  class InfoWindow {
    close() { this.node?.remove(); }
    setContent(value) { this.content = value; }
    open(map) {
      this.close(); this.node = document.createElement('div');
      this.node.textContent = this.content; this.node.setAttribute('role', 'dialog'); map.element.append(this.node);
    }
  }
  window.google = { maps: {
    Map, Marker, InfoWindow,
    LatLng: class { constructor(lat, lng) { this.lat = lat; this.lng = lng; } },
    Size: class {}, Point: class {}, ControlPosition: { LEFT_TOP: 'LEFT_TOP', TOP_CENTER: 'TOP_CENTER' },
    event: { addListener: (object, name, callback) => object.addListener(name, callback) }
  } };
  window.initMap();
})();
