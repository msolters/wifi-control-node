'use-strict'
WiFiControl = require("../lib/wifi-control.js");
const sleep = (millis) => new Promise(resolve => setTimeout(resolve, millis));


WiFiControl.init({
  debug: true,
  connectionTimeout: 2000
});

setInterval(() => {
	WiFiControl.getIfaceState()
}, 1000)