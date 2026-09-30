<#
.SYNOPSIS
    Displays complete hardware and system configuration in a clean, readable format.

.USAGE
    powershell -ExecutionPolicy Bypass -File .\HardwareInfo.ps1
    powershell -ExecutionPolicy Bypass -File .\HardwareInfo.ps1 -Export     # also saves a .txt report to Desktop

    Tip: Run PowerShell as Administrator for the most complete details
    (some serial numbers / disk data need admin rights).
#>

param(
    [switch]$Export
)

$ErrorActionPreference = 'SilentlyContinue'
$Host.UI.RawUI.WindowTitle = "Hardware Information Report"

# Collect plain-text copy of everything for optional export
$script:Report = New-Object System.Text.StringBuilder

# ---------------------------------------------------------------
#  Helper functions
# ---------------------------------------------------------------
function Write-Banner {
    param([string]$Text)
    $line = "=" * 78
    Write-Host ""
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host ("  " + $Text) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkCyan
    [void]$script:Report.AppendLine("")
    [void]$script:Report.AppendLine($line)
    [void]$script:Report.AppendLine("  $Text")
    [void]$script:Report.AppendLine($line)
}

function Write-SubHeader {
    param([string]$Text)
    Write-Host ""
    Write-Host ("  >> " + $Text) -ForegroundColor Yellow
    Write-Host ("  " + ("-" * 60)) -ForegroundColor DarkGray
    [void]$script:Report.AppendLine("")
    [void]$script:Report.AppendLine("  >> $Text")
    [void]$script:Report.AppendLine("  " + ("-" * 60))
}

function Write-Item {
    param(
        [string]$Label,
        $Value,
        [string]$Color = 'White'
    )
    if ($null -eq $Value -or "$Value".Trim() -eq '') { $Value = 'N/A' }
    $pad = $Label.PadRight(24)
    Write-Host ("    " + $pad) -NoNewline -ForegroundColor Gray
    Write-Host (": ") -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor $Color
    [void]$script:Report.AppendLine("    ${pad}: $Value")
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    return "{0:N0} bytes" -f $Bytes
}

function Convert-UShortArray {
    param($Array)
    if (-not $Array) { return $null }
    $s = -join ($Array | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
    return $s.Trim()
}

function Get-UsageBar {
    param([double]$Percent, [int]$Width = 25)
    $filled = [math]::Round(($Percent / 100) * $Width)
    if ($filled -gt $Width) { $filled = $Width }
    if ($filled -lt 0) { $filled = 0 }
    return "[" + ("#" * $filled) + ("." * ($Width - $filled)) + "]"
}

# ---------------------------------------------------------------
#  Title
# ---------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "   _   _ _____ _____ ____    ___ _   _ _____ ___  " -ForegroundColor Cyan
Write-Host "  | | | |  ___|_   _/ ___|  |_ _| \ | |  ___/ _ \ " -ForegroundColor Cyan
Write-Host "  | |_| | |_    | | \___ \   | ||  \| | |_ | | | |" -ForegroundColor Cyan
Write-Host "  |  _  |  _|   | |  ___) |  | || |\  |  _|| |_| |" -ForegroundColor Cyan
Write-Host "  |_| |_|_|     |_| |____/  |___|_| \_|_|   \___/ " -ForegroundColor Cyan
Write-Host ""
Write-Host "        SYSTEM & HARDWARE CONFIGURATION REPORT" -ForegroundColor White
Write-Host ("        Generated: " + (Get-Date -Format "dddd, dd MMMM yyyy  HH:mm:ss")) -ForegroundColor DarkGray

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "        Note: Not running as Administrator - some details may be limited." -ForegroundColor DarkYellow
}

Write-Host "`n  Collecting information, please wait..." -ForegroundColor DarkGray

# ---------------------------------------------------------------
#  Gather data
# ---------------------------------------------------------------
$cs      = Get-CimInstance Win32_ComputerSystem
$csp     = Get-CimInstance Win32_ComputerSystemProduct
$os      = Get-CimInstance Win32_OperatingSystem
$bios    = Get-CimInstance Win32_BIOS
$board   = Get-CimInstance Win32_BaseBoard
$chassis = Get-CimInstance Win32_SystemEnclosure
$cpus    = Get-CimInstance Win32_Processor
$ram     = Get-CimInstance Win32_PhysicalMemory
$gpus    = Get-CimInstance Win32_VideoController
$disks   = Get-CimInstance Win32_DiskDrive
$vols    = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$nics    = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true }
$nicCfg  = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
$sound   = Get-CimInstance Win32_SoundDevice
$battery = Get-CimInstance Win32_Battery
$monitor = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID
$kbd     = Get-CimInstance Win32_Keyboard
$mouse   = Get-CimInstance Win32_PointingDevice
$cache   = Get-CimInstance Win32_CacheMemory
$slots   = Get-CimInstance Win32_PhysicalMemoryArray
$tpm     = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm

