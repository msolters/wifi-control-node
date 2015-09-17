# wifi-control

A NodeJS module providing methods for scanning local WiFi access points, as well as connecting/disconnecting to networks.  Works for Windows, Linux and MacOS.

Maybe you have a SoftAP-based IoT toy, and you just need to make a thin downloadeable "setup" client?  Maybe you want to make a headless Rpi-based device that needs to frequently change APs?

Install:
```sh
  npm install wifi-control
```

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
This package uses the [node-wifiscanner2 NPM package](https://www.npmjs.com/package/node-wifiscanner2) by Spark for the heavy lifting where AP scanning is concerned.  However, on Linux, we use a custom approach that leverages `nmcli` which bypasses the `sudo` requirement of `iwlist` and permits us to more readily scan local WiFi networks.  For example, without `sudo` on Linux, node-wifiscanner2 will often return *only* the AP currently connected to, even though many others are available.  The trade-off here is that on Linux, the result list does not include the MAC address of the AP.

Direct call:
```js
  var scanResults = WiFiControl.scan();
```

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

Direct call:
```js
  var _ap = {
    ssid: "Home 2.4Ghz",
    password: "mypassword"
  };
  var results = WiFiControl.connectToAP( _ap );
```

The `.password` property is optional and may be omitted for open networks.

## Reset Wireless Interface
```js
  WiFiControl.resetWiFi();
```
After connecting or disconnecting to various APs programmatically (which may or may not succeed) it is useful to have a method by which to reset the network interface to system defaults.

This method attempts to do that, either by disconnecting the interface or restarting the system's network manager, if one exists.  It will report either success or failure in the return message.


## Find Wireless Interface
Unless your wireless cards are frequently changing or being turned on or off, it should not be necessary to use this method often.

When called with no argument, `WiFiControl.findInterface()` will attempt to automatically locate a valid wireless interface on the host machine.

When supplied a string argument `interface`, that value will be used as the host machine's intended wireless interface.  Typical values for various operating systems are:

OS | Typical Values
---|---
Linux | wlan0, wlan1, ...
Windows | wlan
MacOS | en0, en1, ...

Direct call:
(Server only)
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
