// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

// Array structure: ["station_id", "station_name", "latitude", "longitude", "errors"]
// console.log("This is the name: " + gon.metadata.station_name);

var array_keys = new Array();
var array_values = new Array();

for (var key in gon.metadata) {
    array_keys.push(key);
    array_values.push(gon.metadata[key]);
}

// console.log("This is the id: " + parseFloat(array_values[0]));
// console.log("This is the latitude: " + parseFloat(array_values[2]));
// console.log("This is the longitude: " + parseFloat(array_values[3]));

// console.log(gon.all_station_metadata[0].station_id);
// console.log(gon.all_station_metadata[0].station_name);

function split(a, n) {
    var len = a.length,out = [], i = 0;
    while (i < len) {
        var size = Math.ceil((len - i) / n--);
        out.push(a.slice(i, i + size));
        i += size;
    }
    return out;
}



var station_name = new Array();
var station_markers = new Array();
var station_markers_array = new Array();




var all_stations = gon.all_station_metadata

  for (var i = 0; i < all_stations.length; i++) {
    var station = all_stations[i];
    station_name.push(all_stations[i].station_name);
    station_name.push(parseFloat(all_stations[i].latitude));
    station_name.push(parseFloat(all_stations[i].longitude));

    // console.log(station_name)


       // station_markers.push(station_name)
    // console.log(station_markers)


  //   var marker = new google.maps.Marker({
  //     position: {lat: station[1], lng: station[2]},
  //     map: map,
  //     // icon: image,
  //     shape: shape,
  //     title: station[0],
  //     zIndex: station[3]
  //   });
  }

// console.log(all_stations.length);

var station_markers = split(station_name, all_stations.length);

  for (var i = 0; i < station_markers.length; i++) {
    station_markers_array.push(station_markers[i]);

  }

    // console.log(station_markers_array.length);

  // for (var i = 0; i < station_markers_array.length; i++) {
    // console.log(station_markers_array[i]);
  // }

    console.log(station_markers_array);

// var map;
// var myLatLng = {
//     lat: parseFloat(array_values[2]),
//     lng: parseFloat(array_values[3])
// };

// function initMap() {
//     map = new google.maps.Map(document.getElementById('map'), {
//         center: myLatLng,
//         zoom: 10
//     });
//     var marker = new google.maps.Marker({
//         position: myLatLng,
//         map: map,
//         title: array_values[0] + " Station: " + array_values[1]
//     });
// }

function initMap() {
  var map = new google.maps.Map(document.getElementById('full_map'), {
    zoom: 3,
    center: {lat: 38.88, lng: -98.35}
  });

  setMarkers(map);
}

// Data for the markers consisting of a name, a LatLng and a zIndex for the
// order in which these markers should display on top of each other.
var stations = station_markers_array;
function setMarkers(map) {
  // Adds markers to the map.

  // Marker sizes are expressed as a Size of X,Y where the origin of the image
  // (0,0) is located in the top left of the image.

  // Origins, anchor positions and coordinates of the marker increase in the X
  // direction to the right and in the Y direction down.
  var image = {
    // url: 'images/stationflag.png',
    // This marker is 20 pixels wide by 32 pixels high.
    size: new google.maps.Size(20, 32),
    // The origin for this image is (0, 0).
    origin: new google.maps.Point(0, 0),
    // The anchor for this image is the base of the flagpole at (0, 32).
    anchor: new google.maps.Point(0, 32)
  };
  // Shapes define the clickable region of the icon. The type defines an HTML
  // <area> element 'poly' which traces out a polygon as a series of X,Y points.
  // The final coordinate closes the poly by connecting to the first coordinate.
  var shape = {
    coords: [1, 1, 1, 20, 18, 20, 18, 1],
    type: 'poly'
  };
  for (var i = 0; i < stations.length; i++) {
    var station = stations[i];
    console.log(station)
    var marker = new google.maps.Marker({
      position: {lat: station[1], lng: station[2]},
      map: map,
      // icon: image,
      // shape: shape,
      title: station[0]
      // zIndex: station[3]
    });
  }
}