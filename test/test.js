WiFiControl = require("../lib/wifi-control.js");

WiFiControl.init({
  debug: true,
  connectionTimeout: 2000
});

console.log( WiFiControl.getIfaceState() );

WiFiControl.scanForWiFi( function(error, response) {
  //if (error) console.log(error);
  console.log(response);
});

test_ap = ;

WiFiControl.events.on('connect-to-ap', function(results) {
  console.log( results );
});

console.log( WiFiControl.connectToAP( {
  ssid: "And We Will Call It....THIS LAN!",
  password: "poopscuttle"
} ) );

/*
console.log( WiFiControl.resetWiFi() );
*/
