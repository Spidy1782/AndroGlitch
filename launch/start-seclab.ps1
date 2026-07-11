# ============================================================================
#  Launch AndroGlitch (SecLab12), then after full boot: adb root + start
#  frida-server as root. Normally run HIDDEN via start-seclab.vbs (the desktop
#  shortcut) so there is no console window to accidentally close. Progress ->
#  logs\launch.log.
#
#  -writable-system mounts the Burp CA / Play Store / boot animation overlay.
#  -no-snapshot-load cold-boots so the boot animation plays.
# ============================================================================
param([string[]]$ExtraArgs = @())
. "$PSScriptRoot\..\config.ps1"

$logDir = "$SecLabRoot\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = "$logDir\launch.log"
function Log($m) { Add-Content -Path $logFile -Value "$(Get-Date -Format 'HH:mm:ss')  $m" -Encoding utf8 }
Set-Content $logFile -Value "" -Encoding utf8

$emuArgs = @("-avd",$AvdName,"-writable-system","-no-snapshot-load") + $ExtraArgs
Log "Launching ${AvdName}: emulator $($emuArgs -join ' ')"
Start-Process -FilePath $Emu -ArgumentList $emuArgs -WindowStyle Hidden

Log "Waiting for boot..."
$serial = $null
for ($i=0; $i -lt 90; $i++) {
    if (-not $serial) { $serial = Get-SecLabSerial }
    if ($serial -and ((& $Adb -s $serial shell getprop sys.boot_completed 2>$null | Out-String).Trim() -eq '1')) { break }
    Start-Sleep -Seconds 3
}
if (-not $serial) { Log "[!] $AvdName did not appear. Aborting frida auto-start."; exit 1 }
Log "Booted: $serial"

& $Adb -s $serial root | Out-Null
Start-Sleep 2
& $Adb -s $serial wait-for-device

$bin = "$SecLabRoot\assets\frida-server"
$present = (& $Adb -s $serial shell "ls /data/local/tmp/frida-server 2>/dev/null" | Out-String).Trim()
if (-not $present) {
    if (Test-Path $bin) { Log "pushing frida-server..."; & $Adb -s $serial push $bin /data/local/tmp/frida-server | Out-Null }
    else { Log "[!] no frida-server present or in assets\ - run setup.ps1 -Only 7" }
}
& $Adb -s $serial shell chmod 755 /data/local/tmp/frida-server 2>$null
& $Adb -s $serial shell "su -c 'pkill -f frida-server' 2>/dev/null"
Start-Sleep 1
& $Adb -s $serial shell "su -c 'setsid /data/local/tmp/frida-server >/dev/null 2>&1 &'"
Start-Sleep 3

$procLine = (& $Adb -s $serial shell "ps -A -o USER,PID,NAME | grep frida" | Out-String).Trim()
if ($procLine) { Log "frida-server running: $procLine`r`nReady -> run 'frida-ps -U' from the host." }
else           { Log "[!] frida-server did not start. Run restart-frida.bat." }
