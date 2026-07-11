# Step 6 - install a custom boot animation (optional; the AndroGlitch look).
#
# Drop a logo image at assets\boot.png (or a folder of numbered frames at
# assets\boot-frames\). If neither exists this step is skipped. Requires
# Python + Pillow (pip install pillow).
#
# Android searches oem -> product -> system for bootanimation.zip, so we install
# to BOTH /product/media and /system/media (the stock Google dots live in
# /product/media and would otherwise win).
. "$PSScriptRoot\..\config.ps1"

$assets = "$SecLabRoot\assets"
$asset = @("$assets\boot-frames","$assets\boot.png","$assets\boot.jpg") |
         Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $asset) { Warn "No assets\boot.png (or boot-frames\) - skipping boot animation."; return }

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
if (-not $py) { throw "Python not found (needed to build the STORED zip)." }

# device resolution -> desc.txt geometry
$serial = Get-SecLabSerial
if (-not $serial) { throw "$AvdName not running - launch it first." }
$size = (& $Adb -s $serial shell wm size 2>$null | Select-String 'Physical size:\s*(\d+)x(\d+)')
$w = 1080; $h = 2340
if ($size) { $w = $size.Matches.Groups[1].Value; $h = $size.Matches.Groups[2].Value }

$zip = "$assets\bootanimation.zip"
Say "building bootanimation.zip ($w x $h)..."
& $py.Source "$SecLabRoot\scripts\make-bootanim.py" --asset $asset --out $zip --width $w --height $h
if (-not (Test-Path $zip)) { throw "make-bootanim.py did not produce $zip" }

& $Adb -s $serial root 2>$null | Out-Null; Start-Sleep 2
& $Adb -s $serial remount 2>$null | Out-Null
& $Adb -s $serial push "$SecLabRoot\scripts\device\install-bootanim.sh" /data/local/tmp/ | Out-Null
& $Adb -s $serial push $zip /data/local/tmp/bootanimation.zip | Out-Null
& $Adb -s $serial shell "su -c 'sh /data/local/tmp/install-bootanim.sh'"
Ok "boot animation installed (plays on the next cold boot: launch\start-seclab.bat)."
