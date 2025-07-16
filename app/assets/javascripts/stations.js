var station_name = new Array();
var station_markers = new Array();
var station_markers_array = new Array();
var all_stations = gon.all_station_metadata;
var map_div = 'full_map'

function CenterControl(controlDiv, map, center) {
  // We set up a variable for this since we're adding event listeners
  // later.
  var control = this;

  // Set the center property upon construction
  control.center_ = center;
  controlDiv.style.clear = 'both';

  // Set CSS for the control border
  var goCenterUI = document.createElement('div');
  goCenterUI.id = 'goCenterUI';
  goCenterUI.title = 'Click to recenter the map';
  controlDiv.appendChild(goCenterUI);

  // Set CSS for the control interior
  var goCenterText = document.createElement('div');
  goCenterText.id = 'goCenterText';
  goCenterText.innerHTML = 'Center Map on your location';
  goCenterUI.appendChild(goCenterText);

  // Set CSS for the setCenter control border
  var setCenterUI = document.createElement('div');
  setCenterUI.id = 'setCenterUI';
  setCenterUI.title = 'Click to change the center of the map';
  controlDiv.appendChild(setCenterUI);


  // Set up the click event listener for 'Center Map': Set the center of
  // the map
  // to the current center of the control.
  goCenterUI.addEventListener('click', function() {
    var currentCenter = control.getCenter();
    map.setZoom(9);
    map.setCenter(currentCenter);
  });
}

/**
 * Define a property to hold the center state.
 * @private
 */
CenterControl.prototype.center_ = null;

/**
 * Gets the map center.
 * @return {?google.maps.LatLng}
 */
CenterControl.prototype.getCenter = function() {
  return this.center_;
};

/**
 * Sets the map center.
 * @param {?google.maps.LatLng} center
 */
CenterControl.prototype.setCenter = function(center) {
  this.center_ = center;
};


function initMap() {
  var map = new google.maps.Map(document.getElementById(map_div), {
    zoom: 3,
    scaleControl: true,
    streetViewControl: true,
    zoomControl: true,
    mapTypeControl: true,
    scaleControl: true,
    rotateControl: true,
    scaleControlOptions: {
      position: google.maps.ControlPosition.LEFT_TOP
    },
    center: {
      lat: 38.88,
      lng: -98.35
    }
  });
  myPosition(map);

  if (all_stations != null) {
    formArray(all_stations);
    var stations = station_markers_array;
    setMarkers(map, stations);
  } else {
    alert('No valid stations to show!')
  };

}


function myPosition(map) {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(function(position) {
      var lat = position.coords.latitude;
      var lon = position.coords.longitude;
      var myLatLng = {
        lat: lat,
        lng: lon
      };

      // Create the DIV to hold the control and call the CenterControl()
      // constructor
      // passing in this DIV.
      var centerControlDiv = document.createElement('div');
      var centerControl = new CenterControl(centerControlDiv, map, myLatLng);

      centerControlDiv.index = 1;
      centerControlDiv.style['padding-top'] = '10px';
      map.controls[google.maps.ControlPosition.TOP_CENTER].push(centerControlDiv);

      var marker = new google.maps.Marker({
        position: myLatLng,
        map: map,
        title: " You are SO HERE"
      });

      var infoWindow = new google.maps.InfoWindow({
        map: map,
        maxWidth: 200
      });

      marker.addListener('click', function() {
        map.setZoom(5);
        map.setCenter(marker.getPosition());
      });
    });
  }
}



function setMarkers(map, stations) {
  var image = {
    url: '/images/orange_marker.png',
    size: new google.maps.Size(20, 32),
    origin: new google.maps.Point(0, 0),
    anchor: new google.maps.Point(0, 32)
  };

  var shape = {
    coords: [1, 1, 1, 20, 18, 20, 18, 1],
    type: 'poly'
  };

  for (var i = 0; i < stations.length; i++) {
    var station = stations[i];
    var marker_station_name = station[0] + " " + station[3].toString()
    var tmpLat = station[1];
    var tmpLng = station[2];
    var tmpName = marker_station_name;
    var marker = _newGoogleMapsMarker({
      _map: map,
      _lat: tmpLat,
      _lng: tmpLng,
      _head: '|' + new google.maps.LatLng(tmpLat, tmpLng),
      _data: tmpName
    });

  }
}


function _newGoogleMapsMarker(param) {
  var r = new google.maps.Marker({
    map: param._map,
    position: new google.maps.LatLng(param._lat, param._lng),
    icon: asset_path('orange_marker.png'),
    title: param._data
  });
  if (param._data) {
    google.maps.event.addListener(r, 'click', function() {
      var selected_station = extract_station(r.title);
      ajaxToController(selected_station);
      // this -> the marker on which the on click event is being attached
      if (!this.getMap()._infoWindow) {
        this.getMap()._infoWindow = new google.maps.InfoWindow();
      }
      this.getMap()._infoWindow.close();
      this.getMap()._infoWindow.setContent(param._data);
      this.getMap()._infoWindow.open(this.getMap(), this);
    });
  }
  return r;
}


function extract_station(full_title) {
  var n = full_title.split(" ");
  last_word = n[n.length - 1];
  return parseInt(last_word);
}

function ajaxToController(station_sent) {
  $.ajax({
    url: "./show_graph",
    type: "POST",
    data: {
      content: station_sent
    }
  }).success(function(data) {});
};


function formArray(all_stations) {
  for (var i = 0; i < all_stations.length; i++) {
    var station = all_stations[i];
    station_name.push(all_stations[i].station_name);
    station_name.push(parseFloat(all_stations[i].latitude));
    station_name.push(parseFloat(all_stations[i].longitude));
    station_name.push(parseFloat(all_stations[i].station_id));
  }

  var station_markers = split(station_name, all_stations.length);

  for (var i = 0; i < station_markers.length; i++) {
    station_markers_array.push(station_markers[i]);
  }
};

function split(a, n) {
  var len = a.length,
    out = [],
    i = 0;
  while (i < len) {
    var size = Math.ceil((len - i) / n--);
    out.push(a.slice(i, i + size));
    i += size;
  }
  return out;
}


function animateCircle(line) {
  var count = 0;
  window.setInterval(function() {
    count = (count + 1) % 200;
    var icons = line.get('icons');
    icons[0].offset = (count / 2) + '%';
    line.set('icons', icons);
  }, 20);
}


function removeGraph() {
  var elem_1 = document.getElementById('tide-graph-container');
  var elem_2 = document.getElementById('tide-graph');
  
  if (elem_1 && elem_1.parentNode) {
    elem_1.parentNode.removeChild(elem_1);
  }
  
  if (elem_2 && elem_2.parentNode) {
    elem_2.parentNode.removeChild(elem_2);
  }
  
  $('#map-container-small').attr("id", "map-container-full");
  return false;
}
