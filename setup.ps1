# ============================================================================
#  setup.ps1 - one-command build of the AndroGlitch Android-12 security lab.
#
#     powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
#  Runs the numbered steps in scripts\ in order. Each step is idempotent and can
#  also be run on its own. Use -From / -To to run a subset, or -Only for one.
#
#     .\setup.ps1 -From 4          # resume at the Burp-CA step
#     .\setup.ps1 -Only 5          # (re)install the Play Store only
#     .\setup.ps1 -SkipRoot        # skip step 3 (already rooted)
#
#  Steps:
#    1  install the API-31 google_apis x86_64 system image (sdkmanager)
#    2  create the SecLab12 AVD
#    3  root it with rootAVD/Magisk  (modifies the shared SDK ramdisk)
#    4  inject YOUR Burp CA into the system trust store   (assets\burp.der)
#    5  install the Google Play Store as a privileged system app
#    6  install a custom boot animation                    (assets\boot.png, optional)
#    7  stage frida-server on the device
#    8  create the hidden desktop launcher shortcut
# ============================================================================
param(
    [int]$From = 1,
    [int]$To   = 8,
    [int]$Only = 0,
    [switch]$SkipRoot
)
. "$PSScriptRoot\config.ps1"

$steps = @(
    @{ n = 1; name = 'install-sdk-image';  file = '01-install-sdk-image.ps1' },
    @{ n = 2; name = 'create-avd';         file = '02-create-avd.ps1' },
    @{ n = 3; name = 'root-avd';           file = '03-root-avd.ps1' },
    @{ n = 4; name = 'install-burp-ca';    file = '04-install-burp-ca.ps1' },
    @{ n = 5; name = 'install-playstore';  file = '05-install-playstore.ps1' },
    @{ n = 6; name = 'boot-animation';     file = '06-boot-animation.ps1' },
    @{ n = 7; name = 'install-frida';      file = '07-install-frida.ps1' },
    @{ n = 8; name = 'desktop-shortcut';   file = '08-desktop-shortcut.ps1' }
)
if ($Only -gt 0) { $From = $Only; $To = $Only }

Write-Host "`n=== AndroGlitch lab setup ===" -ForegroundColor Magenta
Write-Host "  SDK   : $Sdk"
Write-Host "  AVD   : $AvdName  ($DeviceDef, $SdkImage)"
Write-Host "  Steps : $From..$To`n"

foreach ($s in $steps) {
    if ($s.n -lt $From -or $s.n -gt $To) { continue }
    if ($s.n -eq 3 -and $SkipRoot) { Write-Host "--- step 3 root-avd  (skipped)`n" -ForegroundColor DarkGray; continue }
    Write-Host "--- step $($s.n)  $($s.name) ---" -ForegroundColor Magenta
    & "$SecLabRoot\scripts\$($s.file)"
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { throw "step $($s.n) ($($s.name)) failed (exit $LASTEXITCODE)" }
    Write-Host ""
}

Write-Host "=== done. Launch the lab with:  launch\start-seclab.bat ===" -ForegroundColor Green
Write-Host "    Verify:  adb shell su -c id   |   frida-ps -U   |   open Play Store"
