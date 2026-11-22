/* global google */
(() => {
  'use strict';
  const position = station => ({lat: Number(station.latitude), lng: Number(station.longitude)});
  const element = (tag, text, className) => {
    const node = document.createElement(tag); node.textContent = text;
    if (className) node.className = className;
    return node;
  };
  window.StationSpread = {
    create({map, host, label, extras, select}) {
      let root, restoreFocus, openingScroll;
      const bridge = new google.maps.OverlayView();
      bridge.onAdd = bridge.draw = bridge.onRemove = () => {};
      bridge.setMap(map);
      function close(returnFocus) {
        const current = root;
        const shouldRestore = returnFocus === undefined ? current?.contains(document.activeElement) : returnFocus;
        root = null; current?.remove();
        if (shouldRestore) {
          const target = restoreFocus?.isConnected ? restoreFocus : host;
          if (!target.hasAttribute('tabindex') && target === host) target.tabIndex = -1;
          target.focus({preventScroll: true});
        }
      }
      ['click', 'dragstart', 'zoom_changed', 'bounds_changed'].forEach(event => map.addListener(event, () => close()));
      window.addEventListener('resize', () => close());
      window.addEventListener('scroll', () => {
        if (root && (scrollX !== openingScroll.x || scrollY !== openingScroll.y)) close();
      }, {passive: true});
      function open(station, stations) {
        const projection = bridge.getProjection();
        const anchor = projection?.fromLatLngToContainerPixel(position(station));
        if (!anchor) {select(station); return;}
        const worldWidth = projection.getWorldWidth();
        const nearby = stations.filter(candidate => {
          const point = projection.fromLatLngToContainerPixel(position(candidate));
          if (!point) return false;
          let dx = point.x - anchor.x;
          if (worldWidth) dx -= Math.round(dx / worldWidth) * worldWidth;
          return Math.abs(dx) <= 40 && Math.abs(point.y - anchor.y) <= 48;
        });
        if (nearby.length < 2) {select(station); return;}
        close(); restoreFocus = document.activeElement;
        // Keep the tapped station first; filtering searches the entire overlap set.
        nearby.sort((a, b) => a.station_id === b.station_id ? 0 : a.station_id === station.station_id ? -1 : b.station_id === station.station_id ? 1 : label(a).localeCompare(label(b)));
        root = element('section', '', 'station-spread');
        const current = root;
        root.setAttribute('role', 'dialog'); root.setAttribute('aria-label', 'Choose an overlapping station');
        const header = element('div', '', 'spread-header');
        const search = document.createElement('input'); search.type = 'search';
        search.placeholder = `Search ${nearby.length} overlapping stations`;
        search.setAttribute('aria-label', 'Search overlapping stations');
        const dismiss = element('button', '×'); dismiss.type = 'button'; dismiss.setAttribute('aria-label', 'Close overlapping stations');
        dismiss.addEventListener('click', () => close(true)); header.append(search, dismiss);
        const area = element('div', '', 'spread-area');
        const footer = element('div', '', 'spread-footer');
        const previous = element('button', 'Previous'), next = element('button', 'Next');
        previous.type = next.type = 'button';
        const status = element('span', ''); status.setAttribute('role', 'status');
        footer.append(previous, status, next); root.append(header, area, footer); host.append(root);
        const mapRect = host.getBoundingClientRect();
        const top = Math.max(8, mapRect.top), bottom = Math.min(innerHeight - 8, mapRect.bottom);
        if (bottom - top >= 320) {
          root.style.top = `${top - mapRect.top}px`; root.style.bottom = 'auto'; root.style.height = `${bottom - top}px`;
        } else {
          // A partly visible map still gets a complete picker, without scrolling the page.
          const height = Math.min(innerHeight - 16, Math.max(320, mapRect.height));
          const width = Math.min(innerWidth - 16, mapRect.width);
          root.style.position = 'fixed'; root.style.inset = 'auto';
          root.style.top = `${Math.max(8, Math.min(innerHeight - height - 8, mapRect.top))}px`;
          root.style.left = `${Math.max(8, Math.min(innerWidth - width - 8, mapRect.left))}px`;
          root.style.height = `${height}px`; root.style.width = `${width}px`;
        }
        openingScroll = {x: scrollX, y: scrollY};
        google.maps.OverlayView.preventMapHitsAndGesturesFrom(root);
        let page = 0;
        function render() {
          if (root !== current) return;
          const query = search.value.trim().toLocaleLowerCase();
          const matches = nearby.filter(s => `${label(s)} ${s.station_id}`.toLocaleLowerCase().includes(query));
          const width = area.clientWidth, height = area.clientHeight;
          const buttonWidth = Math.min(136, Math.max(72, (width - 30) / 3));
          const radius = Math.max(0, Math.min(144, (height - 46) / 2, (width - buttonWidth - 20) / 2));
          const pageSize = radius >= 89 ? 6 : radius >= 45 && radius * 2 >= buttonWidth + 2 ? 4 : radius >= 23 ? 2 : 1;
          const shown = matches.slice(page * pageSize, (page + 1) * pageSize);
          previous.disabled = page === 0; next.disabled = (page + 1) * pageSize >= matches.length;
          status.textContent = matches.length ? `${page * pageSize + 1}–${Math.min((page + 1) * pageSize, matches.length)} of ${matches.length}` : 'No matching stations';
          area.replaceChildren();
          const mapBounds = host.getBoundingClientRect(), pickerBounds = current.getBoundingClientRect();
          const origin = {x: anchor.x + mapBounds.left - pickerBounds.left,
            y: anchor.y + mapBounds.top - pickerBounds.top - header.offsetHeight};
          const clamp = (value, padding, size) => Math.max(padding, Math.min(size - padding, value));
          const cx = clamp(origin.x, radius + buttonWidth / 2 + 6, width);
          const cy = clamp(origin.y, radius + 22, height);
          const lines = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
          lines.setAttribute('width', width); lines.setAttribute('height', height); lines.setAttribute('aria-hidden', 'true');
          area.append(lines);
          shown.forEach((s, index) => {
            const slots = shown.length === 5 ? 6 : shown.length;
            const angle = -Math.PI / 2 + index * 2 * Math.PI / slots;
            const x = cx + radius * Math.cos(angle), y = cy + radius * Math.sin(angle);
            const line = document.createElementNS(lines.namespaceURI, 'line');
            line.setAttribute('x1', origin.x); line.setAttribute('y1', origin.y);
            line.setAttribute('x2', x); line.setAttribute('y2', y); lines.append(line);
            const button = element('button', '', `spread-station${extras(s) ? ' extra-products' : ''}`);
            button.append(element('span', label(s)), element('small', s.station_id));
            button.type = 'button'; button.dataset.stationId = s.station_id;
            button.setAttribute('aria-label', `${label(s)} ${s.station_id}${extras(s) ? ' · Additional products' : ''}`);
            button.title = `${label(s)} ${s.station_id}`;
            button.style.left = `${x}px`; button.style.top = `${y}px`; button.style.width = `${buttonWidth}px`;
            button.addEventListener('click', () => {close(true); select(s);}); area.append(button);
          });
        }
        search.addEventListener('input', () => {page = 0; render();});
        const turn = direction => {page += direction; render(); area.querySelector('button')?.focus({preventScroll: true});};
        previous.addEventListener('click', () => turn(-1)); next.addEventListener('click', () => turn(1));
        root.addEventListener('keydown', event => {if (event.key === 'Escape') {event.preventDefault(); event.stopPropagation(); close(true);}});
        root.addEventListener('focusout', event => {if (event.relatedTarget && !current.contains(event.relatedTarget)) close(false);});
        area.addEventListener('click', event => {if (event.target === area) close(true);});
        render(); area.querySelector('button')?.focus({preventScroll: true});
      }
      return {open, close};
    }
  };
})();
