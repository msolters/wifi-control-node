WiFiControl = require("../lib/wifi-control.js");
WiFiControl.init({
  debug: true
});
console.log( WiFiControl.getIfaceState() );
WiFiControl.scanForWiFi( function(err, response) {
  if (err) console.log(error);
  console.log(response);
});
//console.log( WiFiControl.resetWiFi() );

/*console.log( WiFiControl.connectToAP({
  ssid: "xfinitywifi"
}) );*/
