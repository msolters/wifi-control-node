parsePatterns =
  nmcli_line: new RegExp /([^:]+):\s+(.+)/

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
    # On linux, we use the results of `nmcli device status` and parse for
    # active `wlan*` interfaces.
    findInterfaceCom = "nmcli -m multiline device status | grep wlan"
    @WiFiLog "Executing: #{findInterfaceCom}"
    _interfaceLine = @execSync findInterfaceCom
    parsedLine = parsePatterns.nmcli_line.exec( _interfaceLine.trim() )
    _interface = parsedLine[2]
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
  # For Linux, parse nmcli to acquire networking interface data.
  #
  getIfaceState: ->
    interfaceState = {}
    #
    # (1) Get Interface Power State
    #
    powerData = @execSync "nmcli networking"
    interfaceState.power = powerStateMap[ powerData.trim() ]
    if interfaceState.power
      #
      # (2) First, we get connection name & state
      #
      foundInterface = false
      connectionData = @execSync "nmcli -m multiline device status"
      connectionName = null
      for ln, k in connectionData.split '\n'
        try
          parsedLine = parsePatterns.nmcli_line.exec( ln.trim() )
          KEY = parsedLine[1]
          VALUE = parsedLine[2]
          VALUE = null if VALUE is "--"
        catch error
          continue  # this line was not a key: value pair!
        switch KEY
          when "DEVICE"
            foundInterface = true if VALUE is @WiFiControlSettings.iface
          when "STATE"
            interfaceState.connection = connectionStateMap[ VALUE ] if foundInterface
          when "CONNECTION"
            connectionName = VALUE if foundInterface
        break if KEY is "CONNECTION" and foundInterface # we have everything we need!
      # If we didn't find anything...
      unless foundInterface
        return {
          success: false
          msg: "Unable to retrieve state of network interface #{@WiFiControlSettings.iface}."
        }
      if connectionName
        #
        # (3) Next, we get the actual SSID
        #
        try
          ssidData = @execSync "nmcli -m multiline connection show \"#{connectionName}\" | grep 802-11-wireless.ssid"
          parsedLine = parsePatterns.nmcli_line.exec( ssidData.trim() )
          interfaceState.ssid = parsedLine[2]
        catch error
          return {
            success: false
            msg: "Error while retrieving SSID information of network interface #{@WiFiControlSettings.iface}: #{error.stderr}"
          }
      else
        interfaceState.ssid = null
    else
      interfaceState.connection = connectionStateMap[ VALUE ]
      interfaceState.ssid = null
    return interfaceState

  #
  # We leverage nmcli to scan nearby APs in Linux
  #
  scanForWiFi: ->
    #
    # Use nmcli to list visible wifi networks.
    #
    scanResults = @execSync "nmcli -m multiline device wifi list"
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
    return networks

  #
  # With Linux, we can use nmcli to do the heavy lifting.
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
      disableNetworking: "nmcli networking off"
      enableNetworking: "nmcli networking on"
    resetWiFiChain = [ "disableNetworking", "enableNetworking" ]

    #
    # (2) Execute each command.
    #
    for com in resetWiFiChain
      @WiFiLog "Executing:\t#{COMMANDS[com]}"
      stdout = @execSync COMMANDS[com]
      _msg = "Success!"
      @WiFiLog _msg
