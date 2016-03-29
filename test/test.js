WiFiControl = require("../lib/wifi-control.js");

WiFiControl.init({
  debug: true,
  connectionTimeout: 2000
});


/*
 *  Get info about wireless interface!
 */
console.log( WiFiControl.getIfaceState() );

/*
 *  Scan for nearby WiFi!
 */
WiFiControl.scanForWiFi( function(error, response) {
  if (error) console.log(error);
  console.log(response);
});


/*
 *  Connect to an Access Point!
 */
var open_ap = {
  ssid: "And We Will Call It....THIS LAN!"
};
var closed_ap = {
  ssid: "And We Will Call It....THIS LAN!",
  password: "hench4life"
};

WiFiControl.connectToAP( closed_ap, function(error, response) {
  if (error) console.log(error);
  console.log(response);
});

/*
 *  Reset the WiFi card!
 */
WiFiControl.resetWiFi( function(error, response) {
  if (error) console.log(error);
  console.log(response);
});
