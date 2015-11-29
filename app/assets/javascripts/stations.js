// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.
// alert(gon.metadata);
// console.log(gon.metadata);
// console.log(gon.metadata.station_name);
console.log("This is the name: " + gon.metadata.station_name);

var array_keys = new Array();
var array_values = new Array();

for (var key in gon.metadata) {
    array_keys.push(key);
    array_values.push(gon.metadata[key]);
}


var map;
var myLatLng = {
    lat: parseFloat(array_values[2]),
    lng: parseFloat(array_values[3])
};

function initMap() {
    map = new google.maps.Map(document.getElementById('map'), {
        center: myLatLng,
        zoom: 10
    });
    var marker = new google.maps.Marker({
        position: myLatLng,
        map: map,
        title: array_values[0] + " Station: " + array_values[1]
    });
}
