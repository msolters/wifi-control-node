# On Windows, we need write .xml files to create network profiles :(
fs = require 'fs'

parsePatterns =
  netsh_line: new RegExp /([^:]+): (.+)/

connectionStateMap =
  connected: "connected" # Win32 & Linux
  disconnected: "disconnected" # Win32 & Linux
  associating: "connecting" # Win32

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
  connectToAP: ( _ap ) ->
    @WiFiLog "Generating win32 wireless profile..."
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
      @WiFiLog _msg, true
      return {
        success: false
        msg: _msg
      }

    #
    # (4) Load new XML profile, and connect to SSID.
    #
    COMMANDS =
      loadProfile: "netsh #{@WiFiControlSettings.iface} add profile filename=\"#{_ap.ssid}.xml\""
      connect: "netsh #{@WiFiControlSettings.iface} connect ssid=\"#{_ap.ssid}\" name=\"#{_ap.ssid}\""
    connectToAPChain = [ "loadProfile", "connect" ]

    #
    # (5) Connect to AP using using the above constructed
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
      # Otherwise, so far so good!
      #
      @WiFiLog "Success!"

    @WiFiLog "Removing temporary WiFi config file..."
    @execSync "del \".\\#{_ap.ssid}.xml\""

  #
  # In Windows, we are just disconnecting from the current network.
  # This typically causes the wireless to then re-connect to its first
  # preference.
  #
  resetWiFi: ->
    #
    # (1) Construct a chain of commands to disconnect
    #     from the current WiFi network
    #
    COMMANDS =
      disconnect: "netsh #{@WiFiControlSettings.iface} disconnect"
    resetWiFiChain = [ "disconnect" ]

    #
    # (2) Execute each command.
    #
    for com in resetWiFiChain
      @WiFiLog "Executing:\t#{COMMANDS[com]}"
      stdout = @execSync COMMANDS[com]
      _msg = "Success!"
      @WiFiLog _msg
