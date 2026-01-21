#include <ButtonConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <File.au3>

; --- Settings and File Paths ---
Global $configPath = @ScriptDir & "\sing-box\wireguard-config.json"
Global $singBoxExe = "nekobox_core.exe"
Global $gatewayExe = "go-pcap2socks.exe"
Global $runCmdPath = @ScriptDir & "\sing-box\run_config.cmd"
Global $pcapExePath = @ScriptDir & "\go-pcap2socks\go-pcap2socks.exe"
Global $g_fileContent = "LOADED" 

; --- GUI Design ---
$Form1 = GUICreate("WireGuard Bridge Manager", 480, 580, -1, -1)
GUISetBkColor(0xF4F4F4)

GUICtrlCreateLabel("WireGuard Bridge Manager", 20, 15, 440, 30, $SS_CENTER)
GUICtrlSetFont(-1, 16, 800, 0, "Segoe UI")

GUICtrlCreateGroup("1. Configuration and Mode", 20, 60, 440, 260)
$btnImport = GUICtrlCreateButton("IMPORT NEW WIREGUARD .CONF", 40, 95, 400, 40)
GUICtrlSetFont(-1, 10, 800)

GUICtrlCreateLabel("Operation Mode:", 40, 145, 100, 20)
$radioFull = GUICtrlCreateRadio("Full Tunnel", 145, 140, 100, 25)
$radioWhite = GUICtrlCreateRadio("Whitelist (Split)", 250, 140, 160, 25)

GUICtrlCreateLabel("Whitelist Domains (Loaded from JSON):", 40, 185, 400, 20)
$txtDomains = GUICtrlCreateEdit("", 40, 205, 400, 100, $ES_WANTRETURN + $WS_VSCROLL)
GUICtrlCreateGroup("", -99, -99, 1, 1)

GUICtrlCreateGroup("2. Service Control", 20, 330, 440, 180)
$lblStatus = GUICtrlCreateLabel("STATUS: CHECKING...", 40, 360, 400, 25, $SS_CENTER)
GUICtrlSetFont(-1, 11, 800)

$btnStart = GUICtrlCreateButton("START SYSTEM", 40, 400, 190, 50)
GUICtrlSetFont(-1, 10, 800)
GUICtrlSetColor(-1, 0x006600)

$btnStop = GUICtrlCreateButton("STOP SYSTEM", 250, 400, 190, 50)
GUICtrlSetFont(-1, 10, 800)
GUICtrlSetColor(-1, 0x990000)

$btnCheck = GUICtrlCreateButton("Check Status", 140, 465, 200, 25)
GUICtrlCreateGroup("", -99, -99, 1, 1)

; --- READ JSON ON STARTUP ---
_LoadExistingConfig()
_UpdateStatusIndicator()

GUISetState(@SW_SHOW)



While 1
    $nMsg = GUIGetMsg()
    Switch $nMsg
        Case $GUI_EVENT_CLOSE
            Exit
        Case $btnImport
            _ImportFile()
        Case $btnStart
            _StartServices()
        Case $btnStop
            _StopServices()
        Case $btnCheck
            _UpdateStatusIndicator()
    EndSwitch
WEnd

Func _LoadExistingConfig()
    If Not FileExists($configPath) Then
        GUICtrlSetState($radioFull, $GUI_CHECKED)
        GUICtrlSetData($lblStatus, "STATUS: NO CONFIG FOUND")
        $g_fileContent = "" 
        Return
    EndIf
    Local $jsonContent = FileRead($configPath)
    If StringInStr($jsonContent, '"final": "bypass"') Then
        GUICtrlSetState($radioWhite, $GUI_CHECKED)
        Local $domains = StringRegExp($jsonContent, '"domain_suffix":\s*\[([^\]]+)\]', 3)
        If Not @error Then
            Local $cleanDomains = StringReplace($domains[0], '"', "")
            $cleanDomains = StringReplace($cleanDomains, " ", "")
            $cleanDomains = StringReplace($cleanDomains, ",", @CRLF)
            GUICtrlSetData($txtDomains, StringStripWS($cleanDomains, 3))
        EndIf
    Else
        GUICtrlSetState($radioFull, $GUI_CHECKED)
    EndIf
    GUICtrlSetData($lblStatus, "STATUS: SETTINGS LOADED")
    GUICtrlSetColor($lblStatus, 0x0000FF)
