'use-strict'
WiFiControl = require("../lib/wifi-control.js");
const sleep = (millis) => new Promise(resolve => setTimeout(resolve, millis));


WiFiControl.init({
    debug: true,
    connectionTimeout: 2000
});
let iface = WiFiControl.getIfaceState()

WiFiControl.resetWiFi(iface[0].adapterName)

let ap = { ssid: 'your ap name', password: 'your ap password' }

WiFiControl.connectToAP(ap, iface[0].adapterName, (err, resp) => {
    if (resp) {
        console.log("connected: " + resp)
        WiFiControl.resetWiFi(iface[0].adapterName)
    }
    if (err)
        console.log("error" + ReferenceError)
})