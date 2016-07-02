parsePatterns =
  iwconfig_line: new RegExp /([^ ]+)/
  iw_dev_link_line: new RegExp /([^:]+): ([^\n]+)/
  iwlist:
    new_cell: new RegExp /.*BSS [0-9a-z]{2}:.*/
    ssid: new RegExp /.*SSID: (.*).*/
    encryption: new RegExp /.*Privacy.*/
    signal: new RegExp /.*signal: (-[0-9\.]+).*/
    channel: new RegExp /.*DS Parameter set: channel ([0-9]+)/

connectionStateMap =
  connected: "connected" # Win32 & Linux
  disconnected: "disconnected" # Win32 & Linux
  connecting: "connecting"  # Linux

powerStateMap =
  enabled: true   # linux
  disabled: false # linux

module.exports =
  autoFindInterface: ->
    @WiFiLog "Host machine is Linux."
    # On linux, we use the results of `iwconfig` and parse for
    # active 802.11 radios.
    # There could be more than one choice, but we always just grab the first
    # result.
    findInterfaceCom = "iwconfig | grep 802.11"
    @WiFiLog "Executing: #{findInterfaceCom}"
    _interfaceLine = @execSync findInterfaceCom
    parsedLine = parsePatterns.iwconfig_line.exec( _interfaceLine.trim() )
    _interface = parsedLine[0]
    if _interface
      _iface = _interface.trim()
      _msg = "Automatically located wireless interface #{_iface}."
      @WiFiLog _msg
      return {
        success: true
        msg: _msg
        interface: _iface
      }
    else
      _msg = "Error: No network interface found."
      @WiFiLog _msg, true
      return {
        success: false
        msg: _msg
        interface: null
      }

  #
  # For Linux, parse iw dev link to acquire networking interface data.
  #
  getIfaceState: ->
    interfaceState = {}
    connectionState = @execSync "iw dev #{@WiFiControlSettings.iface} link"
    if connectionState.indexOf("command failed: no such device") == -1
      interfaceState.power = true
      connectionStateLines = connectionState.split("\n")
      if connectionStateLines[0].indexOf("Not connected") > -1
        interfaceState.connection = "disconnected"
      else if connectionStateLines[0].indexOf("Connected to") > -1
        interfaceState.connection = "connected"
        for ln, k in connectionStateLines.slice(1)
          try
            parsedLine = parsePatterns.iw_dev_link_line.exec( ln.trim() )
            KEY = parsedLine[1]
            VALUE = parsedLine[2]
          catch error
            continue
          switch KEY
            when "SSID"
              interfaceState.ssid = VALUE
              break
        interfaceState.ssid = null if !interfaceState.ssid?
    else
      interfaceState.power = false
      interfaceState.connection = "disconnected"
      interfaceState.ssid = null
    return interfaceState

  #
  # We leverage nmcli to scan nearby APs in Linux
  #
  scanForWiFi: ->
    #
    # Use iw to list visible wifi networks.
    #
    scanResults = @execSync "sudo iw dev #{@WiFiControlSettings.iface} scan ap-force"
    networks = []
    #
    # Parse the results into an array of AP objects to match
    # the structure found in node-wifiscanner2 for win32 and MacOS.
    #
    _network =
      ssid: null
      security: false
      signal: null
      channel: null
    for ln, k in scanResults.split("\n")
      line = ln.trim()
      if parsePatterns.iwlist.new_cell.test ln
        # This is a new cell, reset the current scan result object.
        _network =
          ssid: null
          security: false
          signal_level: null
          channel: null
        continue

      ssid_parse = parsePatterns.iwlist.ssid.exec ln
      if ssid_parse
        _network.ssid = ssid_parse[1]
        # This is the last line of the current cell!
        if _network.ssid.length
          networks.push _network
        continue

      if parsePatterns.iwlist.encryption.test ln
        _network.security = true

      channel_parse = parsePatterns.iwlist.channel.exec ln
      if channel_parse
        console.log channel_parse
        _network.channel = parseInt channel_parse[1]

      signal_parse = parsePatterns.iwlist.signal.exec ln
      if signal_parse
        _network.signal = parseInt signal_parse[1]
    return networks

  #
  # With Linux, we can use iw to do the heavy lifting.
  #
  connectToAP: ( _ap ) ->
    #
    # (1) Does a connection that matches the name of the ssid
    #     already exist?
    #
    COMMANDS =
      delete: "nmcli connection delete \"#{_ap.ssid}\""
      connect: "nmcli device wifi connect \"#{_ap.ssid}\""
    if _ap.password.length
      COMMANDS.connect += " password \"#{_ap.password}\""
    try
      stdout = @execSync "nmcli connection show \"#{_ap.ssid}\""
      ssidExist = true if stdout.length
    catch error
      ssidExist = false

    #
    # (2) Delete the old connection, if there is one.
    #     Then, create a new connection.
    #
    connectToAPChain = []
    if ssidExist
      @WiFiLog "It appears there is already a connection for this SSID."
      connectToAPChain.push "delete"
    connectToAPChain.push "connect"

    #
    # (3) Connect to AP using using the above constructed
    #     command chain.
    #
    for com in connectToAPChain
      @WiFiLog "Executing:\t#{COMMANDS[com]}"
      #
      # Run the command, handle any errors that get thrown.
      #
      try
        stdout = @execSync COMMANDS[com]
      catch error
        if error.stderr.toString().trim() is "Error: No network with SSID '#{_ap.ssid}' found."
          _msg = "Error: No network called #{_ap.ssid} could be found."
          @WiFiLog _msg, true
          return {
            success: false
            msg: _msg
          }
        else if error.stderr.toString().search /Error:/ != -1
          _msg = error.stderr.toString().trim()
          @WiFiLog _msg, true
          return {
            success: false
            msg: _msg
          }
        # Ignore nmcli's add/modify errors, this is a system bug
        unless /nmcli device wifi connect/.test(COMMANDS[com])
          @WiFiLog error, true
          return {
            success: false
            msg: error
          }
      #
      # Otherwise, so far so good!
      #
      @WiFiLog "Success!"

  #
  # With Linux, we just restart the network-manager, which will
  # immediately force its own preferences and defaults.
  #
  resetWiFi: ->
    #
    # (1) Construct a chain of commands to restart
    #     the Network Manager service
    #
    COMMANDS =
      disableNetworking: "sudo ifconfig #{@WiFiControlSettings.iface} down"
      enableNetworking: "sudo ifconfig #{@WiFiControlSettings.iface} up"
    resetWiFiChain = [ "disableNetworking", "enableNetworking" ]

    #
    # (2) Execute each command.
    #
    for com in resetWiFiChain
      @WiFiLog "Executing:\t#{COMMANDS[com]}"
      stdout = @execSync COMMANDS[com]
      _msg = "Success!"
      @WiFiLog _msg
