WiFiControl = require("../lib/wifi-control.js");
WiFiControl.init({
  debug: true
});
console.log( WiFiControl.scanForWiFi() );
