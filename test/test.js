WiFiControl = require("../lib/wifi-control.js");

WiFiControl.init({
  debug: true,
  connectionTimeout: 2000
});

console.log( WiFiControl.getIfaceState() );
/*
WiFiControl.scanForWiFi( function(error, response) {
  //if (error) console.log(error);
  console.log(response);
});
*/

var test_ap = {
  ssid: "xfinitywifi"
  /*
  ssid: "And We Will Call It....THIS LAN!",
  password: "poopscuttle"
  */
};

/*
WiFiControl.connectToAP( test_ap, function(error, response) {
  if (error) console.log(error);
  console.log(response);
});
*/

WiFiControl.resetWiFi( function(error, response) {
  if (error) console.log(error);
  console.log(response);
});