EndFunc

Func _ImportFile()
    Local $sFilePath = FileOpenDialog("Select WireGuard .conf", @DesktopDir, "Config (*.conf)", 1)
    If @error Then Return
    $g_fileContent = FileRead($sFilePath)
    If $g_fileContent <> "" Then
        GUICtrlSetData($lblStatus, "STATUS: NEW FILE READY")
        GUICtrlSetColor($lblStatus, 0x0000FF)
    EndIf
EndFunc

Func _StartServices()
    Local $privKey, $address, $pubKey, $psk, $epIP, $epPort
    If $g_fileContent = "" Then
        MsgBox(48, "Warning", "Please import a .conf file!")
        Return
    ElseIf $g_fileContent = "LOADED" Then
        Local $currentJson = FileRead($configPath)
        $privKey = _RegExpFirst($currentJson, '"private_key":\s*"([^"]+)"')
        $address = _RegExpFirst($currentJson, '"local_address":\s*\["([^"]+)"\]')
        $pubKey  = _RegExpFirst($currentJson, '"peer_public_key":\s*"([^"]+)"')
        $psk     = _RegExpFirst($currentJson, '"pre_shared_key":\s*"([^"]+)"')
		$epIP = _RegExpFirst($currentJson, '"server":\s*"([^"]+)"(?=\s*,\s*"server_port")')
        $epPort  = _RegExpFirst($currentJson, '"server_port":\s*(\d+)')
    Else
        $privKey = _RegExpFirst($g_fileContent, '(?i)PrivateKey\s*=\s*([^\s\r\n]+)')
        $address = _RegExpFirst($g_fileContent, '(?i)Address\s*=\s*([^\s\r\n,]+)')
        $pubKey  = _RegExpFirst($g_fileContent, '(?i)PublicKey\s*=\s*([^\s\r\n]+)')
        $psk     = _RegExpFirst($g_fileContent, '(?i)PresharedKey\s*=\s*([^\s\r\n]+)')
        Local $endpointRaw = _RegExpFirst($g_fileContent, '(?i)Endpoint\s*=\s*([^\s\r\n]+)')
        Local $split = StringSplit($endpointRaw, ":")
        $epIP = $split[1]
        $epPort = $split[2]
    EndIf
	

    Local $isWhitelist = (GUICtrlRead($radioWhite) = $GUI_CHECKED)
    Local $routeFinal = ($isWhitelist ? "bypass" : "proxy")
    Local $whiteRule = ""
    If $isWhitelist Then
        Local $domainList = "", $rawText = GUICtrlRead($txtDomains)
        Local $aLines = StringSplit(StringReplace($rawText, @CR, ""), @LF)
        Local $first = True
        For $i = 1 To $aLines[0]
            Local $trimmed = StringStripWS($aLines[$i], 3)
            If $trimmed <> "" Then
                If Not $first Then $domainList &= ","
                $domainList &= '"' & $trimmed & '"'
                $first = False
            EndIf
        Next
        $whiteRule = '            {' & @CRLF & _
        '                "domain": [], "domain_keyword": [], "domain_regex": [],' & @CRLF & _
        '                "domain_suffix": [' & $domainList & '],' & @CRLF & _
        '                "geosite": [], "outbound": "proxy"' & @CRLF & _
        '            },'
    EndIf

    Local $jsonOutput = '{' & @CRLF & _
    '    "dns": {' & @CRLF & _
    '        "independent_cache": true,' & @CRLF & _
    '        "rules": [' & @CRLF & _
    '            { "outbound": "any", "server": "dns-direct" },' & @CRLF & _
    '            { "query_type": [32, 33], "server": "dns-block" },' & @CRLF & _
    '            { "domain_suffix": ".lan", "server": "dns-block" }' & @CRLF & _
    '        ],' & @CRLF & _
    '        "servers": [' & @CRLF & _
    '            { "address": "https://cloudflare-dns.com/dns-query", "address_resolver": "dns-local", "detour": "proxy", "tag": "dns-remote" },' & @CRLF & _
    '            { "address": "https://doh.pub/dns-query", "address_resolver": "dns-local", "detour": "direct", "tag": "dns-direct" },' & @CRLF & _
    '            { "address": "rcode://success", "tag": "dns-block" },' & @CRLF & _
    '            { "address": "local", "detour": "direct", "tag": "dns-local" }' & @CRLF & _
    '        ]' & @CRLF & _
    '    },' & @CRLF & _
    '    "inbounds": [{ "listen": "0.0.0.0", "listen_port": 2080, "sniff": true, "tag": "mixed-in", "type": "mixed" }],' & @CRLF & _
    '    "outbounds": [' & @CRLF & _
    '        { "type": "wireguard", "tag": "proxy", "server": "' & $epIP & '", "server_port": ' & Number($epPort) & ', "local_address": ["' & $address & '"], "private_key": "' & $privKey & '", "peer_public_key": "' & $pubKey & '", "pre_shared_key": "' & $psk & '", "mtu": 1280, "system_interface": false, "tag": "proxy" },' & @CRLF & _
    '        { "tag": "direct", "type": "direct" }, { "tag": "bypass", "type": "direct" }, { "tag": "block", "type": "block" }, { "tag": "dns-out", "type": "dns" }' & @CRLF & _
    '    ],' & @CRLF & _
    '    "route": {' & @CRLF & _
    '        "final": "' & $routeFinal & '",' & @CRLF & _
    '        "rules": [' & @CRLF & _
    '            { "outbound": "dns-out", "protocol": "dns" },' & @CRLF & _
    $whiteRule & @CRLF & _
    '            { "network": "udp", "outbound": "block", "port": [135, 137, 138, 139, 5353] },' & @CRLF & _
    '            { "ip_cidr": ["224.0.0.0/3", "ff00::/8"], "outbound": "block" },' & @CRLF & _
    '            { "outbound": "block", "source_ip_cidr": ["224.0.0.0/3", "ff00::/8"] }' & @CRLF & _
    '        ]' & @CRLF & _
    '    }' & @CRLF & _
    '}'

    FileDelete($configPath)
    Local $hFile = FileOpen($configPath, 2)
    FileWrite($hFile, $jsonOutput)
    FileClose($hFile)

    _StopServices()
    Run($runCmdPath, @ScriptDir & "\sing-box", @SW_HIDE)
    Run($pcapExePath, @ScriptDir & "\go-pcap2socks", @SW_HIDE)
    Sleep(2000) ; Wait 2s for tunnel to establish
    _UpdateStatusIndicator()
