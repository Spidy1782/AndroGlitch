# Step 3 - root the AVD with rootAVD (patches the image ramdisk with Magisk).
#
# NOTE: rootAVD patches system-images\...\ramdisk.img IN PLACE, so it roots the
# shared image - every AVD built on this exact image becomes rooted. A .backup
# is left next to ramdisk.img. rootAVD needs a booted AVD to run the patch, so
# this step boots SecLab12 first.
. "$PSScriptRoot\..\config.ps1"

$rootAvdDir = "$SecLabRoot\rootAVD"
if (-not (Test-Path "$rootAvdDir\rootAVD.bat")) {
    Say "cloning rootAVD..."
    & git clone https://gitlab.com/newbit/rootAVD.git $rootAvdDir
    if (-not (Test-Path "$rootAvdDir\rootAVD.bat")) { throw "rootAVD clone failed (is git installed?)" }
}

# Already rooted? (boot writable, check su)
Say "checking current root state..."
Start-Process -FilePath $Emu -ArgumentList @("-avd",$AvdName,"-writable-system","-no-snapshot-load") -WindowStyle Hidden
$serial = $null
for ($i=0; $i -lt 40 -and -not $serial; $i++) { $serial = Get-SecLabSerial; Start-Sleep 3 }
if (-not $serial) { throw "emulator did not appear" }
[void](Wait-Boot $serial)
& $Adb -s $serial root 2>$null | Out-Null
Start-Sleep 2
$id = (& $Adb -s $serial shell su -c id 2>$null)
if ($id -match 'uid=0') {
    Ok "already rooted: $id"
} else {
    Say "not rooted yet - running rootAVD (the emulator will reboot a few times)..."
    $ramdisk = ($SdkImage -replace ';', '\') + '\ramdisk.img'
    Push-Location $rootAvdDir
    try { & cmd /c "rootAVD.bat $ramdisk" } finally { Pop-Location }
    Warn "rootAVD finished. If it left the emulator down, re-run this step; it will verify root."
}

# Grant the adb shell (uid 2000) root headlessly so `adb shell su -c` works.
$serial = Get-SecLabSerial
if ($serial) {
    & $Adb -s $serial root 2>$null | Out-Null; Start-Sleep 2
    & $Adb -s $serial push "$SecLabRoot\scripts\device\grant-shell-root.sh" /data/local/tmp/ | Out-Null
    & $Adb -s $serial shell "su -c 'sh /data/local/tmp/grant-shell-root.sh'" 2>$null | Out-Null
    $id = (& $Adb -s $serial shell su -c id 2>$null)
    if ($id -match 'uid=0') { Ok "root confirmed: $id" } else { Warn "shell su not confirmed yet: $id" }
}
