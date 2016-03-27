#
# NPM Dependencies.
#
# node-wifiscanner2 is a great NPM package for scanning WiFi APs (for Windows & Mac -- it REQUIRES sudo on Linux).
WiFiScanner = require 'node-wifiscanner2'
# On Windows, we need write .xml files to create network profiles :(
fs = require 'fs'
# To execute commands in the host machine, we'll use sync-exec.
# Note: In nodejs >= v0.12 this will default to child_process.execSync.
execSyncToBuffer = require 'sync-exec'


#
# Local helper functions.
#


#
# win32WirelessProfileBuilder:    This method generates the Windows wireless profile
#                       XML file corresponding to the ssid, security, and
#                       passphrase (key).
#
win32WirelessProfileBuilder = (ssid, security=false, key=null) ->
  #
  # (1) First, construct the header which specifies the SSID.
  #
  profile_content =   "<?xml version=\"1.0\"?>
                      <WLANProfile xmlns=\"http://www.microsoft.com/networking/WLAN/profile/v1\">
                        <name>#{ssid.plaintext}</name>
                        <SSIDConfig>
                          <SSID>
                            <hex>#{ssid.hex}</hex>
                            <name>#{ssid.plaintext}</name>
                          </SSID>
                        </SSIDConfig>"
  #
  # (2) Next, depending on security, fill out the encryption-specific data.
  #
  switch security
    when "wpa"
      profile_content +=   "<connectionType>ESS</connectionType>
                            <connectionMode>auto</connectionMode>
                            <autoSwitch>true</autoSwitch>
                            <MSM>
                                <security>
                                    <authEncryption>
                                        <authentication>WPAPSK</authentication>
                                        <encryption>TKIP</encryption>
                                        <useOneX>false</useOneX>
                                    </authEncryption>
                                    <sharedKey>
                                      <keyType>passPhrase</keyType>
                                      <protected>false</protected>
                                      <keyMaterial>#{key}</keyMaterial>
                                    </sharedKey>
                                </security>
                            </MSM>"
    when "wpa2"
      profile_content +=   "<connectionType>ESS</connectionType>
                            <connectionMode>auto</connectionMode>
                            <autoSwitch>true</autoSwitch>
                            <MSM>
                              <security>
                                <authEncryption>
                                  <authentication>WPA2PSK</authentication>
                                  <encryption>AES</encryption>
                                  <useOneX>false</useOneX>
                                </authEncryption>
                                <sharedKey>
                                  <keyType>passPhrase</keyType>
                                  <protected>false</protected>
                                  <keyMaterial>#{key}</keyMaterial>
                                </sharedKey>
                              </security>
                            </MSM>"
    else
      # Open networks!
      profile_content +=   "<connectionType>ESS</connectionType>
                            <connectionMode>manual</connectionMode>
                            <MSM>
                              <security>
                                <authEncryption>
                                  <authentication>open</authentication>
                                  <encryption>none</encryption>
                                  <useOneX>false</useOneX>
                                </authEncryption>
                              </security>
                            </MSM>"
  #
  # (3) Close the profile.
  #
  profile_content += "</WLANProfile>"
  return profile_content


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
    unless WiFiControlSettings.iface?
      _msg = "You cannot scan for nearby WiFi networks without a valid wireless interface."
      WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }
    try
      WiFiLog "Scanning for nearby WiFi Access Points..."
      if process.platform is "linux"
        #
        # Use nmcli to list visible wifi networks.
        #
        scanResults = execSync "nmcli -m multiline device wifi list"
        #
        # Parse the results into an array of AP objects to match
        # the structure found in node-wifiscanner2 for win32 and MacOS.
        #
        networks = []
        for nwk, c in scanResults.split '*:'
          continue if c is 0
          _network = {}
          for ln, k in nwk.split '\n'
            try
              parsedLine = parsePatterns.nmcli_line.exec( ln.trim() )
              KEY = parsedLine[1]
              VALUE = parsedLine[2]
            catch error
              continue  # this line was not a key: value pair!
            switch KEY
              when "SSID"
                _network.ssid = String VALUE
              when "CHAN"
                _network.channel = String VALUE
              when "SIGNAL"
                _network.signal_level = String VALUE
              when "SECURITY"
                _network.security = String VALUE
          networks.push _network unless _network.ssid is "--"
        _msg = "Nearby WiFi APs successfully scanned (#{networks.length} found)."
        WiFiLog _msg
        cb null,
          success: true
          msg: _msg
          networks: networks
      else
        WiFiScanner.scan (err, networks) ->
          if err
            _msg = "We encountered an error while scanning for WiFi APs: #{error}"
            WiFiLog _msg, true
            cb err,
              success: false
              msg: _msg
          else
            _msg = "Nearby WiFi APs successfully scanned (#{networks.length} found)."
            WiFiLog _msg
            cb null,
              success: true
              networks: networks
              msg: _msg
    catch error
      _msg = "We encountered an error while scanning for WiFi APs: #{error}"
      WiFiLog _msg, true
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
    unless WiFiControlSettings.iface?
      _msg = "You cannot connect to a WiFi network without a valid wireless interface."
      WiFiLog _msg, true
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
      # (3) Construct an OS-specific command chain for connecting to
      #     a wireless AP.
      #
      switch process.platform
        #
        # With Linux, we can use nmcli to do the heavy lifting.
        #
        #
        # (1) Does a connection that matches the name of the ssid
        #     already exist?
        #
        when "linux"
          COMMANDS =
            delete: "nmcli connection delete \"#{_ap.ssid}\""
            connect: "nmcli device wifi connect \"#{_ap.ssid}\""
          if _ap.password.length
            COMMANDS.connect += " password \"#{_ap.password}\""
          try
            stdout = execSync "nmcli connection show \"#{_ap.ssid}\""
            ssidExist = true if stdout.length
          catch error
            ssidExist = false
          #
          # (2) Delete the old connection, if there is one.
          #     Then, create a new connection.
          #
          connectToAPChain = []
          if ssidExist
            WiFiLog "It appears there is already a connection for this SSID."
            connectToAPChain.push "delete"
          connectToAPChain.push "connect"
        #
        # Windows is a special child.  While the netsh command provides us
        # quite a bit of functionality, the real kicker is that to connect
        # to a given network using it, we must first have a so-called wireless
        # profile for that network in the machine.
        # This can be done ONLY through the GUI, or by loading an XML file which
        # must already contain the SSID information in plaintext and as HEX.
        # Once we create this XML file, we will add the profile inside, and then
        # connect to it all using the netsh command.
        #
        when "win32"
          WiFiLog "Generating win32 wireless profile..."
          #
          # (1) Convert SSID to Hex
          #
          ssid =
            plaintext: _ap.ssid
            hex: ""
          for i in [0..ssid.plaintext.length-1]
            ssid.hex += ssid.plaintext.charCodeAt(i).toString(16)
          #
          # (2) Generate XML content for the provided parameters.
          #
          xmlContent = null
          if _ap.password.length
            xmlContent = win32WirelessProfileBuilder ssid, "wpa2", _ap.password
          else
            xmlContent = win32WirelessProfileBuilder ssid
          #
          # (3) Write xmlContent to XML wireless profile file.
          #
          try
            fs.writeFileSync "#{_ap.ssid}.xml", xmlContent
          catch error
            _msg = "Encountered an error connecting to AP: #{error}"
            WiFiLog _msg, true
            return {
              success: false
              msg: _msg
            }
          #
          # (4) Load new XML profile, and connect to SSID.
          #
          COMMANDS =
            loadProfile: "netsh #{WiFiControlSettings.iface} add profile filename=\"#{_ap.ssid}.xml\""
            connect: "netsh #{WiFiControlSettings.iface} connect ssid=\"#{_ap.ssid}\" name=\"#{_ap.ssid}\""
          connectToAPChain = [ "loadProfile", "connect" ]
        when "darwin" # i.e., MacOS
          COMMANDS =
            connect: "networksetup -setairportnetwork #{WiFiControlSettings.iface} \"#{_ap.ssid}\""
          if _ap.password.length
            COMMANDS.connect += " \"#{_ap.password}\""
          connectToAPChain = [ "connect" ]

      #
      # (4) Connect to AP using using the above constructed
      #     command chain.
      #
      for com in connectToAPChain
        WiFiLog "Executing:\t#{COMMANDS[com]}"
        #
        # Run the command, handle any errors that get thrown.
        #
        try
          stdout = execSync COMMANDS[com]
        catch error
          # Handle Linux errors:
          if process.platform is "linux"
            if error.stderr.toString().trim() is "Error: No network with SSID '#{_ap.ssid}' found."
              _msg = "Error: No network called #{_ap.ssid} could be found."
              WiFiLog _msg, true
              return {
                success: false
                msg: _msg
              }
            else if error.stderr.toString().search /Error:/ != -1
              _msg = error.stderr.toString().trim()
              WiFiLog _msg, true
              return {
                success: false
                msg: _msg
              }
            # Ignore nmcli's add/modify errors, this is a system bug
            unless /nmcli device wifi connect/.test(COMMANDS[com])
              WiFiLog error, true
              return {
                success: false
                msg: error
              }
        #
        # If we've made it this far, check the output.
        #
        switch process.platform
          when "darwin"
            if stdout is "Could not find network #{_ap.ssid}."
              _msg = "Error: No network called #{_ap.ssid} could be found."
              WiFiLog _msg, true
              return {
                success: false
                msg: _msg
              }
        #
        # Otherwise, so far so good!
        #
        WiFiLog "Success!"
      #
      # If this is Windows, delete the wireless profile XML file we made.
      #
      if process.platform is "win32"
        WiFiLog "Removing temporary WiFi config file..."
        execSync "del \".\\#{_ap.ssid}.xml\""
      #
      # (5) Now we keep checking the state of the network interface
      #     to make sure it ends up actually being connected to the
      #     desired SSID.
      #
      WiFiLog "Waiting for connection attempt to settle..."
      while true
        ifaceState = @getIfaceState()
        if ifaceState.success
          if ifaceState.connection is "connected"
            break
          else if ifaceState.connection is "disconnected"
            _msg = "Error: Interface is not currently connected to any wireless AP."
            WiFiLog _msg, true
            return {
              success: false
              msg: _msg
            }
      if ifaceState.ssid is _ap.ssid
        #
        # We're connected, and on the right SSID!  Success.
        #
        _msg = "Successfully connected to #{_ap.ssid}!"
        WiFiLog _msg
        return {
          success: true
          msg: _msg
        }
      else
        #
        # We're connected, but to the wrong SSID!
        #
        _msg = "Error: Interface is currently connected to #{ifaceState.ssid}"
        WiFiLog _msg, true
        return {
          success: false
          msg: _msg
        }
    catch error
      _msg = "Encountered an error while connecting to #{_ap.ssid}: #{error}"
      WiFiLog _msg, true
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
