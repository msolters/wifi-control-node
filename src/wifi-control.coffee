#
# NPM Dependencies.
#
# node-wifiscanner2 is a great NPM package for scanning WiFi APs (for Windows & Mac -- it REQUIRES sudo on Linux).
WiFiScanner = require 'node-wifiscanner2'
# To execute commands in the host machine, we'll use sync-exec.
# Note: In nodejs >= v0.12 this will default to child_process.execSync.
execSyncToBuffer = require 'sync-exec'


#
# ( ) Load OS-specific instructions from file.
#
switch process.platform
  when "linux"
    os_instructions = require './linux.js'
  when "win32"
    os_instructions = require './win32.js'
  when "darwin"
    os_instructions = require './darwin.js'
  else
    WiFiLog "Unrecognized operating system.", true
    process.exit()

#
# ( ) Helper methods common to all OS
#
private_context =
  #
  # Define WiFiControl settings.
  #
  WiFiControlSettings:
    iface: null
    debug: false

  #
  # execSync: Executes command with options via child_process.execSync,
  #           but guarantees output as a String instead of a buffer.
  #
  execSync: (command, options={}) ->
    results = execSyncToBuffer command, options
    unless results.status
      return results.stdout
    throw
      stderr: results.stderr

  #
  # WiFiLog:        Helper method for debugging and throwing
  #                 errors.
  #
  WiFiLog: (msg, error=false) ->
    if error
      console.error "WiFiControl: #{msg}"
    else
      console.log "WiFiControl: #{msg}" if @WiFiControlSettings.debug

