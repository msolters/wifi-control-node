WiFiControl = require("../lib/wifi-control.js");
WiFiControl.init({
  debug: true
});
//console.log( WiFiControl.scanForWiFi() );
console.log( WiFiControl.connectToAP({
  ssid: "xfinitywifi"
}) );
var state;
while (1) {
  state = WiFiControl.getIfaceState().ifaceState
  if (state.state === "connected") {
    break;
  }
}
console.log( state );
