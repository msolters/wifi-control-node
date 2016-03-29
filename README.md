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
  WiFiControl.scanForWiFi( function(err, response) {
    if (err) console.log(err);
    console.log(response);
  });
```

Example Output:
```js
  {
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

Some `WiFiControl` methods are synchronous, some are not.

Synchronous
---
* `WiFiControl.init( settings )`
* `WiFiControl.configure( settings )`
* `WiFiControl.findInterface( iface )`
* `WiFiControl.getIfaceState()`

Asynchronous
---
*  `WiFiControl.scanForWiFi( callback )` - this can take a while (1-10 seconds) so we use a callback to return the scan results.
*  `WiFiControl.connectToAP( ap, callback )` - this can sometimes take several minutes so we use a callback to report on how it went.
*  `WiFiControl.resetWiFi( callback )` - powering down and back up can sometimes take a while, depending on your wireless card, so this method will return your callback when it is complete.

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
    iface: 'wlan0',
    connectionTimeout: 10000 // in ms
  };

  WiFiControl.configure( settings );
  // and/or WiFiControl.init( settings );
```

**Settings Object**

key | Explanation
---|---
`debug` | (optional, Bool) When `debug: true`,  will turn on verbose output to the server console.  When `debug: false` (default), only errors will be printed to the server console.
`iface` | (optional, String) Can be used to manually specify a network interface to use, instead of relying on `WiFiControl.findInterface()` to automatically find it.  This could be useful if for any reason `WiFiControl.findInterface()` is not working, or you have multiple network cards.
`connectionTimeout` | (optional, Int) WiFi connection using `WiFiControl.connectToAP` method takes place in 2 steps. The first is the OS-specific commands required to associate the wireless device with the WiFi network specified by `ap`.  The second is a confirmation phase, where we must wait for the connection to be confirmed (in case of i.e. bad password, unstable AP, banned MAC address, ...).  By default, we allow 5 seconds for this step (`connectionTimeout: 5000`). You can override this value here.

## Scan for Networks
```js
  WiFiControl.scanForWiFi( function(err, response) {
    if (err) console.log(err);
    console.log(response);
  });
```

On Windows and MacOS, this package uses the [node-wifiscanner2 NPM package](https://www.npmjs.com/package/node-wifiscanner2) by Spark for the heavy lifting where AP scanning is concerned.  However, since `node-wifiscanner2` requires `sudo` to scan for more than the network the host machine is *currently connected to* on Linux, a custom scanning algorithm is implemented inside `WiFiControl` that leverages `nmcli` instead.

Note that this method is an async `WiFiControl` method, and requires a callback to be passed in order to use its results.

Example output:
```js
  {
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
  var results = WiFiControl.connectToAP( _ap, callback );
```
The `WiFiControl.connectToAP( _ap, cb )` command takes a wireless access point as an object and attempts to direct the host machine's wireless interface to connect to it.  Note this is an asynchronous function because it can sometimes take on the order of minutes to complete, depending on factors such as your wireless interface and AP strength & distance!

```js
  var _ap = {
    ssid: "Home 2.4Ghz",
    password: "mypassword"
  };
  var results = WiFiControl.connectToAP( _ap, function(err, response) {
    if (err) console.log(err);
    console.log(response);
  });
```

The `.password` property is optional and may be omitted for open networks.

Example output:

```js
  {
    success: true,
    msg: 'Successfully connected to "Home 2.4Ghz"!'
  }
```

> Note: The only types of networks tested to work on Windows so far are WPA2-Personal and Open.  Any type of security is expected to work on Linux and MacOS.

## Reset Wireless Interface
```js
  WiFiControl.resetWiFi( function(err, response) {
    if (err) console.log(err);
    console.log(response);
  } );
```
After connecting or disconnecting to various APs programmatically (which may or may not succeed) it is useful to have a method by which to reset the network interface to system defaults.

This method attempts to do that, either by disconnecting the interface or restarting the system's network manager, if one exists.  

> Note this is not always bound to have consistent results across all operating systems and the user is encouraged to verify the results in their application code if using this command to automate a procedure.  For example, some flavors of Windows may reset by reconnecting to the default WiFi network, while some flavors may simply disconnect completely.

Example output:

```js
  {
    success: true,
    msg: 'Success!  Wireless interface is now reset.'
  }
```

## Get Connection State
```js
  var ifaceState = WiFiControl.getIfaceState();
```

This method will tell you whether or not the wireless interface is connected to an access point, and if so, what SSID.  This method is used internally, for example, when `WiFiControl.connectToAP( _ap )` is called, to make sure that the interface either successfully connects or unsuccessfully does something else before returning.

Example output:
```js
ifaceState = {
  "success": true,
  "msg": "Successfully acquired state of network interface wlan0.",
  "ssid": "Home 2.4Ghz",
  "connection": "connected",
  "power": true
}
```

Output parameters are as follows:
Parameter | Value and Meaning
---|---
`success` | (bool), will only be `false` if there is an error.
`msg` | A brief description of the request results.  Will contain a description of the error if `success: false`.
`ssid` | (string or null) The SSID of the network the wireless interface is currently connected to.  If not presently connected, will be `undefined`.
`connection` | (string) Can take three values: "disconnected", "connecting", or "connected".  Describes the current state of the wireless interface association with the current AP.
`power` | (bool) Will only be `false` if the specified wireless interface's driver or connection manager is disabled.

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
This library has been tested on Ubuntu 15.04, MacOS Yosemite, and Windows 10.

This package has been developed to be compatible with Node v0.10.36 because it is intended for [use in Meteor](https://atmospherejs.com/msolters/wifi-control-meteor), which currently runs on the v0.10.36 binary.


## Change Log
### v2.0.0
3/28/2016
*  Replace infinite loops with (customizable) timeouts
*  `WiFiControl.connectToAP(ap, cb)` is now asynchronous.  **This is a breaking change if it is currently implemented in user application code as a sync method.**
*  `WiFiControl.resetWiFi(cb)` is now asynchronous.  **This is a breaking change if it is currently implemented in user application code as a sync method.**
*  OS-specific source code has been refactored into separate files (`darwin.coffee`, `win32.coffee`, `linux.coffee`)

### v1.0.2
3/22/2016
*  Fix multiple instances of catastrophic backtracking in RegExp objects.

### v1.0.1
9/27/2015
*  Documentation fixes.

### v1.0.0
9/26/2015
*  `WiFiControl.getIfaceState(cb)` is extended to include more robust `connection` state of the interface, and also tested to work with Windows.  This method has also become an async method now!  **This is a breaking change if it is currently implemented in user application code as a sync method.**
*  `WiFiControl.resetWiFi()` tested to work with Windows.
*  `WiFiControl.connecToAP(ap)` tested to work with Windows both with open and secure networks.

### v0.1.6
9/23/2015
*  Better output logs for `WiFiControl.resetWiFi()`.

### v0.1.5
9/23/2015
*  `WiFiControl.resetWiFi()` blocks until wireless interface reports it has reset or returns an error.
*  `WiFiControl.getIfaceState()` now returns information about if the wireless interface is powered or not.

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