#
# WiFiControl Methods.
#
module.exports =
  #
  # init:   Initial setup.  This is almost the same as config, except it
  #         adds the additional step of attempting to automatically locate
  #         a network interface if one was not specified in settings.
  #
  #         This is optional, provided you manually set an interface by calling
  #         WiFiControl.configure({iface: "myifc"}), or by triggering the automatic
  #         interface lookup by calling WiFiControl.findInterface() elsewhere in
  #         the code before attempting to scan/(dis)connect.
  #
  init: ( settings={} ) ->
    # Apply any manual settings passed in.
    @configure settings
    # Make sure we try to find an interface if none specified:
    #   (WiFiControl.configure will not do so!)
    @findInterface settings.iface unless settings.iface?

  #
  # configure:    Update or change settings such as debug state or manual
  #               network interface selection.
  #
  configure: ( settings={} ) ->
    # Configure debug settings.
    if settings.debug?
      private_context.WiFiControlSettings.debug = settings.debug
      private_context.WiFiLog "Debug mode set to: #{settings.debug}"
    # Set network interface to settings.iface.
    @findInterface settings.iface if settings.iface?

  #
  # findInterface:  Search host machine to find an active
  #                 WiFi card interface.
  #
  findInterface: ( iface=null ) ->
    try
      # If user is forcing an interface manually, do that.
      if iface?
        _msg = "Wireless interface manually set to #{iface}."
        private_context.WiFiLog _msg
        private_context.WiFiControlSettings.iface = iface
        return {
          success: true
          msg: _msg
          interface: iface
        }
      #
      # (1) First, we find the wireless card interface on the host.
      #
      private_context.WiFiLog "Determining system wireless interface..."
      interfaceResults = os_instructions.autoFindInterface.call private_context
      private_context.WiFiControlSettings.iface = interfaceResults.interface
      return interfaceResults
    catch error
      _msg = "Encountered an error while searching for wireless interface: #{error}"
      private_context.WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }

  #
  # scanForWiFi:   Return a list of nearby WiFi access points by using the
  #                host machine's wireless interface.  For this, we are using
  #                the NPM package node-wifiscanner2 by Particle (aka Spark).
  #
  #                This is an async method and it will return its results through
  #                a user provided callback, cb(err, resp).
  #
  scanForWiFi: (cb) ->
    unless private_context.WiFiControlSettings.iface?
      _msg = "You cannot scan for nearby WiFi networks without a valid wireless interface."
      private_context.WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }
    try
      private_context.WiFiLog "Scanning for nearby WiFi Access Points..."
      if process.platform is "linux"
        networks = os_instructions.scanForWiFi.apply private_context
        _msg = "Nearby WiFi APs successfully scanned (#{networks.length} found)."
        private_context.WiFiLog _msg
        cb null,
          success: true
          msg: _msg
          networks: networks
      else
        WiFiScanner.scan (err, networks) ->
          if err
            _msg = "We encountered an error while scanning for WiFi APs: #{error}"
            private_context.WiFiLog _msg, true
            cb err,
              success: false
              msg: _msg
          else
            _msg = "Nearby WiFi APs successfully scanned (#{networks.length} found)."
            private_context.WiFiLog _msg
            cb null,
              success: true
              networks: networks
              msg: _msg
    catch error
      _msg = "We encountered an error while scanning for WiFi APs: #{error}"
      private_context.WiFiLog _msg, true
      cb error,
        success: false
        msg: _msg

  #
  # connectToAP:    Direct the host machine to connect to a specific WiFi AP
  #                 using the specified parameters.
  #                 pw is an optional parameter; calling with only an ssid
  #                 connects to an open network.
  #
  connectToAP: ( _ap ) ->
    unless private_context.WiFiControlSettings.iface?
      _msg = "You cannot connect to a WiFi network without a valid wireless interface."
      private_context.WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }
    try
      #
      # (1) Verify there is a valid SSID
      #
      unless _ap.ssid.length
        return {
          success: false
          msg: "Please provide a non-empty SSID."
        }
      #
      # (2) Verify there is a valid password (if no password, just add an empty one == open network)
      #
      unless _ap.password?
        _ap.password = ""

      #
      # (3) Do the OS-specific dirty work
      #
      os_instructions.connectToAP.call private_context, _ap

      #
      # (4) Now we keep checking the state of the network interface
      #     to make sure it ends up actually being connected to the
      #     desired SSID.
      #
      private_context.WiFiLog "Waiting for connection attempt to settle..."
      while true
        ifaceState = @getIfaceState()
        if ifaceState.success
          if ifaceState.connection is "connected"
            break
          else if ifaceState.connection is "disconnected"
            _msg = "Error: Interface is not currently connected to any wireless AP."
            private_context.WiFiLog _msg, true
            return {
              success: false
              msg: _msg
            }
      if ifaceState.ssid is _ap.ssid
        #
        # We're connected, and on the right SSID!  Success.
        #
        _msg = "Successfully connected to #{_ap.ssid}!"
        private_context.WiFiLog _msg
        return {
          success: true
          msg: _msg
        }
      else
        #
        # We're connected, but to the wrong SSID!
        #
        _msg = "Error: Interface is currently connected to #{ifaceState.ssid}"
        private_context.WiFiLog _msg, true
        return {
          success: false
          msg: _msg
        }
    catch error
      _msg = "Encountered an error while connecting to #{_ap.ssid}: #{error}"
      private_context.WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }

  #
  # resetWiFi:    Attempt to return the host machine's wireless to whatever
  #               network it connects to by default.
  #
  resetWiFi: ->
    try
      #
      # (1) Choose commands based on OS.
      #
      switch process.platform
        when "linux"
          # With Linux, we just restart the network-manager, which will
          # immediately force its own preferences and defaults.
          COMMANDS =
            disableNetworking: "nmcli networking off"
            enableNetworking: "nmcli networking on"
          resetWiFiChain = [ "disableNetworking", "enableNetworking" ]
        when "win32"
          # In Windows, we are just disconnecting from the current network.
          # This typically causes the wireless to then re-connect to its first
          # preference.
          COMMANDS =
            disconnect: "netsh #{WiFiControlSettings.iface} disconnect"#"netsh #{iface} connect ssid=YOURSSID name=PROFILENAME"
          resetWiFiChain = [ "disconnect" ]
        when "darwin" # i.e., MacOS
          # In MacOS, we are going to turn the wireless off and then on again.
          # (lol)
          COMMANDS =
            enableAirport: "networksetup -setairportpower #{WiFiControlSettings.iface} on"
            disableAirport: "networksetup -setairportpower #{WiFiControlSettings.iface} off"
          resetWiFiChain = [ "disableAirport", "enableAirport" ]
      #
      # (2) Execute each command.
      #
      for com in resetWiFiChain
        WiFiLog "Executing:\t#{COMMANDS[com]}"
        stdout = execSync COMMANDS[com]
        _msg = "Success!"
        WiFiLog _msg
      #
      # (3) Ensure that the power has been restored to the interface!
      #
      WiFiLog "Waiting for interface to finish resetting..."
      while true
        ifaceState = @getIfaceState()
        if ifaceState.success
          if ifaceState.power
            WiFiLog "Success!  Wireless interface is now reset."
            break
        else
          _msg = "Error: Interface could not be reset."
          WiFiLog _msg, true
          return {
            success: false
            msg: _msg
          }
      return {
        success: true
        msg: "Successfully reset WiFi!"
      }
    catch error
      _msg = "Encountered an error while resetting wireless interface: #{error}"
      WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }

  #
  # getIfaceState:     Return current connection state of the network
  #                    interface and what SSID it is connected to.
  getIfaceState: ->
    try
      #
      # Return network interface state.
      #
      interfaceState = os_instructions.getIfaceState.call private_context
      unless interfaceState.success is false
        interfaceState.success =  true
        interfaceState.msg = "Successfully acquired state of network interface #{private_context.WiFiControlSettings.iface}."
      return interfaceState
    catch error
      _msg = "Encountered an error while acquiring network interface connection state: #{error}"
      private_context.WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }
