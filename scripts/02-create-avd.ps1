# Step 2 - create the SecLab12 AVD from the API-31 image.
. "$PSScriptRoot\..\config.ps1"

$existing = (& $Avdmanager list avd) | Select-String "Name:\s+$AvdName\b"
if ($existing) { Ok "AVD '$AvdName' already exists"; return }

Say "creating AVD '$AvdName' ($DeviceDef)..."
# 'no' answers avdmanager's "create a custom hardware profile?" prompt.
'no' | & $Avdmanager create avd -n $AvdName -k $SdkImage -d $DeviceDef --force
$existing = (& $Avdmanager list avd) | Select-String "Name:\s+$AvdName\b"
if (-not $existing) { throw "AVD creation failed" }
Ok "created AVD '$AvdName'"
