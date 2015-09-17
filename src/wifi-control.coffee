# For promised callbacks, we'll need Future.
Future = require 'fibers/future'
# node-wifiscanner2 is a great NPM package for scanning WiFi APs (for Windows & Mac -- it REQUIRES sudo on Linux).
WiFiScanner = require 'node-wifiscanner2'
# On Windows, we need write .xml files to create network profiles :(
fs = require 'fs'
# To execute commands in the host machine, we'll use child_process.exec!
execSync = require 'exec-sync'

#
# Define WiFiControl methods.
#
WiFiControlSettings =
  iface: null
  debug: false
#
#
# WiFiLog:        Helper method for debugging and throwing
#                 errors.
#
WiFiLog = (msg, error=false) ->
  if error
    console.error "WiFiControl: #{msg}"
  else
    console.log "WiFiControl: #{msg}" if WiFiControlSettings.debug

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
      WiFiControlSettings.debug = settings.debug
      WiFiLog "Debug mode set to: #{settings.debug}"
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
        WiFiLog _msg
        WiFiControlSettings.iface = iface
        return {
          success: true
          msg: _msg
          interface: iface
        }
      #
      # (1) First, we find the wireless card interface on the host.
      #
      WiFiLog "Determining system wireless interface..."
      switch process.platform
        when "linux"
          WiFiLog "Host machine is Linux."
          # On linux, we use the results of `ip link show` and parse for
          # active `wlan*` interfaces.
          findInterface = "ip link show | grep wlan | grep -i \"state UP\""
          WiFiLog "Executing: #{findInterface}"
          _interface = execSync findInterface
          if _interface
            _iface = _interface.trim().split(": ")[1]
            _msg = "Automatically located wireless interface #{_iface}."
            WiFiLog _msg
            interfaceResults =
              success: true
              msg: _msg
              interface: _iface
          else
            _msg = "Error: No network interface found."
            WiFiLog _msg, true
            interfaceResults =
              success: false
              msg: _msg
              interface: null
        when "win32"
          WiFiLog "Host machine is Windows."
          # On windows we are currently assuming wlan by default.
          findInterface = "echo wlan"
          WiFiLog "Executing: #{findInterface}"
          _interface = execSync findInterface
          if _interface
            _iface = _interface.trim()
            _msg = "Automatically located wireless interface #{_iface}."
            WiFiLog _msg
            interfaceResults =
              success: true
              msg: _msg
              interface: _iface
          else
            _msg = "Error: No network interface found."
            WiFiLog _msg, true
            interfaceResults =
              success: false
              msg: _msg
              interface: null
        when "darwin"
          WiFiLog "Host machine is MacOS."
          # On Mac, we get use the results of getting the route to
          # a public IP, and parse for interfaces.
          findInterface = "networksetup -listallhardwareports | awk '/^Hardware Port: (Wi-Fi|AirPort)$/{getline;print $2}'"
          WiFiLog "Executing: #{findInterface}"
          _interface = execSync findInterface
          if _interface
            _iface = _interface.trim()
            _msg = "Automatically located wireless interface #{_iface}."
            WiFiLog _msg
            interfaceResults =
              success: true
              msg: _msg
              interface: _iface
          else
            _msg = "Error: No network interface found."
            WiFiLog _msg, true
            interfaceResults =
              success: false
              msg: _msg
              interface: null
        else
          WiFiLog "Unrecognized operating system.  No known method for acquiring wireless interface."
          interfaceResults =
            success: false
            msg: "No valid wireless interface could be located."
            interface: null
      WiFiControlSettings.iface = interfaceResults.interface
      return interfaceResults
    catch error
      _msg = "Encountered an error while searching for wireless interface: #{error}"
      WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }

  #
  # scanForWiFi:   Return a list of nearby WiFi access points by using the
  #                host machine's wireless interface.  For this, we are using
  #                the NPM package node-wifiscanner2 by Particle (aka Spark).
  #
  scanForWiFi: ->
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
        parsePattern = new RegExp /\s+(.*)+/
        for nwk, c in scanResults.split '*:'
          continue if c is 0
          _network = {}
          for ln, k in nwk.split '\n'
            value = parsePattern.exec( ln.trim() )
            switch k
              when 1
                _network.ssid = String value[1]
              when 3
                _network.channel = String value[1]
              when 5
                _network.signal_level = String value[1]
          networks.push _network unless _network.ssid is "--"
        _msg = "Nearby WiFi APs successfully scanned (#{networks.length} found)."
        WiFiLog _msg
        return {
          success: true
          msg: _msg
          networks: networks
        }
      else
        scanRequest = new Future
        WiFiScanner.scan (error, data) =>
          if error
            WiFiLog "Error: #{error}", true
            scanRequest.return {
              success: false
              msg: "We encountered an error while scanning for WiFi APs: #{error}"
            }
          else
            _msg = "Nearby WiFi APs successfully scanned (#{data.length} found)."
            WiFiLog _msg
            scanRequest.return {
              success: true
              networks: data
              msg: _msg
            }
        return scanRequest.wait()
    catch error
      return {
        success: false
        msg: "We encountered an error while scanning for WiFi APs: #{error}"
      }

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
      # (3) Connect to AP using nmcli, netsh or networksetup, depending on OS.
      #
      switch process.platform
        when "linux"
          #
          # With Linux, we can use nmcli to do the heavy lifting.
          #
          #
          # (1) Does a connection that matches the name of the ssid
          #     already exist?
          #
          COMMANDS =
            delete: "nmcli connection delete \"#{_ap.ssid}\""
            connect: "nmcli device wifi connect \"#{_ap.ssid}\""
          if _ap.password.length
            COMMANDS.connect += " password \"#{_ap.password}\""
          stdout = execSync "nmcli connection show | grep \"#{_ap.ssid}\""
          if stdout.length
            ssidExist = true
          else
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
        when "win32"
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
          WiFiLog "Generating win32 wireless profile..."
          #
          # (1) Convert SSID to Hex
          #
          ssid_hex = ""
          for i in [0.._ap.ssid.length-1]
            ssid_hex += ssid.charCodeAt(i).toString(16)
          #
          # (2) Generate XML content for the provided parameters.
          #
          xmlContent = "<?xml version=\"1.0\"?>
                        <WLANProfile xmlns=\"http://www.microsoft.com/networking/WLAN/profile/v1\">
                          <name>#{_ap.ssid}</name>
                          <SSIDConfig>
                            <SSID>
                              <hex>#{ssid_hex}</hex>
                              <name>#{_ap.ssid}</name>
                            </SSID>
                          </SSIDConfig>
                          <connectionType>ESS</connectionType>
                          <connectionMode>manual</connectionMode>
                          <MSM>
                            <security>
                              <authEncryption>
                                <authentication>open</authentication>
                                <encryption>none</encryption>
                                <useOneX>false</useOneX>
                              </authEncryption>
                            </security>
                          </MSM>
                        </WLANProfile>"
          #
          # (3) Write to XML file; wait until done.
          #
          xmlWriteRequest = new Future
          fs.writeFile "#{_ap.ssid}.xml", xmlContent, (err) ->
            if err?
              WiFiLog err, true
              xmlWriteRequest.return false
            else
              xmlWriteRequest.return true
          if !xmlWriteRequest.wait()
            return {
              success: false
              msg: "Encountered an error connecting to AP:"
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

      for com in connectToAPChain
        WiFiLog "Executing:\t#{COMMANDS[com]}"
        #
        # Run the command, handle any errors that get thrown.
        #
        try
          stdout = execSync COMMANDS[com]
        catch error
          unless /nmcli device wifi connect/.test(COMMANDS[com])
            WiFiLog error, true
            return {
              success: false
              msg: error
            }
        #
        # If we've made it this far, check the output.
        #
        if process.platform is "darwin" and stdout is "Could not find network #{_ap.ssid}."
          WiFiLog stdout, true
          return {
            success: false
            msg: stdout
          }
        #
        # Otherwise, so far so good!
        #
        WiFiLog "Success!"
      #
      # We've made it through every command in the chain with no errors.
      #
      return {
        success: true
        msg: "Successfully connected to #{_ap.ssid}!"
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
