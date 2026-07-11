# AndroGlitch — Rooted Android 12 Security-Testing Lab

A one-command build of a **rooted, Burp-ready Android 12 emulator** for
authorized mobile-app security testing. It scripts every step that is normally
hours of fiddly manual work:

- ✅ **Root** — Magisk via rootAVD (`adb shell su -c id` → `uid=0`)
- ✅ **System-trusted proxy CA** — your Burp CA injected into the Android 12
  system store, so HTTPS is intercepted with **no TLS warning**
- ✅ **Google Play Store** — installed as a privileged system app that **stays
  working across its own auto-updates** (the two crashes everyone hits are
  pre-fixed)
- ✅ **Frida** — `frida-server` matched to your host client, auto-started as
  root on every boot (`frida-ps -U` just works)
- ✅ **Custom boot animation** (optional) + a **windowless desktop launcher**

> ⚠️ **Authorized testing only.** This lab is for assessing apps you own or are
> explicitly permitted to test. A rooted device with a system-trusted MITM CA
> is powerful — use it responsibly and legally.

---

## Quick start (Windows)

**Prerequisites** (installed once):
- Android Studio + Android SDK (gives you `adb`, `emulator`, `sdkmanager`,
  `avdmanager` — the scripts auto-detect the SDK location)
- **Android SDK Command-line Tools (latest)** — Android Studio → SDK Manager →
  SDK Tools → tick it
- A JDK (Android Studio's bundled JBR is auto-detected)
- [Git for Windows](https://git-scm.com/download/win) — provides `git` **and**
  the `openssl` used to hash your CA
- Python 3 + `pip install pillow frida-tools` (frida client on the host; Pillow
  only if you want a custom boot animation)

**Build it:**

```powershell
git clone https://github.com/<you>/AndroGlitch.git
cd AndroGlitch

# (optional) export your Burp CA to assets\burp.der   — Burp: Proxy settings >
#   Import/export CA certificate > "Certificate in DER format"
# (optional) drop a logo at assets\boot.png for the boot animation

powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

`setup.ps1` runs 8 idempotent steps end-to-end (~15–30 min, mostly downloads):

| # | Step | What it does |
|---|---|---|
| 1 | install-sdk-image | API-31 **google_apis** x86_64 image (rootable; not google_play) |
| 2 | create-avd | creates the `SecLab12` AVD |
| 3 | root-avd | rootAVD → Magisk; grants adb-shell root headlessly |
| 4 | install-burp-ca | hashes `assets\burp.der` and installs it as a **system** CA |
| 5 | install-playstore | extracts Phonesky from a Google image, installs it **privileged** + applies the crash fixes |
| 6 | boot-animation | builds a STORED `bootanimation.zip` from `assets\boot.png` (optional) |
| 7 | install-frida | downloads `frida-server` matching your client, pushes it |
| 8 | desktop-shortcut | hidden **AndroGlitch** launcher on your desktop |

Re-run any subset:

```powershell
.\setup.ps1 -Only 5        # reinstall just the Play Store
.\setup.ps1 -From 4        # resume from the Burp-CA step
.\setup.ps1 -SkipRoot      # already rooted
```

## Launching

Double-click the **AndroGlitch** desktop shortcut, or run `launch\start-seclab.bat`.

> **Always launch this way — not Android Studio's ▶ button.** The Burp CA, Play
> Store, and boot animation live in the AVD's *writable-system overlay*, which
> only mounts with `-writable-system` (the play button omits it). The launcher
> also cold-boots (so the animation plays) and auto-starts `frida-server` as
> root after boot.

## Verify

```powershell
. .\env.ps1                       # loads the toolchain + pins ANDROID_SERIAL
adb shell su -c id                # -> uid=0(root)
frida-ps -U                       # lists device processes
# open the Play Store, sign in, install an app
```

Route a target app through Burp (listener on 8080, all interfaces):

```powershell
adb shell settings put global http_proxy 10.0.2.2:8080   # ON
adb shell settings put global http_proxy :0              # OFF
```

> **Burp proxy vs the Play Store are mutually exclusive.** Google apps pin their
> certs, so keep the proxy **OFF** for Play Store / sign-in and turn it **ON**
> only to intercept the target app under test.

## Customizing

Override defaults with environment variables before running `setup.ps1`
(see `config.ps1`): `SECLAB_AVD`, `SECLAB_IMAGE`, `SECLAB_DEVICE`,
`SECLAB_PLAY_IMAGE`, `SECLAB_FRIDA_VERSION`.

## Repo layout

```
setup.ps1          orchestrator            env.ps1     session helper (dot-source)
config.ps1         paths + autodetection   launch/     start / restart scripts
scripts/           numbered build steps    scripts/device/   pushed .sh helpers
assets/            your private inputs (git-ignored)
docs/SETUP-NOTES.md  full build log + every root-cause fix
```

## Troubleshooting

- **frida "need Gadget to attach on jailed Android"** → `frida-server` isn't
  running as root. Run `launch\restart-frida.bat`, then `frida-ps -U`.
- **Play Store crashes on open** → already fixed by step 5. If it recurs after a
  wipe, re-run `.\setup.ps1 -Only 5`.
- **Play Store "Try again" / Wi-Fi "!"** → the Burp proxy is on. `adb shell
  settings put global http_proxy :0`.
- **Everything vanished after an Android-Studio launch** → relaunch with
  `launch\start-seclab.bat` (needs `-writable-system`). The overlay persists;
  the play button just doesn't mount it.
- **Sign-in loops ("uncertified device")** → register the device's GSF ID at
  <https://www.google.com/android/uncertified> (read it with
  `python scripts\read-gsf-id.py <pulled gservices.db>`), wait a few minutes,
  retry.

See **`docs/SETUP-NOTES.md`** for the full diagnosis behind every fix.
