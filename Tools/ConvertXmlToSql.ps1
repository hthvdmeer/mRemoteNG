# ConvertXmlToSql.ps1
# Converts an mRemoteNG XML connections file to SQL INSERT statements for MariaDB.
# Passwords are re-encrypted with the mRemoteNG default key ("mR3m").
# Usage: .\ConvertXmlToSql.ps1 -XmlFile "path\to\confCons.xml" -OutputFile "output.sql"

param(
    [Parameter(Mandatory)][string]$XmlFile,
    [Parameter(Mandatory)][string]$OutputFile,
    [string]$EncryptionKey = "mR3m"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Encrypt-Value([string]$plaintext) {
    if ([string]::IsNullOrEmpty($plaintext)) { return "" }
    $keyBytes = [System.Security.Cryptography.MD5]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($EncryptionKey))
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.BlockSize = 128
    $aes.Key = $keyBytes
    $aes.GenerateIV()
    $ms = [System.IO.MemoryStream]::new()
    $ms.Write($aes.IV, 0, 16)
    $cs = [System.Security.Cryptography.CryptoStream]::new(
        $ms, $aes.CreateEncryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write)
    $data = [System.Text.Encoding]::UTF8.GetBytes($plaintext)
    $cs.Write($data, 0, $data.Length)
    $cs.FlushFinalBlock()
    return [Convert]::ToBase64String($ms.ToArray())
}

function B([string]$val) {
    # XML boolean string -> tinyint
    if ($val -eq "true") { return 1 } else { return 0 }
}

