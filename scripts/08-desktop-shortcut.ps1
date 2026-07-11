# Step 8 - create a hidden desktop launcher shortcut.
# Target = wscript.exe launch\start-seclab.vbs, which runs the PowerShell
# launcher with NO console window (nothing to accidentally close that would
# kill the emulator). Only the emulator GUI appears.
. "$PSScriptRoot\..\config.ps1"

$vbs = "$SecLabRoot\launch\start-seclab.vbs"
if (-not (Test-Path $vbs)) { throw "missing $vbs" }

$desktop = [Environment]::GetFolderPath('Desktop')
$lnk = "$desktop\AndroGlitch.lnk"
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnk)
$sc.TargetPath = "$env:SystemRoot\System32\wscript.exe"
$sc.Arguments  = "`"$vbs`""
$sc.WorkingDirectory = "$SecLabRoot\launch"
$sc.IconLocation = "$Emu,0"
$sc.Description = "Launch the AndroGlitch Android-12 security lab (rooted, Burp CA, Play Store, frida)"
$sc.Save()
Ok "desktop shortcut created: $lnk"

# also a restart-frida shortcut
$rf = $ws.CreateShortcut("$desktop\AndroGlitch - Restart Frida.lnk")
$rf.TargetPath = "$SecLabRoot\launch\restart-frida.bat"
$rf.WorkingDirectory = "$SecLabRoot\launch"
$rf.Save()
Ok "desktop shortcut created: AndroGlitch - Restart Frida.lnk"
