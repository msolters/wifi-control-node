WiFiControl = require("../lib/wifi-control.js");

WiFiControl.init({
  debug: true
});

console.log( WiFiControl.getIfaceState() );

WiFiControl.scanForWiFi( function(error, response) {
  if (error) console.log(error);
  console.log(response);
});

/*
console.log( WiFiControl.connectToAP({
  ssid: "xfinitywifi"
}) );

console.log( WiFiControl.resetWiFi() );
*/
