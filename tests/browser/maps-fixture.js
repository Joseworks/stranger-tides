// Minimal Maps adapter. Hosted checks exercise the real SDK separately.
(() => {
  const world = value => {
    const sin = Math.sin(value.lat * Math.PI / 180);
    return {x: (value.lng + 180) / 360, y: .5 - Math.log((1 + sin) / (1 - sin)) / (4 * Math.PI)};
  };
  class Map {
    constructor(element, options) {
      this.listeners = {}; window.fixtureMap = this;
      this.element = element; this.center = options.center; this.setZoom(options.zoom); this.setCenter(options.center);
      element.setAttribute('role', 'region'); element.setAttribute('aria-label', 'Map');
    }
    emit(name) {this.listeners[name]?.forEach(fn => fn());}
    setZoom(value) { this.zoom = value; this.element.dataset.zoom = value; this.emit('zoom_changed'); this.emit('bounds_changed'); this.emit('idle'); }
    getZoom() { return this.zoom; }
    setCenter(value) { this.center = value; this.element.dataset.center = JSON.stringify(value); this.emit('bounds_changed'); this.emit('idle'); }
    getBounds() {return {contains: value => {const p=this.project(value); return p.x>=0 && p.x<=this.element.clientWidth && p.y>=0 && p.y<=this.element.clientHeight;}};}
    project(value) {
      const p=world(value), c=world(this.center), size=256*2**this.zoom;
      let dx=p.x-c.x; dx-=Math.round(dx);
      return {x:this.element.clientWidth/2+dx*size,y:this.element.clientHeight/2+(p.y-c.y)*size};
    }
    addListener(name, callback) { (this.listeners[name] ||= []).push(callback); }
  }
  class Marker {
    constructor(options) {
      Object.assign(this, options);
      this.button = document.createElement('button'); this.button.textContent = options.title;
      if (typeof options.icon === 'string' || options.icon?.url) {
        const image = document.createElement('img'); image.src = typeof options.icon === 'string' ? options.icon : options.icon.url; image.alt = '';
        this.button.prepend(image);
      }
      options.map.element.append(this.button);
    }
    addListener(name, callback) { this.button.addEventListener(name, () => callback.call(this)); }
    setMap(map) { if (!map) this.button.remove(); }
  }
  class AdvancedMarkerElement {
    constructor(options) {Object.assign(this, options); this.button=options.content; options.map.element.append(this.button);}
    addListener(name, callback) {this.button.addEventListener(name, callback);}
    set map(value) {if (!value) this.button?.remove();}
  }
  class OverlayView {
    setMap(map) {this.map=map; this.onAdd(); this.draw();}
    getProjection() {return {fromLatLngToContainerPixel:value=>this.map.project(value),getWorldWidth:()=>256*2**this.map.zoom};}
    static preventMapHitsAndGesturesFrom() {}
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
  window.google = {maps:{Map,Marker,InfoWindow,OverlayView,marker:{AdvancedMarkerElement}}};
  if (window.useAdvancedMarkersFixture) document.querySelector('#full_map').dataset.mapId='offline-map';
  window.initMap();
})();
