# Step 1 - install the Android-12 (API 31) google_apis x86_64 system image.
# google_apis (NOT google_play): the google_apis image is rootable; the
# google_play image is not. GMS is present either way.
. "$PSScriptRoot\..\config.ps1"

$imgDir = "$Sdk\" + ($SdkImage -replace ';', '\')
if (Test-Path "$imgDir\ramdisk.img") {
    Ok "system image already installed: $SdkImage"
    return
}
Say "installing $SdkImage (this downloads ~1 GB)..."
& $Sdkmanager --install $SdkImage
if (-not (Test-Path "$imgDir\ramdisk.img")) { throw "image install failed; ramdisk.img not found under $imgDir" }
Ok "installed $SdkImage"