# ---------------------------------------------------------------
#  1. COMPUTER / SYSTEM
# ---------------------------------------------------------------
Write-Banner "1. COMPUTER / SYSTEM"
Write-Item "Computer Name"       $cs.Name Green
Write-Item "Manufacturer"        $cs.Manufacturer
Write-Item "Model"               $cs.Model
Write-Item "System Family"       $cs.SystemFamily
Write-Item "System SKU"          $cs.SystemSKUNumber
Write-Item "System Type"         $cs.SystemType
Write-Item "Product UUID"        $csp.UUID
Write-Item "Product Serial No."  $csp.IdentifyingNumber Green
Write-Item "Chassis Serial No."  $chassis.SerialNumber
Write-Item "Chassis Type"        ($chassis.ChassisTypes -join ', ')
Write-Item "Domain / Workgroup"  $cs.Domain
Write-Item "Current User"       "$env:USERDOMAIN\$env:USERNAME"

# ---------------------------------------------------------------
#  2. OPERATING SYSTEM
# ---------------------------------------------------------------
Write-Banner "2. OPERATING SYSTEM"
$uptime = (Get-Date) - $os.LastBootUpTime
Write-Item "OS Name"             $os.Caption Green
Write-Item "Version"             $os.Version
Write-Item "Build Number"        $os.BuildNumber
Write-Item "Architecture"        $os.OSArchitecture
Write-Item "Install Date"        $os.InstallDate
Write-Item "Last Boot"           $os.LastBootUpTime
Write-Item "Uptime"              ("{0} days, {1} hrs, {2} min" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
Write-Item "Registered Owner"    $os.RegisteredUser
Write-Item "Product ID"          $os.SerialNumber
Write-Item "System Directory"    $os.SystemDirectory
Write-Item "Locale / Language"   ((Get-Culture).Name)
Write-Item "Time Zone"           ((Get-TimeZone).DisplayName)
Write-Item "PowerShell Version"  $PSVersionTable.PSVersion.ToString()

# ---------------------------------------------------------------
#  3. BIOS / FIRMWARE
# ---------------------------------------------------------------
Write-Banner "3. BIOS / FIRMWARE"
Write-Item "BIOS Vendor"         $bios.Manufacturer
Write-Item "BIOS Version"        $bios.SMBIOSBIOSVersion
Write-Item "BIOS Name"           $bios.Name
Write-Item "Release Date"        $bios.ReleaseDate
Write-Item "BIOS Serial No."     $bios.SerialNumber Green
Write-Item "SMBIOS Version"      ("{0}.{1}" -f $bios.SMBIOSMajorVersion, $bios.SMBIOSMinorVersion)
$secureBoot = try { if (Confirm-SecureBootUEFI) { 'Enabled' } else { 'Disabled' } } catch { 'Not supported / Legacy BIOS (or need Admin)' }
Write-Item "Secure Boot"         $secureBoot
if ($tpm) {
    Write-Item "TPM Present"     "Yes (Spec: $($tpm.SpecVersion.Split(',')[0]))"
    Write-Item "TPM Enabled"     $tpm.IsEnabled_InitialValue
} else {
    Write-Item "TPM"             "Not detected (or need Admin)"
}

# ---------------------------------------------------------------
#  4. MOTHERBOARD
# ---------------------------------------------------------------
Write-Banner "4. MOTHERBOARD"
Write-Item "Manufacturer"        $board.Manufacturer
Write-Item "Product / Model"     $board.Product Green
Write-Item "Version"             $board.Version
Write-Item "Serial Number"      $board.SerialNumber Green
Write-Item "Asset Tag"          $board.Tag

# ---------------------------------------------------------------
#  5. PROCESSOR
# ---------------------------------------------------------------
Write-Banner "5. PROCESSOR (CPU)"
$i = 0
foreach ($cpu in $cpus) {
    $i++
    Write-SubHeader "CPU Socket $i"
    Write-Item "Name"                 $cpu.Name.Trim() Green
    Write-Item "Manufacturer"         $cpu.Manufacturer
    Write-Item "Processor ID"         $cpu.ProcessorId
    Write-Item "Serial Number"        $cpu.SerialNumber
    Write-Item "Architecture"         $(switch ($cpu.Architecture) {0{'x86'}1{'MIPS'}5{'ARM'}9{'x64'}12{'ARM64'} default{$cpu.Architecture}})
    Write-Item "Socket Type"          $cpu.SocketDesignation
    Write-Item "Physical Cores"       $cpu.NumberOfCores
    Write-Item "Logical Processors"   $cpu.NumberOfLogicalProcessors
    Write-Item "Base Speed"           ("{0:N2} GHz" -f ($cpu.MaxClockSpeed / 1000))
    Write-Item "Current Speed"        ("{0:N2} GHz" -f ($cpu.CurrentClockSpeed / 1000))
    Write-Item "L2 Cache"             ("{0} KB" -f $cpu.L2CacheSize)
    Write-Item "L3 Cache"             ("{0} KB" -f $cpu.L3CacheSize)
    Write-Item "Virtualization"       $(if ($cpu.VirtualizationFirmwareEnabled) {'Enabled'} else {'Disabled / Unknown'})
    Write-Item "Current Load"         ("{0}%  {1}" -f $cpu.LoadPercentage, (Get-UsageBar $cpu.LoadPercentage))
}

# ---------------------------------------------------------------
#  6. MEMORY (RAM)
# ---------------------------------------------------------------
Write-Banner "6. MEMORY (RAM)"
$totalRam = ($ram | Measure-Object Capacity -Sum).Sum
$freeRam  = $os.FreePhysicalMemory * 1KB
$usedRam  = $totalRam - $freeRam
$ramPct   = if ($totalRam) { [math]::Round(($usedRam / $totalRam) * 100, 1) } else { 0 }
Write-Item "Total Installed"      (Format-Size $totalRam) Green
Write-Item "In Use"               ("{0}  ({1}%)  {2}" -f (Format-Size $usedRam), $ramPct, (Get-UsageBar $ramPct))
Write-Item "Available"            (Format-Size $freeRam)
Write-Item "Max Supported"        (Format-Size (($slots | Measure-Object MaxCapacity -Sum).Sum * 1KB))
Write-Item "Total Slots"          (($slots | Measure-Object MemoryDevices -Sum).Sum)
Write-Item "Slots Used"           ($ram | Measure-Object).Count

$memType = @{0='Unknown';20='DDR';21='DDR2';22='DDR2 FB-DIMM';24='DDR3';26='DDR4';34='DDR5'}
$formF   = @{8='DIMM';12='SODIMM';13='SRIMM';0='Unknown'}
foreach ($m in $ram) {
    Write-SubHeader ("Slot: " + $m.DeviceLocator + "  (" + $m.BankLabel + ")")
    Write-Item "Capacity"           (Format-Size $m.Capacity) Green
    Write-Item "Manufacturer"       $m.Manufacturer
    Write-Item "Part Number"        $m.PartNumber.Trim()
    Write-Item "Serial Number"      $m.SerialNumber
    $t = if ($m.SMBIOSMemoryType) { $m.SMBIOSMemoryType } else { $m.MemoryType }
    Write-Item "Type"               $(if ($memType.ContainsKey([int]$t)) { $memType[[int]$t] } else { "Code $t" })
    Write-Item "Form Factor"        $(if ($formF.ContainsKey([int]$m.FormFactor)) { $formF[[int]$m.FormFactor] } else { $m.FormFactor })
    Write-Item "Rated Speed"        ("{0} MHz" -f $m.Speed)
    Write-Item "Configured Speed"   ("{0} MHz" -f $m.ConfiguredClockSpeed)
    Write-Item "Voltage"            ("{0} mV" -f $m.ConfiguredVoltage)
}

# ---------------------------------------------------------------
#  7. GRAPHICS
# ---------------------------------------------------------------
Write-Banner "7. GRAPHICS (GPU)"
$i = 0
foreach ($g in $gpus) {
    $i++
    Write-SubHeader "Graphics Adapter $i"
    Write-Item "Name"               $g.Name Green
    Write-Item "Manufacturer"       $g.AdapterCompatibility
    Write-Item "Video Processor"    $g.VideoProcessor
    Write-Item "Driver Version"     $g.DriverVersion
    Write-Item "Driver Date"        $g.DriverDate
    # AdapterRAM is capped at 4 GB in WMI (32-bit); show a note if so
    $vram = if ($g.AdapterRAM -ge 4GB - 1MB) { "4 GB or more (WMI limit)" } else { Format-Size $g.AdapterRAM }
    Write-Item "Video Memory"       $vram
    Write-Item "Resolution"         ("{0} x {1}" -f $g.CurrentHorizontalResolution, $g.CurrentVerticalResolution)
    Write-Item "Refresh Rate"       ("{0} Hz" -f $g.CurrentRefreshRate)
    Write-Item "Status"             $g.Status
    Write-Item "PNP Device ID"      $g.PNPDeviceID
}

# ---------------------------------------------------------------
#  8. MONITORS
# ---------------------------------------------------------------
Write-Banner "8. MONITORS / DISPLAYS"
if ($monitor) {
    $i = 0
    foreach ($mon in $monitor) {
        $i++
        Write-SubHeader "Monitor $i"
        Write-Item "Model Name"       (Convert-UShortArray $mon.UserFriendlyName) Green
        Write-Item "Manufacturer"     (Convert-UShortArray $mon.ManufacturerName)
        Write-Item "Product Code"     (Convert-UShortArray $mon.ProductCodeID)
        Write-Item "Serial Number"    (Convert-UShortArray $mon.SerialNumberID)
        Write-Item "Manufactured"     ("Week {0}, {1}" -f $mon.WeekOfManufacture, $mon.YearOfManufacture)
    }
} else {
    Write-Item "Monitors" "No monitor information available"
}

# ---------------------------------------------------------------
#  9. STORAGE
# ---------------------------------------------------------------
Write-Banner "9. STORAGE"
Write-SubHeader "Physical Drives"
$physDisks = Get-PhysicalDisk
$i = 0
foreach ($d in $disks | Sort-Object Index) {
    $i++
    $pd = $physDisks | Where-Object { $_.DeviceId -eq $d.Index }
    Write-Host ""
    Write-Host ("    Drive #{0}" -f $d.Index) -ForegroundColor Magenta
    Write-Item "Model"              $d.Model Green
    Write-Item "Serial Number"      ($d.SerialNumber -replace '\s','') Green
    Write-Item "Capacity"           (Format-Size $d.Size)
    Write-Item "Media Type"         $(if ($pd) { $pd.MediaType } else { 'N/A' })
    Write-Item "Bus Type"           $(if ($pd) { $pd.BusType } else { $d.InterfaceType })
    Write-Item "Firmware Version"   $d.FirmwareRevision
    Write-Item "Partitions"         $d.Partitions
    Write-Item "Health Status"      $(if ($pd) { $pd.HealthStatus } else { $d.Status }) $(if ($pd -and $pd.HealthStatus -ne 'Healthy') {'Red'} else {'Green'})
}

Write-SubHeader "Logical Volumes"
foreach ($v in $vols) {
    $usedPct = if ($v.Size) { [math]::Round((($v.Size - $v.FreeSpace) / $v.Size) * 100, 1) } else { 0 }
    Write-Host ""
    Write-Host ("    Drive {0}  {1}" -f $v.DeviceID, $v.VolumeName) -ForegroundColor Magenta
    Write-Item "File System"        $v.FileSystem
    Write-Item "Volume Serial"      $v.VolumeSerialNumber
    Write-Item "Total Size"         (Format-Size $v.Size)
    Write-Item "Free Space"         (Format-Size $v.FreeSpace)
    $c = if ($usedPct -ge 90) {'Red'} elseif ($usedPct -ge 75) {'Yellow'} else {'Green'}
    Write-Item "Usage"              ("{0}%  {1}" -f $usedPct, (Get-UsageBar $usedPct)) $c
}

# ---------------------------------------------------------------
#  10. NETWORK
# ---------------------------------------------------------------
Write-Banner "10. NETWORK ADAPTERS"
foreach ($n in $nics) {
    $cfg = $nicCfg | Where-Object { $_.Index -eq $n.Index }
    Write-SubHeader $n.Name
    Write-Item "Connection Name"    $n.NetConnectionID
    Write-Item "Manufacturer"       $n.Manufacturer
    Write-Item "MAC Address"        $n.MACAddress Green
    $speed = if ($n.Speed) { "{0} Mbps" -f [math]::Round($n.Speed / 1e6) } else { 'N/A' }
    Write-Item "Link Speed"         $speed
    $st = switch ($n.NetConnectionStatus) {0{'Disconnected'}1{'Connecting'}2{'Connected'}7{'Media Disconnected'} default{$n.NetConnectionStatus}}
    Write-Item "Status"             $st $(if ($st -eq 'Connected') {'Green'} else {'DarkGray'})
    if ($cfg) {
        Write-Item "IPv4 Address"   (($cfg.IPAddress | Where-Object { $_ -match '^\d+\.' }) -join ', ')
        Write-Item "IPv6 Address"   (($cfg.IPAddress | Where-Object { $_ -match ':' }) -join ', ')
        Write-Item "Subnet Mask"    ($cfg.IPSubnet | Select-Object -First 1)
        Write-Item "Default Gateway" ($cfg.DefaultIPGateway -join ', ')
        Write-Item "DNS Servers"    ($cfg.DNSServerSearchOrder -join ', ')
        Write-Item "DHCP Enabled"   $cfg.DHCPEnabled
        Write-Item "DHCP Server"    $cfg.DHCPServer
    }
}

# ---------------------------------------------------------------
#  11. AUDIO
# ---------------------------------------------------------------
Write-Banner "11. AUDIO DEVICES"
foreach ($s in $sound) {
    Write-Item $s.Name ("{0}  [{1}]" -f $s.Manufacturer, $s.Status)
}

# ---------------------------------------------------------------
#  12. BATTERY
# ---------------------------------------------------------------
Write-Banner "12. BATTERY / POWER"
if ($battery) {
    foreach ($b in $battery) {
        $c = if ($b.EstimatedChargeRemaining -le 20) {'Red'} elseif ($b.EstimatedChargeRemaining -le 50) {'Yellow'} else {'Green'}
        Write-Item "Name"             $b.Name
        Write-Item "Charge"           ("{0}%  {1}" -f $b.EstimatedChargeRemaining, (Get-UsageBar $b.EstimatedChargeRemaining)) $c
        Write-Item "Status"           $(switch ($b.BatteryStatus) {1{'Discharging'}2{'AC Power'}3{'Fully Charged'}4{'Low'}5{'Critical'}6{'Charging'} default{$b.BatteryStatus}})
        Write-Item "Chemistry"        $(switch ($b.Chemistry) {1{'Other'}2{'Unknown'}3{'Lead Acid'}4{'Nickel Cadmium'}5{'Nickel Metal Hydride'}6{'Lithium-ion'}8{'Lithium Polymer'} default{$b.Chemistry}})
        Write-Item "Design Voltage"   ("{0} mV" -f $b.DesignVoltage)
    }
} else {
    Write-Item "Battery" "No battery detected (Desktop PC)"
}

# ---------------------------------------------------------------
#  13. INPUT DEVICES
# ---------------------------------------------------------------
Write-Banner "13. INPUT DEVICES"
foreach ($k in $kbd)   { Write-Item "Keyboard" $k.Description }
foreach ($m in $mouse) { Write-Item "Pointing Device" $m.Name }

# ---------------------------------------------------------------
#  14. USB DEVICES
# ---------------------------------------------------------------
Write-Banner "14. CONNECTED USB DEVICES"
$usb = Get-PnpDevice -PresentOnly -Class USB, HIDClass, Camera, Image, Bluetooth |
       Where-Object { $_.FriendlyName } | Sort-Object FriendlyName -Unique
foreach ($u in $usb) { Write-Item $u.Class $u.FriendlyName }

# ---------------------------------------------------------------
#  Footer / Export
# ---------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 78) -ForegroundColor DarkCyan
Write-Host "  Report complete." -ForegroundColor Green
Write-Host ("=" * 78) -ForegroundColor DarkCyan

if ($Export) {
    $file = Join-Path ([Environment]::GetFolderPath('Desktop')) ("HardwareReport_{0}_{1}.txt" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $script:Report.ToString() | Out-File -FilePath $file -Encoding UTF8
    Write-Host "  Saved to: $file" -ForegroundColor Cyan
}
Write-Host ""
