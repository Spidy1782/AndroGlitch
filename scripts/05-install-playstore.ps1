# Step 5 - install the Google Play Store as a PRIVILEGED PRODUCT system app.
#
# The Play Store (Phonesky) is Google's proprietary APK - it is NOT shipped in
# this repo. We extract it, at setup time, from Google's own Play system image
# (no third-party mirror). Nothing Google-owned is redistributed.
#
# Two hard-won fixes make it stay working across its own auto-updates:
#   * install to /product/priv-app (matches its package record + GMS layout) so
#     it keeps the PRIVILEGED flag and can hold MANAGE_USERS (else it crashes),
#   * remove the fake /product/app/LicenseChecker vending stub, whose
#     non-privileged record was being inherited by /data updates -> crash.
# See docs\SETUP-NOTES.md "Task 8" for the full diagnosis.
. "$PSScriptRoot\..\config.ps1"

$assets = "$SecLabRoot\assets"
$apk = "$assets\playstore.apk"

# --- 1. get Phonesky.apk (skip if the user already supplied one) ------------
if (-not (Test-Path $apk)) {
    Say "extracting Phonesky from $PlayImage ..."
    $imgDir = "$Sdk\" + ($PlayImage -replace ';', '\')
    if (-not (Test-Path "$imgDir\system.img")) {
        Say "installing the Play system image (one-time, ~1.5 GB)..."
        & $Sdkmanager --install $PlayImage
    }
    $tmpAvd = 'AndroGlitchExtract'
    'no' | & $Avdmanager create avd -n $tmpAvd -k $PlayImage -d $DeviceDef --force | Out-Null
    Say "booting throwaway AVD to pull the APK (headless, ~1-2 min)..."
    Start-Process -FilePath $Emu -ArgumentList @("-avd",$tmpAvd,"-no-window","-no-snapshot","-no-audio") -WindowStyle Hidden
    # find the throwaway serial (the one that is NOT $AvdName)
    $ex = $null
    for ($i=0; $i -lt 60 -and -not $ex; $i++) {
        $devs = (& $Adb devices) | Select-String '^(emulator-\d+)\s+device' | ForEach-Object { $_.Matches[0].Groups[1].Value }
        foreach ($d in $devs) { if ((& $Adb -s $d emu avd name 2>$null | Select-Object -First 1) -eq $tmpAvd) { $ex = $d } }
        Start-Sleep 3
    }
    if (-not $ex) { throw "throwaway AVD did not boot" }
    [void](Wait-Boot $ex)
    $m = & $Adb -s $ex shell 'pm path com.android.vending' 2>$null | Select-String 'package:(.+Phonesky.apk)'
    $remote = if ($m) { $m.Matches[0].Groups[1].Value.Trim() } else { '/product/priv-app/Phonesky/Phonesky.apk' }
    & $Adb -s $ex pull $remote $apk | Out-Null
    & $Adb -s $ex emu kill 2>$null | Out-Null
    Start-Sleep 3
    & $Avdmanager delete avd -n $tmpAvd 2>$null | Out-Null
    if (-not (Test-Path $apk)) { throw "failed to pull Phonesky.apk" }
    Ok "extracted playstore.apk ($([math]::Round((Get-Item $apk).Length/1MB)) MB)"
} else {
    Ok "using supplied assets\playstore.apk"
}

# --- 2. install into SecLab12 ----------------------------------------------
$serial = Get-SecLabSerial
if (-not $serial) { throw "$AvdName not running - launch it first (launch\start-seclab.bat)." }
& $Adb -s $serial root 2>$null | Out-Null; Start-Sleep 2
& $Adb -s $serial remount 2>$null | Out-Null

& $Adb -s $serial push $apk /data/local/tmp/Phonesky.apk | Out-Null
& $Adb -s $serial push "$SecLabRoot\privapp-permissions-vending.xml" /data/local/tmp/privapp-permissions-vending.xml | Out-Null
& $Adb -s $serial push "$SecLabRoot\scripts\device\install-playstore.sh" /data/local/tmp/ | Out-Null
& $Adb -s $serial shell "su -c 'sh /data/local/tmp/install-playstore.sh'"

Say "rebooting so the package manager re-scans the system partition..."
& $Adb -s $serial reboot
[void](Wait-Boot $serial 120)
$flags = (& $Adb -s $serial shell 'dumpsys package com.android.vending' 2>$null | Select-String 'pkgFlags|codePath' | Select-Object -First 2)
Ok "Play Store installed. $($flags -join '  ')"
Warn "Keep the Burp proxy OFF when using the Play Store (it pins certs): adb shell settings put global http_proxy :0"