EndFunc

Func _StopServices()
    ProcessClose($singBoxExe)
    ProcessClose($gatewayExe)
    Sleep(500)
    _UpdateStatusIndicator()
EndFunc

; --- REAL-TIME SOCKS5 CHECK ---
Func _UpdateStatusIndicator()
    Local $sRunning = ProcessExists($singBoxExe)
    Local $gRunning = ProcessExists($gatewayExe)
    
    If Not $sRunning Or Not $gRunning Then
        GUICtrlSetData($lblStatus, "STATUS: SERVICES STOPPED")
        GUICtrlSetColor($lblStatus, 0xCC0000)
        Return
    EndIf

    ; If processes are running, check if SOCKS5 is actually WORKING
    GUICtrlSetData($lblStatus, "STATUS: TESTING TUNNEL...")
    GUICtrlSetColor($lblStatus, 0x0000FF)
    
    TCPStartup()
    Local $socket = TCPConnect("127.0.0.1", 2080)
    If $socket <> -1 Then
        TCPCloseSocket($socket)
        GUICtrlSetData($lblStatus, "STATUS: ACTIVE (TUNNEL OK)")
        GUICtrlSetColor($lblStatus, 0x008800)
    Else
        GUICtrlSetData($lblStatus, "STATUS: SERVICES UP (TUNNEL ERROR)")
        GUICtrlSetColor($lblStatus, 0xFF8800) ; Orange
    EndIf
    TCPShutdown()
EndFunc

Func _RegExpFirst($string, $pattern)
    Local $aRet = StringRegExp($string, $pattern, 3)
    Return (@error ? "" : $aRet[0])
EndFunc