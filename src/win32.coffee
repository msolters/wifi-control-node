parsePatterns =
  netsh_line: new RegExp /([^:]+): (.+)/

connectionStateMap =
  connected: "connected" # Win32 & Linux
  disconnected: "disconnected" # Win32 & Linux
  associating: "connecting" # Win32

module.exports =
  autoFindInterface: ->
    @WiFiLog "Host machine is Windows."
    # On windows we are currently assuming wlan by default.
    findInterfaceCom = "echo wlan"
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
  # For Windows, parse netsh to acquire networking interface data.
  #
  getIfaceState: ->
    interfaceState = {}
    connectionData = @execSync "netsh #{@WiFiControlSettings.iface} show interface"
    for ln, k in connectionData.split '\n'
      try
        ln_trim = ln.trim()
        if ln_trim is "Software Off"
          interfaceState =
            ssid: null
            connected: false
            power: false
          break
        else
          parsedLine = parsePatterns.netsh_line.exec( ln_trim )
          KEY = parsedLine[1].trim()
          VALUE = parsedLine[2].trim()
      catch error
        continue  # this line was not a key: value pair!
      interfaceState.power = true
      switch KEY
        when "State"
          interfaceState.connection = connectionStateMap[ VALUE ]
        when "SSID"
          interfaceState.ssid = VALUE
        when "Radio status"
          if VALUE is "Hardware Off"
            interfaceState =
              ssid: null
              connected: false
              power: false
            break
      break if KEY is "SSID"  # we have everything we need! -- NOTE: we may not get this on Windows!
    return interfaceState
