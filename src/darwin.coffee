AirPortBinary = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

parsePatterns =
  airport_line: new RegExp /(.+): (.+)/

connectionStateMap =
  init: "disconnected"  # MacOS
  running: "connected"  # MacOS

powerStateMap =
  On: true        # MacOS
  Off: false      # MacOS

module.exports =
  autoFindInterface: ->
    @WiFiLog "Host machine is MacOS."
    # On Mac, we get use the results of getting the route to
    # a public IP, and parse for interfaces.
    findInterfaceCom = "networksetup -listallhardwareports | awk '/^Hardware Port: (Wi-Fi|AirPort)$/{getline;print $2}'"
    @WiFiLog "Executing: #{findInterfaceCom}"
    _interface = @execSync findInterfaceCom
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
  # For MacOS, parse `airport -I` to acquire networking interface data.
  #
  getIfaceState: ->
    interfaceState = {}
    connectionData = @execSync "#{AirPortBinary} -I"
    for ln, k in connectionData.split '\n'
      try
        parsedLine = parsePatterns.airport_line.exec( ln.trim() )
        KEY = parsedLine[1]
        VALUE = parsedLine[2]
      catch error
        continue  # this line was not a key: value pair!
      switch KEY
        when "state"
          interfaceState.connection = connectionStateMap[ VALUE ]
        when "SSID"
          interfaceState.ssid = VALUE
      break if KEY is "SSID"  # we have everything we need!
    #
    # (2) Get Interface Power State
    #
    powerData = @execSync "networksetup -getairportpower #{@WiFiControlSettings.iface}"
    try
      parsedLine = parsePatterns.airport_line.exec( powerData.trim() )
      KEY = parsedLine[1]
      VALUE = parsedLine[2]
    catch error
      return {
        success: false
        msg: "Unable to retrieve state of network interface #{@WiFiControlSettings.iface}."
      }
    interfaceState.power = powerStateMap[ VALUE ]
    return interfaceState

  #
  # For MacOS, we will use networksetup
  #
  connectToAP: ( _ap ) ->
    #
    # (1)
    #
    COMMANDS =
      connect: "networksetup -setairportnetwork #{@WiFiControlSettings.iface} \"#{_ap.ssid}\""
    if _ap.password.length
      COMMANDS.connect += " \"#{_ap.password}\""
    connectToAPChain = [ "connect" ]

    #
    # (2) Connect to AP using using the above constructed
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

      #
      # Listen for MacOS-specific errors.
      #
      if stdout is "Could not find network #{_ap.ssid}."
        _msg = "Error: No network called #{_ap.ssid} could be found."
        @WiFiLog _msg, true
        return {
          success: false
          msg: _msg
        }
      #
      # Otherwise, so far so good!
      #
      @WiFiLog "Success!"

  #
  # In MacOS, we are going to turn the wireless off and then on again.
  # (lol)
  #
  resetWiFi: ->
    #
    # (1) Construct a chain of commands to restart
    #     Airport service
    #
    COMMANDS =
      enableAirport: "networksetup -setairportpower #{@WiFiControlSettings.iface} on"
      disableAirport: "networksetup -setairportpower #{@WiFiControlSettings.iface} off"
    resetWiFiChain = [ "disableAirport", "enableAirport" ]

    #
    # (2) Execute each command.
    #
    for com in resetWiFiChain
      @WiFiLog "Executing:\t#{COMMANDS[com]}"
      stdout = @execSync COMMANDS[com]
      _msg = "Success!"
      @WiFiLog _msg
