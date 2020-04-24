'use-strict'
WiFiControl = require("../lib/wifi-control.js");
const sleep = (millis) => new Promise(resolve => setTimeout(resolve, millis));


WiFiControl.init({
    debug: true,
    connectionTimeout: 7000
});
let iface = WiFiControl.getIfaceState()

console.log("getInterfaceState", iface);

WiFiControl.resetWiFi(iface[0].adapterName, (err) => {
    if (err) {
        console.log(err)
    }
})

let ap = { ssid: 'MediCam_DFBAD1', password: '1234567890' }

WiFiControl.connectToAP(ap, iface[0].adapterName, (err, resp) => {
    if (resp) {
        console.log("connected: ", resp)
        // WiFiControl.resetWiFi(iface[0].adapterName, (err) => {
        //     if (err) {
        //         console.log(err)
        //     }
        // })
    }
    if (err)
        console.log("error", err)
})