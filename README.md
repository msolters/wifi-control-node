# wifi-control

A NodeJS module providing methods for scanning local WiFi access points, as well as connecting/disconnecting to networks.  Works for Windows, Linux and MacOS.

Maybe you have a SoftAP-based IoT toy, and you just need to make a thin downloadeable "setup" client?  Maybe you want to make a headless Rpi-based device that needs to frequently change APs?

## Example:

```js
  var WiFiControl = require('wifi-control');

  //  Initialize wifi-control package with verbose output
  WiFiControl.init({
    debug: true
  });

  //  Try scanning for access points:
  var scanResults = WiFiControl.scan();
  console.log( scanResults );
```

Example Output:
```js
  scanResults = {
    "success":  true,
    "networks":
      [ { "mac": "AA:BB:CC:DD:EE:FF",
          "channel": "1",
          "signal_level": "-43",
          "ssid": "Home 2.4Ghz" } ],
    "msg":"Nearby WiFi APs successfully scanned (1 found)."
  }
```

# Methods
The following methods use different commands across Windows, MacOS and Linux to provide the same functionality.  In broad strokes, the underlying system commands we are leveraging are:

OS | Command
---|---
Windows | `netsh`
MacOS | `networksetup`
Linux | `nmcli`

You may encounter errors if you use this module on a system lacking these commands!

**A Note About Synchronicity** (*Synchronicity!*)

All `WiFiControl` methods are synchronous.  Calls to them will block.  This is a decision made that reflects the fact that low-level system operations such as starting and stopping network interfaces are intrinsically sequential.

---

##  Initialize
```
  WiFiControl.init( settings );
```

Before `WiFiControl` can scan or connect/disconnect using the host machine's wireless interface, it must know what that wireless interface is!

To initialize the network interface and simultaneously pass in any custom settings, simply call `WiFiControl.init( settings )` on the server at startup.  `settings` is an optional parameter -- see [`WiFiControl.configure( settings )`](https://github.com/msolters/wifi-control-node#configure) below.

Equivalently, to manually instruct the `WiFiControl` module to locate a wireless interface, or to manually force a network interface, see the `WiFiControl.findInterface( iface )` command.

##  Configure
```js
  WiFiControl.configure( settings );
```
You can reconfigure the `WiFiControl` settings at any time using this method.  Possible `WiFiControl` settings are illustrated in the following example:

```js
  var settings = {
    debug: true || false,
    iface: 'wlan0'
  };

  WiFiControl.configure( settings );
  // and/or WiFiControl.init( settings );
```

**Settings Object**

key | Explanation
---|---
`debug` | (optional, Bool) When `debug: true`,  will turn on verbose output to the server console.  When `debug: false` (default), only errors will be printed to the server console.
`iface` | (optional, String) Can be used to manually specify a network interface to use, instead of relying on `WiFiControl.findInterface()` to automatically find it.  This could be useful if for any reason `WiFiControl.findInterface()` is not working, or you have multiple network cards.

## Scan for Networks
```js
  var scanResults = WiFiControl.scan();
```

This package uses the [node-wifiscanner2 NPM package](https://www.npmjs.com/package/node-wifiscanner2) by Spark for the heavy lifting where AP scanning is concerned.  However, on Linux, we use a custom approach that leverages `nmcli` which bypasses the `sudo` requirement of `iwlist` and permits us to more readily scan local WiFi networks.


Example output:
```js
  scanResults = {
    "success":  true,
    "networks":
      [ { "mac": "AA:BB:CC:DD:EE:FF",
          "channel": "1",
          "signal_level": "-43",
          "ssid": "Home 2.4Ghz" } ],
    "msg":"Nearby WiFi APs successfully scanned (1 found)."
  }
```

## Connect To WiFi Network
```js
  var results = WiFiControl.connectToAP( _ap );
```
The `WiFiControl.connectToAP( _ap )` command takes a wireless access point as an object and attempts to direct the host machine's wireless interface to connect to it.

```js
  var _ap = {
    ssid: "Home 2.4Ghz",
    password: "mypassword"
  };
  var results = WiFiControl.connectToAP( _ap );
```

The `.password` property is optional and may be omitted for open networks.

> Note: Windows can only connect to open networks currently.

## Reset Wireless Interface
```js
  WiFiControl.resetWiFi();
```
After connecting or disconnecting to various APs programmatically (which may or may not succeed) it is useful to have a method by which to reset the network interface to system defaults.

This method attempts to do that, either by disconnecting the interface or restarting the system's network manager, if one exists.  It will report either success or failure in the return message.

## Get Connection State
```js
  var ifaceState = WiFiControl.getIfaceState();
```

This method will tell you whether or not the wireless interface is connected to an access point, and if so, what SSID.  This method is used internally, for example, when `WiFiControl.connectToAP( _ap )` is called, to make sure that the interface either successfully connects or unsuccessfully does something else before returning.

Example output:
```js
ifaceState = {
  "success": true
  "msg": "Successfully acquired state of network interface wlan0."
  "ssid": "Home 2.4Ghz"
  "state": "connected"
}
```

## Find Wireless Interface
Unless your wireless cards are frequently changing or being turned on or off, it should not be necessary to use this method often.

When called with no argument, `WiFiControl.findInterface()` will attempt to automatically locate a valid wireless interface on the host machine.

When supplied a string argument `interface`, that value will be used as the host machine's intended wireless interface.  Typical values for various operating systems are:

OS | Typical Values
---|---
Linux | wlan0, wlan1, ...
Windows | wlan
MacOS | en0, en1, ...

Example:
```js
  var resultsAutomatic = WiFiControl.findInterface();
  var resultsManual = WiFiControl.findInterface( 'wlan2' );
```

Output:
```js
  resultsAutomatic = {
    "success":  true,
    "msg":  "Automatically located wireless interface wlan2.",
    "interface":  "wlan2"
  }
  resultsManual = {
    "success":  true,
    "msg":  "Wireless interface manually set to wlan2.",
    "interface":  "wlan2"
  }
```

# Notes
This library has been tested on Ubuntu & MacOS with no problems.

Of the 3 OSs provided here, Windows is currently the least tested.  Expect bugs with:

*  Connecting to secure APs in win32
*  Resetting network interfaces in win32

This package has been developed to be compatible with Node v0.10.36 because it is intended for [use in Meteor](https://atmospherejs.com/msolters/wifi-control), which currently runs on the v0.10.36 binary.  If you are using a version like 4.0.0+ and encounter bugs with `execSync` dependencies, you can update the source of this package by going into `src/wifi-control.coffee` and redefine `execSyncToBuffer = require('child_process').execSync`, remove the `execSync` dependency, and `npm install`.  This will build the package by using the built-in `execSync` method that was later added to `child_process`.


## Change Log

### v0.1.3
9/19/2015
*  `WiFiControl.getIfaceState()`
*  `WiFiControl.connectToAP( ap )` now waits on `WiFiControl.getIfaceState()` to ensure network interface either succeeds or fails in connection attempt before returning a result.  This definitely works on MacOS and Linux.

### v0.1.2
9/18/2015

*  `WiFiControl.init( settings )` and `WiFiControl.configure( settings )`
*  `WiFiControl.connectToAP( ap )`, does not wait for connection to settle, no secure AP for win32 yet.
*  `WiFiControl.findInterface( iface )`
*  `WiFiControl.scan()`
