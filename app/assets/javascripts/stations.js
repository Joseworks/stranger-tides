var station_name = new Array();
var station_markers = new Array();
var station_markers_array = new Array();
var all_stations = gon.all_station_metadata;



function initMap() {
  var map = new google.maps.Map(document.getElementById('full_map'), {
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
    console.log('No valid stations to show!')
  };

}



function myPosition(map) {
  // This adds the marker for my location ( From Dominique snippet :)
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(function(position) {
      var lat = position.coords.latitude;
      var lon = position.coords.longitude;
      var myLatLng = {
        lat: lat,
        lng: lon
      };

      var marker = new google.maps.Marker({
        position: myLatLng,
        map: map,
        title: " You are SO HERE"
      });

      var infoWindow = new google.maps.InfoWindow({
        map: map
      });
      infoWindow.setPosition(myLatLng);
      infoWindow.setContent('Your location has been found. Use the controls to zoom in or out');
      map.setCenter(myLatLng);
      map.setZoom(14);
      var lineSymbol = {
        path: google.maps.SymbolPath.CIRCLE,
        scale: 8,
        strokeColor: '#3367d6'
      };

      var line = new google.maps.Polyline({
        path: [{
          lat: lat,
          lng: lon
        }, {
          lat: lat - .0001,
          lng: lon
        }],
        icons: [{
          icon: lineSymbol,
          offset: '100%'
        }],
        map: map
      });

      animateCircle(line);




      marker.addListener('click', function() {
        map.setZoom(10);
        map.setCenter(marker.getPosition());
        console.log('It is here!');



        // $("div.tide-graph").click(function() {
        $.ajax({
          url: "./show_graph",
          type: "POST",
          data: {
            content: marker[0]
          }
        }).success(function(data) {
          console.log('made it to ajax success!');
          $("div.tide-graph").replaceWith("<h2>Something else</h2>");

        });
        // });

      });


    });
  }
}

function setMarkers(map, stations) {
  // Adds markers to the map.
  // Marker sizes are expressed as a Size of X,Y where the origin of the image
  // (0,0) is located in the top left of the image.
  // Origins, anchor positions and coordinates of the marker increase in the X
  // direction to the right and in the Y direction down.
  // Data for the markers consisting of a name, a LatLng and a zIndex for the
  // order in which these markers should display on top of each other.
  var image = {
    url: '/images/orange_marker.png',
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
    var marker = new google.maps.Marker({
      position: {
        lat: station[1],
        lng: station[2]
      },
      map: map,
      icon: asset_path('orange_marker.png'),
      // shape: shape,
      title: station[0]
        // zIndex: station[3]
    });

    marker.addListener('click', function() {
      // map.setZoom(12);
      // console.log(marker.getPosition())
    console.log(marker)
    });

    // google.maps.event.addListener( marker.serviceObject, 'click', function(object) {
    // alert('lat: '+object.latLng.Na+' long: '+object.latLng.Oa);
    // });

  }
}

function formArray(all_stations) {
  for (var i = 0; i < all_stations.length; i++) {
    var station = all_stations[i];
    station_name.push(all_stations[i].station_name);
    station_name.push(parseFloat(all_stations[i].latitude));
    station_name.push(parseFloat(all_stations[i].longitude));
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
