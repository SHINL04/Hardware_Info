# Hardware Info

A single-file PowerShell script that displays your computer's complete hardware and system configuration in a clean, color-coded, easy-to-read format. No installation and no third-party modules are needed.

```
==============================================================================
  4. MOTHERBOARD
==============================================================================
    Manufacturer            : ASUSTeK COMPUTER INC.
    Product / Model         : PRIME B450M-A
    Version                 : Rev X.0x
    Serial Number           : 190XXXXXXXXXXXX
    Asset Tag               : Default string
```

> Add a real screenshot here after you run it, for example `![Screenshot](screenshot.png)`.

## Features

The report is split into 14 sections:

| # | Section | Details shown |
|---|---------|---------------|
| 1 | Computer / System | Name, manufacturer, model, serial number, UUID, chassis type |
| 2 | Operating System | Version, build, architecture, install date, uptime, product ID |
| 3 | BIOS / Firmware | Vendor, version, release date, serial number, Secure Boot, TPM |
| 4 | Motherboard | Manufacturer, model, version, serial number |
| 5 | Processor | Name, cores, threads, speeds, cache, virtualization, live load |
| 6 | Memory (RAM) | Total, used, free, and per-slot manufacturer, part number, serial number, type, speed |
| 7 | Graphics (GPU) | Name, driver version and date, VRAM, resolution, refresh rate |
| 8 | Monitors | Model, manufacturer, serial number, manufacture date |
| 9 | Storage | Physical drives (model, serial number, SSD/HDD, health, firmware) and volume usage |
| 10 | Network | MAC, IP, gateway, DNS, DHCP, link speed |
| 11 | Audio | Sound devices |
| 12 | Battery / Power | Charge, status, chemistry |
| 13 | Input Devices | Keyboard and pointing devices |
| 14 | USB Devices | Connected USB, HID, camera and Bluetooth devices |

Other features:
- Color-coded output, with serial numbers and key values highlighted
- Usage bars for RAM, disk, CPU and battery, such as `[#########................]`
- Disk usage turns yellow or red when a drive is nearly full
- Optional export of the full report to a `.txt` file

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 (built in) or PowerShell 7+
- Administrator rights are optional but recommended, because some serial numbers and TPM data need them

## Usage

1. Download `HardwareInfo.ps1` (clone the repo or use **Code > Download ZIP**).
2. Open PowerShell. For best results, right-click it and choose **Run as administrator**.
3. Go to the folder that contains the script:

   ```powershell
   cd "C:\path\to\folder"
   ```

4. Run it:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\HardwareInfo.ps1
   ```

`-ExecutionPolicy Bypass` applies only to this one run. It does not change your system settings.

### Save the report to a text file

```powershell
powershell -ExecutionPolicy Bypass -File .\HardwareInfo.ps1 -Export
```

The report is saved to your Desktop as `HardwareReport_<COMPUTERNAME>_<date>.txt`.

### Tip: run it from a USB drive

Copy `HardwareInfo.ps1` to a USB drive. It can be run on any Windows PC with the same command, without installing anything.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `The argument ... to the -File parameter does not exist` | You are in the wrong folder. Use `dir` to check that the file is listed, or give the full path in quotes. |
| File is blocked after downloading | Run `Unblock-File .\HardwareInfo.ps1`, then try again. |
| Saved as `HardwareInfo.ps1.txt` | Rename it so it ends in `.ps1`. In Notepad, set "Save as type" to **All files**. |
| Some fields show `N/A` | The hardware or virtual machine does not report that value, or you need to run as Administrator. |
| VRAM shows "4 GB or more" | A Windows WMI limitation. It cannot report more than 4 GB of GPU memory. |
| Text looks cramped | Maximize the PowerShell window. |

## Privacy

This script only **reads** information from your computer and prints it to the screen. It does not connect to the internet or send data anywhere. If you use `-Export`, the report is saved locally. Note that reports contain serial numbers and MAC addresses, so remove them before sharing a report publicly.

## How it works

The script uses built-in Windows CIM/WMI classes such as `Win32_ComputerSystem`, `Win32_BIOS`, `Win32_Processor`, `Win32_PhysicalMemory`, `Win32_VideoController` and `Win32_DiskDrive`, plus `Get-PhysicalDisk` and `Get-PnpDevice`.

## Contributing

Issues and pull requests are welcome. Ideas for future improvements:
- HTML report export
- JSON / CSV export
- Installed software and driver lists
- Double-click `.bat` launcher

## License

Released under the [MIT License](LICENSE). Add a `LICENSE` file to your repository (GitHub can generate one for you when you create the repo).
