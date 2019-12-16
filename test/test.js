'use-strict'
WiFiControl = require("../lib/wifi-control.js");
const sleep = (millis) => new Promise(resolve => setTimeout(resolve, millis));


WiFiControl.init({
  debug: true,
  connectionTimeout: 2000
});

var a = WiFiControl.getIfaceState()
console.log(a.find(interface => interface.adapterName === 'Wi-Fi'))

a.forEach(state => {
  if (state && state.ssid.startsWith('MediCam') && state.connection === 'connected') {
    console.log(state)
  }
});

// ap = {
//   ssid: 'UNICORNWORKING-5G',
//   password: '25175089'
// }

// WiFiControl.connectToAP(ap, a[0].adapterName, () => {
//   console.log("RRRRRRRRRRRRRRRRRRRR")
// })