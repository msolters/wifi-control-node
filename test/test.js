WiFiControl = require("../lib/wifi-control.js");
WiFiControl.init({
  debug: true
});
//console.log( WiFiControl.scanForWiFi() );
console.log( WiFiControl.connectToAP({
  ssid: "xfinitywifi"
}) );
console.log( WiFiControl.getIfaceState() );
