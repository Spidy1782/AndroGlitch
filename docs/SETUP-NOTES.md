# AndroGlitch — build notes & root-cause fixes

Why the lab is built the way it is. Every non-obvious decision here was paid for
with a failure. Read this when a step misbehaves or you want to adapt it.

## Image choice — google_apis, not google_play
`system-images;android-31;google_apis;x86_64` is **rootable**; the
`google_play` image is not. GMS is present in both. We add the Play Store
ourselves (step 5).

## Toolchain gotchas
- `sdkmanager` on **JDK 24** aborts with *"Java version 17 or higher is
  required"* (it mis-parses the version). Fix: `SKIP_JDK_VERSION_CHECK=1`
  (`env.ps1` sets it).
- `openssl` isn't on Windows by default — Git for Windows bundles it at
  `…\Git\usr\bin\openssl.exe` (auto-detected in `config.ps1`).
- `adb exec-out screencap -p > file` **corrupts the PNG** under PowerShell
  (UTF-16 redirection). Use `adb shell screencap -p /data/local/tmp/x.png`
  then `adb pull`.
- Device shell quoting mangles parens/pipes/SQL — put such commands in a pushed
  `.sh` file (that's why `scripts/device/` exists), not inline `adb shell`.

## Root (step 3)
rootAVD patches `system-images\…\ramdisk.img` **in place** (Magisk 26.4,
lz4_legacy, KEEPVERITY/KEEPFORCEENCRYPT) using a running AVD as the worker, and
leaves a `.backup`. Because it patches the shared image, every AVD on that exact
image becomes rooted. It provides `su` (patched ramdisk) — **not** Magisk
magic-mount (modules don't mount on this emulator; see below). Shell root for
uid 2000 is granted via `magisk --sqlite` so `adb shell su -c` needs no tap.

## Writable system (why the launcher matters)
`/system` and `/product` mods only mount with **`-writable-system`**. Android
Studio's ▶ button omits it → pristine system (no CA, no Play Store, no boot
anim; root still works — that's in the ramdisk). The overlay upper-dir lives in
userdata, so it **persists across launches** — even after an Android-Studio
launch in between — as long as you relaunch with `-writable-system`. Only a Wipe
Data / fresh AVD drops it (re-run `setup.ps1`). `-no-snapshot-load` cold-boots
so the boot animation actually plays.

### Why not a Magisk module?
Packaging the CA + Play Store + boot anim as a `/data/adb/modules` module so
they'd apply on every boot was tried and abandoned: on this rootAVD emulator
Magisk **magic-mount does not run** (`/system`,`/product` stay ro with no
overlay; module files never mount). `-writable-system` is the reliable path.

## Burp CA (step 4)
Android 12 ignores user-added CAs for most apps, so the CA must go in the
**system** store. Filename is the legacy subject hash:
`openssl x509 -subject_hash_old` → `<hash>.0`, placed in
`/system/etc/security/cacerts/` with mode 644 and SELinux context
`system_security_cacerts_file`. No reboot — each app's TLS stack reads the dir
on init, so newly-launched apps trust it. Verified end-to-end: Chrome shows a
padlock through Burp with no cert warning.

## Play Store (step 5) — the two crashes, and the durable fix
Phonesky is Google's proprietary APK; we extract it at setup from a Google Play
system image (a throwaway AVD, `adb pull` the readable APK) — no mirror, nothing
redistributed. Installing it naively crashes twice:

1. **`SecurityException: need MANAGE_USERS … to query users`** on open. Cause:
   the package was flagged `PRODUCT` but **not `PRIVILEGED`** because the APK was
   in `/system/priv-app` while its package record is tied to the product
   partition → partition mismatch drops PRIVILEGED, and a non-privileged app
   can't hold the signature|privileged `MANAGE_USERS`.
   Fix: install to **`/product/priv-app/Phonesky`** (matches the record + the
   GMS layout), allowlist in `/product/etc/permissions/`.
2. **Crash returns after it auto-updates** (to a `/data/app` split). Real root
   cause: the image ships a **fake `com.android.vending` stub** at
   `/product/app/LicenseChecker` (v1.8, non-privileged). That stub was the
   "disabled system package" base, so `/data` updates inherited *non-privileged*
   from it and crashed again.
   Fix: **remove the stub** (`rm -rf /product/app/LicenseChecker`) +
   `pm uninstall-system-updates com.android.vending`. Now the disabled-system
   base is the privileged Phonesky, so future updates inherit PRIVILEGED (like
   GMS). Durable.

Also set `ro.control_privapp_permissions` **enforce → log** in
`/vendor/build.prop` so the auto-updating Play Store's shifting privileged-perm
set is granted rather than denied (avoids a bootloop). All of this is in
`scripts/device/install-playstore.sh`.

3. **"Try again" / Wi-Fi "!"** after the crash fix = the **Burp proxy was on**.
   Play Store pins its certs, so MITM breaks its connection (and the
   captive-portal check → Wi-Fi "!"). `settings put global http_proxy :0`.
   Rule: proxy OFF for Play Store / any pinning Google app; ON only for the
   target app.

Sign-in that loops with "uncertified device" → register the GSF Android ID at
<https://www.google.com/android/uncertified> (read it with
`scripts/read-gsf-id.py`), wait a few minutes, retry.

## Boot animation (step 6)
`bootanimation.zip` **must be ZIP_STORED** (no compression) or it black-screens
— `make-bootanim.py` uses `zipfile.ZIP_STORED`. Android searches
oem → product → system, so the stock Google-dots zip in `/product/media`
**overrides** `/system/media`; we install to both. `desc.txt` geometry uses the
live `wm size`.

## Frida (step 7 / launcher)
The `frida-server` major/minor **must match the host `frida` client** — step 7
reads the client version and downloads the matching server. It must run **as
root** or Frida falls back to *jailed/gadget* mode (enumeration still works, but
`spawn` fails with *"need Gadget to attach on jailed Android"* — misleading).
`frida-server` does **not** survive a reboot, so the launcher restarts it as
root (`su -c 'setsid …'`) on every boot.

## Windowless launcher
`start-seclab.vbs` runs `start-seclab.ps1` with a hidden window; the PS1 starts
`emulator.exe` with `-WindowStyle Hidden` so its console is hidden while the
qemu device GUI still shows. Result: only the emulator window appears — no
cmd/PowerShell window to accidentally close (closing the console used to kill
the emulator).
