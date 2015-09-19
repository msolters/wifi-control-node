WiFiControl = require("../lib/wifi-control.js");
WiFiControl.init({
  debug: true
});
//console.log( WiFiControl.scanForWiFi() );
console.log( WiFiControl.connectToAP({
  ssid: "xfinitywif"
}) );
console.log( WiFiControl.getIfaceState() );