function S([string]$val) {
    # SQL-escape a string value (returns NULL if null/empty is expected to be NULL, or quoted string)
    if ($null -eq $val) { return "NULL" }
    $escaped = $val.Replace("\", "\\").Replace("'", "''")
    return "'$escaped'"
}

function SN([string]$val) {
    # SQL-escape: return NULL when empty, quoted string otherwise
    if ([string]::IsNullOrEmpty($val)) { return "NULL" }
    $escaped = $val.Replace("\", "\\").Replace("'", "''")
    return "'$escaped'"
}

function Attr([System.Xml.XmlElement]$node, [string]$name, [string]$default = "") {
    $a = $node.GetAttribute($name)
    if ($null -eq $a -or $a -eq "") { return $default }
    return $a
}

# ---------------------------------------------------------------------------
# Recursively walk XML nodes and collect rows
# ---------------------------------------------------------------------------

$rows = [System.Collections.Generic.List[hashtable]]::new()
$positionCounter = 1
$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

function Process-Node([System.Xml.XmlElement]$xmlNode, [string]$parentId) {
    $type = $xmlNode.GetAttribute("Type")
    if ($type -ne "Container" -and $type -ne "Connection") { return }

    $constantId = [System.Guid]::NewGuid().ToString()
    $script:positionCounter++

    $row = @{
        ConstantID   = $constantId
        PositionID   = $script:positionCounter
        ParentID     = $parentId
        LastChange   = $script:now
        Name         = Attr $xmlNode "Name"
        Type         = $type
        Expanded     = B (Attr $xmlNode "Expanded" "false")
        AutomaticResize  = B (Attr $xmlNode "AutomaticResize" "true")
        CacheBitmaps     = B (Attr $xmlNode "CacheBitmaps" "false")
        Colors           = Attr $xmlNode "Colors" "Colors16Bit"
        ConnectToConsole = B (Attr $xmlNode "ConnectToConsole" "false")
        Connected        = 0
        Description      = Attr $xmlNode "Descr"
        DisableCursorBlinking  = B (Attr $xmlNode "DisableCursorBlinking" "false")
        DisableCursorShadow    = B (Attr $xmlNode "DisableCursorShadow" "false")
        DisableFullWindowDrag  = B (Attr $xmlNode "DisableFullWindowDrag" "false")
        DisableMenuAnimations  = B (Attr $xmlNode "DisableMenuAnimations" "false")
        DisplayThemes    = B (Attr $xmlNode "DisplayThemes" "false")
        DisplayWallpaper = B (Attr $xmlNode "DisplayWallpaper" "false")
        Domain           = Attr $xmlNode "Domain"
        EnableDesktopComposition = B (Attr $xmlNode "EnableDesktopComposition" "false")
        EnableFontSmoothing      = B (Attr $xmlNode "EnableFontSmoothing" "false")
        ExtApp           = Attr $xmlNode "ExtApp"
        Favorite         = B (Attr $xmlNode "Favorite" "false")
        Hostname         = Attr $xmlNode "Hostname"
        Icon             = Attr $xmlNode "Icon" "mRemoteNG"
        LoadBalanceInfo  = Attr $xmlNode "LoadBalanceInfo"
        MacAddress       = Attr $xmlNode "MacAddress"
        OpeningCommand   = ""
        Panel            = Attr $xmlNode "Panel" "General"
        Password         = Encrypt-Value (Attr $xmlNode "Password")
        Port             = Attr $xmlNode "Port" "3389"
        PostExtApp       = Attr $xmlNode "PostExtApp"
        PreExtApp        = Attr $xmlNode "PreExtApp"
        Protocol         = Attr $xmlNode "Protocol" "RDP"
        PuttySession     = Attr $xmlNode "PuttySession" "Default Settings"
        RDGatewayDomain  = Attr $xmlNode "RDGatewayDomain"
        RDGatewayHostname = Attr $xmlNode "RDGatewayHostname"
        RDGatewayPassword = Encrypt-Value (Attr $xmlNode "RDGatewayPassword")
        RDGatewayUsageMethod = Attr $xmlNode "RDGatewayUsageMethod" "Never"
        RDGatewayUseConnectionCredentials = Attr $xmlNode "RDGatewayUseConnectionCredentials" "Yes"
        RDGatewayUsername = Attr $xmlNode "RDGatewayUsername"
        RDPAlertIdleTimeout     = B (Attr $xmlNode "RDPAlertIdleTimeout" "false")
        RDPAuthenticationLevel  = Attr $xmlNode "RDPAuthenticationLevel" "NoAuth"
        RDPMinutesToIdleTimeout = Attr $xmlNode "RDPMinutesToIdleTimeout" "0"
        RdpVersion       = Attr $xmlNode "RdpVersion" "rdc6"
        RedirectAudioCapture = B (Attr $xmlNode "RedirectAudioCapture" "false")
        RedirectClipboard    = B (Attr $xmlNode "RedirectClipboard" "false")
        RedirectDiskDrives   = Attr $xmlNode "RedirectDiskDrives" "false"
        RedirectDiskDrivesCustom = ""
        RedirectKeys     = B (Attr $xmlNode "RedirectKeys" "false")
        RedirectPorts    = B (Attr $xmlNode "RedirectPorts" "false")
        RedirectPrinters = B (Attr $xmlNode "RedirectPrinters" "false")
        RedirectSmartCards = B (Attr $xmlNode "RedirectSmartCards" "false")
        RedirectSound    = Attr $xmlNode "RedirectSound" "DoNotPlay"
        RenderingEngine  = Attr $xmlNode "RenderingEngine" "IE"
        Resolution       = Attr $xmlNode "Resolution" "FitToWindow"
        SSHOptions       = Attr $xmlNode "SSHOptions"
        SSHTunnelConnectionName = Attr $xmlNode "SSHTunnelConnectionName"
        SoundQuality     = Attr $xmlNode "SoundQuality" "Dynamic"
        UseCredSsp       = B (Attr $xmlNode "UseCredSsp" "true")
        UseEnhancedMode  = B (Attr $xmlNode "UseEnhancedMode" "false")
        UseVmId          = B (Attr $xmlNode "UseVmId" "false")
        UserField        = Attr $xmlNode "UserField"
        Username         = Attr $xmlNode "Username"
        VNCAuthMode      = Attr $xmlNode "VNCAuthMode" "AuthVNC"
        VNCColors        = Attr $xmlNode "VNCColors" "ColNormal"
        VNCCompression   = Attr $xmlNode "VNCCompression" "CompNone"
        VNCEncoding      = Attr $xmlNode "VNCEncoding" "EncHextile"
        VNCProxyIP       = Attr $xmlNode "VNCProxyIP"
        VNCProxyPassword = Encrypt-Value (Attr $xmlNode "VNCProxyPassword")
        VNCProxyPort     = Attr $xmlNode "VNCProxyPort" "0"
        VNCProxyType     = Attr $xmlNode "VNCProxyType" "ProxyNone"
        VNCProxyUsername = Attr $xmlNode "VNCProxyUsername"
        VNCSmartSizeMode = Attr $xmlNode "VNCSmartSizeMode" "SmartSAspect"
        VNCViewOnly      = B (Attr $xmlNode "VNCViewOnly" "false")
        VmId             = Attr $xmlNode "VmId"
        ICAEncryptionStrength = Attr $xmlNode "ICAEncryptionStrength" "EncrBasic"
        InheritAutomaticResize  = B (Attr $xmlNode "InheritAutomaticResize" "false")
        InheritCacheBitmaps     = B (Attr $xmlNode "InheritCacheBitmaps" "false")
        InheritColors           = B (Attr $xmlNode "InheritColors" "false")
        InheritDescription      = B (Attr $xmlNode "InheritDescription" "false")
        InheritDisableCursorBlinking  = B (Attr $xmlNode "InheritDisableCursorBlinking" "false")
        InheritDisableCursorShadow    = B (Attr $xmlNode "InheritDisableCursorShadow" "false")
        InheritDisableFullWindowDrag  = B (Attr $xmlNode "InheritDisableFullWindowDrag" "false")
        InheritDisableMenuAnimations  = B (Attr $xmlNode "InheritDisableMenuAnimations" "false")
        InheritDisplayThemes    = B (Attr $xmlNode "InheritDisplayThemes" "false")
        InheritDisplayWallpaper = B (Attr $xmlNode "InheritDisplayWallpaper" "false")
        InheritDomain           = B (Attr $xmlNode "InheritDomain" "false")
        InheritEnableDesktopComposition = B (Attr $xmlNode "InheritEnableDesktopComposition" "false")
        InheritEnableFontSmoothing      = B (Attr $xmlNode "InheritEnableFontSmoothing" "false")
        InheritExtApp           = B (Attr $xmlNode "InheritExtApp" "false")
        InheritFavorite         = B (Attr $xmlNode "InheritFavorite" "false")
        InheritICAEncryptionStrength = B (Attr $xmlNode "InheritICAEncryptionStrength" "false")
        InheritIcon             = B (Attr $xmlNode "InheritIcon" "false")
        InheritLoadBalanceInfo  = B (Attr $xmlNode "InheritLoadBalanceInfo" "false")
        InheritMacAddress       = B (Attr $xmlNode "InheritMacAddress" "false")
        InheritOpeningCommand   = 0
        InheritPanel            = B (Attr $xmlNode "InheritPanel" "false")
        InheritPassword         = B (Attr $xmlNode "InheritPassword" "false")
        InheritPort             = B (Attr $xmlNode "InheritPort" "false")
        InheritPostExtApp       = B (Attr $xmlNode "InheritPostExtApp" "false")
        InheritPreExtApp        = B (Attr $xmlNode "InheritPreExtApp" "false")
        InheritProtocol         = B (Attr $xmlNode "InheritProtocol" "false")
        InheritPuttySession     = B (Attr $xmlNode "InheritPuttySession" "false")
        InheritRDGatewayDomain  = B (Attr $xmlNode "InheritRDGatewayDomain" "false")
        InheritRDGatewayHostname = B (Attr $xmlNode "InheritRDGatewayHostname" "false")
        InheritRDGatewayPassword = B (Attr $xmlNode "InheritRDGatewayPassword" "false")
        InheritRDGatewayUsageMethod = B (Attr $xmlNode "InheritRDGatewayUsageMethod" "false")
        InheritRDGatewayUseConnectionCredentials = B (Attr $xmlNode "InheritRDGatewayUseConnectionCredentials" "false")
        InheritRDGatewayExternalCredentialProvider = 0
        InheritRDGatewayUsername = B (Attr $xmlNode "InheritRDGatewayUsername" "false")
        InheritRDGatewayUserViaAPI = 0
        InheritRDPAlertIdleTimeout     = B (Attr $xmlNode "InheritRDPAlertIdleTimeout" "false")
        InheritRDPAuthenticationLevel  = B (Attr $xmlNode "InheritRDPAuthenticationLevel" "false")
        InheritRDPMinutesToIdleTimeout = B (Attr $xmlNode "InheritRDPMinutesToIdleTimeout" "false")
        InheritRdpVersion       = B (Attr $xmlNode "InheritRdpVersion" "false")
        InheritRedirectAudioCapture = B (Attr $xmlNode "InheritRedirectAudioCapture" "false")
        InheritRedirectClipboard    = B (Attr $xmlNode "InheritRedirectClipboard" "false")
        InheritRedirectDiskDrives   = B (Attr $xmlNode "InheritRedirectDiskDrives" "false")
        InheritRedirectDiskDrivesCustom = 0
        InheritRedirectKeys     = B (Attr $xmlNode "InheritRedirectKeys" "false")
        InheritRedirectPorts    = B (Attr $xmlNode "InheritRedirectPorts" "false")
        InheritRedirectPrinters = B (Attr $xmlNode "InheritRedirectPrinters" "false")
        InheritRedirectSmartCards = B (Attr $xmlNode "InheritRedirectSmartCards" "false")
        InheritRedirectSound    = B (Attr $xmlNode "InheritRedirectSound" "false")
        InheritRenderingEngine  = B (Attr $xmlNode "InheritRenderingEngine" "false")
        InheritResolution       = B (Attr $xmlNode "InheritResolution" "false")
        InheritSSHOptions       = B (Attr $xmlNode "InheritSSHOptions" "false")
        InheritSSHTunnelConnectionName = B (Attr $xmlNode "InheritSSHTunnelConnectionName" "false")
        InheritSoundQuality     = B (Attr $xmlNode "InheritSoundQuality" "false")
        InheritUseConsoleSession = B (Attr $xmlNode "InheritUseConsoleSession" "false")
        InheritUseCredSsp       = B (Attr $xmlNode "InheritUseCredSsp" "false")
        InheritUseRestrictedAdmin = 0
        InheritUseRCG           = 0
        InheritExternalCredentialProvider = 0
        InheritUserViaAPI       = 0
        UseRestrictedAdmin      = 0
        UseRCG                  = 0
        InheritUseEnhancedMode  = B (Attr $xmlNode "InheritUseEnhancedMode" "false")
        InheritUseVmId          = B (Attr $xmlNode "InheritUseVmId" "false")
        InheritUserField        = B (Attr $xmlNode "InheritUserField" "false")
        InheritUsername         = B (Attr $xmlNode "InheritUsername" "false")
        InheritVNCAuthMode      = B (Attr $xmlNode "InheritVNCAuthMode" "false")
        InheritVNCColors        = B (Attr $xmlNode "InheritVNCColors" "false")
        InheritVNCCompression   = B (Attr $xmlNode "InheritVNCCompression" "false")
        InheritVNCEncoding      = B (Attr $xmlNode "InheritVNCEncoding" "false")
        InheritVNCProxyIP       = B (Attr $xmlNode "InheritVNCProxyIP" "false")
        InheritVNCProxyPassword = B (Attr $xmlNode "InheritVNCProxyPassword" "false")
        InheritVNCProxyPort     = B (Attr $xmlNode "InheritVNCProxyPort" "false")
        InheritVNCProxyType     = B (Attr $xmlNode "InheritVNCProxyType" "false")
        InheritVNCProxyUsername = B (Attr $xmlNode "InheritVNCProxyUsername" "false")
        InheritVNCSmartSizeMode = B (Attr $xmlNode "InheritVNCSmartSizeMode" "false")
        InheritVNCViewOnly      = B (Attr $xmlNode "InheritVNCViewOnly" "false")
        InheritVmId             = B (Attr $xmlNode "InheritVmId" "false")
        StartProgram            = ""
        StartProgramWorkDir     = ""
        EC2Region               = $null
        EC2InstanceId           = $null
        ExternalCredentialProvider = $null
        ExternalAddressProvider = $null
        UserViaAPI              = ""
        EnvironmentTags         = $null
        InheritEnvironmentTags  = 0
        RDGatewayExternalCredentialProvider = $null
        RDGatewayUserViaAPI     = $null
    }

    $script:rows.Add($row)

    # Recurse into children
    foreach ($child in $xmlNode.ChildNodes) {
        if ($child -is [System.Xml.XmlElement]) {
            Process-Node $child $constantId
        }
    }
}

# ---------------------------------------------------------------------------
# Load XML and process
# ---------------------------------------------------------------------------

Write-Host "Reading $XmlFile ..."
[xml]$xml = Get-Content $XmlFile -Encoding UTF8

$rootElement = $xml.DocumentElement  # <mrng:Connections> or <Connections>

foreach ($child in $rootElement.ChildNodes) {
    if ($child -is [System.Xml.XmlElement]) {
        Process-Node $child "0"
    }
}

Write-Host "Found $($rows.Count) nodes. Generating SQL..."

# ---------------------------------------------------------------------------
# Generate SQL
# ---------------------------------------------------------------------------

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine("-- Generated by ConvertXmlToSql.ps1 on $(Get-Date)")
$null = $sb.AppendLine("-- Source: $XmlFile")
$null = $sb.AppendLine("-- Passwords encrypted with mRemoteNG default key")
$null = $sb.AppendLine("")
$null = $sb.AppendLine("USE ``mremoteng``;")
$null = $sb.AppendLine("")

foreach ($r in $rows) {
    $sql = @"
INSERT INTO ``tblCons`` (
    ``ConstantID``, ``PositionID``, ``ParentID``, ``LastChange``, ``Name``, ``Type``, ``Expanded``,
    ``AutomaticResize``, ``CacheBitmaps``, ``Colors``, ``ConnectToConsole``, ``Connected``,
    ``Description``, ``DisableCursorBlinking``, ``DisableCursorShadow``, ``DisableFullWindowDrag``,
    ``DisableMenuAnimations``, ``DisplayThemes``, ``DisplayWallpaper``, ``Domain``,
    ``EnableDesktopComposition``, ``EnableFontSmoothing``, ``ExtApp``, ``Favorite``,
    ``Hostname``, ``Icon``, ``LoadBalanceInfo``, ``MacAddress``, ``OpeningCommand``, ``Panel``,
    ``Password``, ``Port``, ``PostExtApp``, ``PreExtApp``, ``Protocol``, ``PuttySession``,
    ``RDGatewayDomain``, ``RDGatewayHostname``, ``RDGatewayPassword``, ``RDGatewayUsageMethod``,
    ``RDGatewayUseConnectionCredentials``, ``RDGatewayUsername``, ``RDPAlertIdleTimeout``,
    ``RDPAuthenticationLevel``, ``RDPMinutesToIdleTimeout``, ``RdpVersion``,
    ``RedirectAudioCapture``, ``RedirectClipboard``, ``RedirectDiskDrives``, ``RedirectDiskDrivesCustom``,
    ``RedirectKeys``, ``RedirectPorts``, ``RedirectPrinters``, ``RedirectSmartCards``,
    ``RedirectSound``, ``RenderingEngine``, ``Resolution``, ``SSHOptions``, ``SSHTunnelConnectionName``,
    ``SoundQuality``, ``UseCredSsp``, ``UseEnhancedMode``, ``UseVmId``, ``UserField``, ``Username``,
    ``VNCAuthMode``, ``VNCColors``, ``VNCCompression``, ``VNCEncoding``,
    ``VNCProxyIP``, ``VNCProxyPassword``, ``VNCProxyPort``, ``VNCProxyType``, ``VNCProxyUsername``,
    ``VNCSmartSizeMode``, ``VNCViewOnly``, ``VmId``, ``ICAEncryptionStrength``,
    ``InheritAutomaticResize``, ``InheritCacheBitmaps``, ``InheritColors``, ``InheritDescription``,
    ``InheritDisableCursorBlinking``, ``InheritDisableCursorShadow``, ``InheritDisableFullWindowDrag``,
    ``InheritDisableMenuAnimations``, ``InheritDisplayThemes``, ``InheritDisplayWallpaper``,
    ``InheritDomain``, ``InheritEnableDesktopComposition``, ``InheritEnableFontSmoothing``,
    ``InheritExtApp``, ``InheritFavorite``, ``InheritICAEncryptionStrength``, ``InheritIcon``,
    ``InheritLoadBalanceInfo``, ``InheritMacAddress``, ``InheritOpeningCommand``, ``InheritPanel``,
    ``InheritPassword``, ``InheritPort``, ``InheritPostExtApp``, ``InheritPreExtApp``,
    ``InheritProtocol``, ``InheritPuttySession``,
    ``InheritRDGatewayDomain``, ``InheritRDGatewayHostname``, ``InheritRDGatewayPassword``,
    ``InheritRDGatewayUsageMethod``, ``InheritRDGatewayUseConnectionCredentials``,
    ``InheritRDGatewayExternalCredentialProvider``, ``InheritRDGatewayUsername``, ``InheritRDGatewayUserViaAPI``,
    ``InheritRDPAlertIdleTimeout``, ``InheritRDPAuthenticationLevel``, ``InheritRDPMinutesToIdleTimeout``,
    ``InheritRdpVersion``, ``InheritRedirectAudioCapture``, ``InheritRedirectClipboard``,
    ``InheritRedirectDiskDrives``, ``InheritRedirectDiskDrivesCustom``, ``InheritRedirectKeys``,
    ``InheritRedirectPorts``, ``InheritRedirectPrinters``, ``InheritRedirectSmartCards``,
    ``InheritRedirectSound``, ``InheritRenderingEngine``, ``InheritResolution``,
    ``InheritSSHOptions``, ``InheritSSHTunnelConnectionName``, ``InheritSoundQuality``,
    ``InheritUseConsoleSession``, ``InheritUseCredSsp``, ``InheritUseRestrictedAdmin``, ``InheritUseRCG``,
    ``InheritExternalCredentialProvider``, ``InheritUserViaAPI``, ``UseRestrictedAdmin``, ``UseRCG``,
    ``InheritUseEnhancedMode``, ``InheritUseVmId``, ``InheritUserField``, ``InheritUsername``,
    ``InheritVNCAuthMode``, ``InheritVNCColors``, ``InheritVNCCompression``, ``InheritVNCEncoding``,
    ``InheritVNCProxyIP``, ``InheritVNCProxyPassword``, ``InheritVNCProxyPort``, ``InheritVNCProxyType``,
    ``InheritVNCProxyUsername``, ``InheritVNCSmartSizeMode``, ``InheritVNCViewOnly``, ``InheritVmId``,
    ``StartProgram``, ``StartProgramWorkDir``, ``EC2Region``, ``EC2InstanceId``,
    ``ExternalCredentialProvider``, ``ExternalAddressProvider``, ``UserViaAPI``,
    ``EnvironmentTags``, ``InheritEnvironmentTags``, ``RDGatewayExternalCredentialProvider``, ``RDGatewayUserViaAPI``
) VALUES (
    $(S $r.ConstantID), $($r.PositionID), $(S $r.ParentID), '$($r.LastChange)', $(S $r.Name), $(S $r.Type), $($r.Expanded),
    $($r.AutomaticResize), $($r.CacheBitmaps), $(S $r.Colors), $($r.ConnectToConsole), $($r.Connected),
    $(SN $r.Description), $($r.DisableCursorBlinking), $($r.DisableCursorShadow), $($r.DisableFullWindowDrag),
    $($r.DisableMenuAnimations), $($r.DisplayThemes), $($r.DisplayWallpaper), $(SN $r.Domain),
    $($r.EnableDesktopComposition), $($r.EnableFontSmoothing), $(SN $r.ExtApp), $($r.Favorite),
    $(SN $r.Hostname), $(S $r.Icon), $(SN $r.LoadBalanceInfo), $(SN $r.MacAddress), $(S $r.OpeningCommand), $(S $r.Panel),
    $(SN $r.Password), $($r.Port), $(SN $r.PostExtApp), $(SN $r.PreExtApp), $(S $r.Protocol), $(S $r.PuttySession),
    $(SN $r.RDGatewayDomain), $(SN $r.RDGatewayHostname), $(SN $r.RDGatewayPassword), $(S $r.RDGatewayUsageMethod),
    $(S $r.RDGatewayUseConnectionCredentials), $(SN $r.RDGatewayUsername), $($r.RDPAlertIdleTimeout),
    $(S $r.RDPAuthenticationLevel), $($r.RDPMinutesToIdleTimeout), $(S $r.RdpVersion),
    $($r.RedirectAudioCapture), $($r.RedirectClipboard), $(S $r.RedirectDiskDrives), $(S $r.RedirectDiskDrivesCustom),
    $($r.RedirectKeys), $($r.RedirectPorts), $($r.RedirectPrinters), $($r.RedirectSmartCards),
    $(S $r.RedirectSound), $(S $r.RenderingEngine), $(S $r.Resolution), $(S $r.SSHOptions), $(S $r.SSHTunnelConnectionName),
    $(S $r.SoundQuality), $($r.UseCredSsp), $($r.UseEnhancedMode), $($r.UseVmId), $(SN $r.UserField), $(SN $r.Username),
    $(S $r.VNCAuthMode), $(S $r.VNCColors), $(S $r.VNCCompression), $(S $r.VNCEncoding),
    $(SN $r.VNCProxyIP), $(SN $r.VNCProxyPassword), $($r.VNCProxyPort), $(S $r.VNCProxyType), $(SN $r.VNCProxyUsername),
    $(S $r.VNCSmartSizeMode), $($r.VNCViewOnly), $(SN $r.VmId), $(S $r.ICAEncryptionStrength),
    $($r.InheritAutomaticResize), $($r.InheritCacheBitmaps), $($r.InheritColors), $($r.InheritDescription),
    $($r.InheritDisableCursorBlinking), $($r.InheritDisableCursorShadow), $($r.InheritDisableFullWindowDrag),
    $($r.InheritDisableMenuAnimations), $($r.InheritDisplayThemes), $($r.InheritDisplayWallpaper),
    $($r.InheritDomain), $($r.InheritEnableDesktopComposition), $($r.InheritEnableFontSmoothing),
    $($r.InheritExtApp), $($r.InheritFavorite), $($r.InheritICAEncryptionStrength), $($r.InheritIcon),
    $($r.InheritLoadBalanceInfo), $($r.InheritMacAddress), $($r.InheritOpeningCommand), $($r.InheritPanel),
    $($r.InheritPassword), $($r.InheritPort), $($r.InheritPostExtApp), $($r.InheritPreExtApp),
    $($r.InheritProtocol), $($r.InheritPuttySession),
    $($r.InheritRDGatewayDomain), $($r.InheritRDGatewayHostname), $($r.InheritRDGatewayPassword),
    $($r.InheritRDGatewayUsageMethod), $($r.InheritRDGatewayUseConnectionCredentials),
    $($r.InheritRDGatewayExternalCredentialProvider), $($r.InheritRDGatewayUsername), $($r.InheritRDGatewayUserViaAPI),
    $($r.InheritRDPAlertIdleTimeout), $($r.InheritRDPAuthenticationLevel), $($r.InheritRDPMinutesToIdleTimeout),
    $($r.InheritRdpVersion), $($r.InheritRedirectAudioCapture), $($r.InheritRedirectClipboard),
    $($r.InheritRedirectDiskDrives), $($r.InheritRedirectDiskDrivesCustom), $($r.InheritRedirectKeys),
    $($r.InheritRedirectPorts), $($r.InheritRedirectPrinters), $($r.InheritRedirectSmartCards),
    $($r.InheritRedirectSound), $($r.InheritRenderingEngine), $($r.InheritResolution),
    $($r.InheritSSHOptions), $($r.InheritSSHTunnelConnectionName), $($r.InheritSoundQuality),
    $($r.InheritUseConsoleSession), $($r.InheritUseCredSsp), $($r.InheritUseRestrictedAdmin), $($r.InheritUseRCG),
    $($r.InheritExternalCredentialProvider), $($r.InheritUserViaAPI), $($r.UseRestrictedAdmin), $($r.UseRCG),
    $($r.InheritUseEnhancedMode), $($r.InheritUseVmId), $($r.InheritUserField), $($r.InheritUsername),
    $($r.InheritVNCAuthMode), $($r.InheritVNCColors), $($r.InheritVNCCompression), $($r.InheritVNCEncoding),
    $($r.InheritVNCProxyIP), $($r.InheritVNCProxyPassword), $($r.InheritVNCProxyPort), $($r.InheritVNCProxyType),
    $($r.InheritVNCProxyUsername), $($r.InheritVNCSmartSizeMode), $($r.InheritVNCViewOnly), $($r.InheritVmId),
    $(S $r.StartProgram), $(S $r.StartProgramWorkDir), NULL, NULL,
    NULL, NULL, $(S $r.UserViaAPI),
    NULL, 0, NULL, NULL
);
"@
    $null = $sb.AppendLine($sql)
}

$sb.ToString() | Set-Content $OutputFile -Encoding UTF8
Write-Host "Done. Written $($rows.Count) INSERT statements to $OutputFile"
