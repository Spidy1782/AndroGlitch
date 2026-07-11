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

## Setup (Windows) — step by step

The whole lab is built by **one command**. Just install a few tools first,
clone the repo, and run the setup script. Total time ≈ 15–30 min (mostly
automatic downloads). You do **not** need to be an Android expert.

### Step 1 — Install these once

| Tool | Why | Get it |
|---|---|---|
| **Android Studio** | provides the emulator + `adb`/`emulator`/`sdkmanager` (auto-detected) | <https://developer.android.com/studio> |
| **SDK Command-line Tools** | needed to create the emulator | In Android Studio: **More Actions → SDK Manager → SDK Tools tab → tick "Android SDK Command-line Tools (latest)" → Apply** |
| **Git for Windows** | `git` to clone + `openssl` to install the Burp CA | <https://git-scm.com/download/win> |
| **Python 3** | builds frida + boot animation | <https://www.python.org/downloads/> (tick *"Add to PATH"*) |

Then open **PowerShell** and install the Python helpers:

```powershell
pip install frida-tools pillow
```

> That's everything. The scripts auto-detect where your SDK and Java live —
> no environment variables to set by hand.

### Step 2 — Get the project

```powershell
git clone https://github.com/RedGlitchX/AndroGlitch.git
cd AndroGlitch
```

### Step 3 (optional) — Drop in your own files

Skip this if you just want the emulator running; you can always add them later.

- **Intercept HTTPS in Burp?** Export your Burp CA and save it as
  `assets\burp.der`.
  *(Burp → Proxy → Proxy settings → Import/export CA certificate →
  "Certificate in DER format".)*
- **Want a custom boot logo?** Put any image at `assets\boot.png`.

### Step 4 — Build the whole lab (one command)

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

Sit back — it installs the Android 12 image, creates the emulator, roots it,
installs the Play Store and Frida, and puts an **AndroGlitch** shortcut on your
desktop. When it finishes, **double-click the AndroGlitch desktop icon** to
start the lab.

That's it. ✅

---

### What the one command actually does

`setup.ps1` runs these 8 steps automatically (each is safe to re-run):

| # | Step | What it does |
|---|---|---|
| 1 | install-sdk-image | API-31 **google_apis** x86_64 image (rootable; not google_play) |
| 2 | create-avd | creates the `SecLab12` emulator |
| 3 | root-avd | rootAVD → Magisk; grants adb-shell root automatically |
| 4 | install-burp-ca | hashes `assets\burp.der` and installs it as a **system** CA |
| 5 | install-playstore | extracts the Play Store from a Google image, installs it **privileged** + applies the crash fixes |
| 6 | boot-animation | builds a boot animation from `assets\boot.png` (skipped if none) |
| 7 | install-frida | downloads `frida-server` matching your client and pushes it |
| 8 | desktop-shortcut | creates the hidden **AndroGlitch** desktop launcher |

Need to redo just part of it later?

```powershell
.\setup.ps1 -Only 5        # reinstall just the Play Store
.\setup.ps1 -From 4        # resume from step 4 onward
.\setup.ps1 -SkipRoot      # skip rooting (already rooted)
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

- **"Java version 17 or higher is required" / "AVD creation failed" at step 2**
  → `avdmanager`'s version check mis-fires on JDK 20+. The current scripts set
  the official override automatically; if you're on an older copy, run
  `$env:SKIP_JDK_VERSION_CHECK = 1` then re-run `.\setup.ps1`.
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

## Contributing

Issues and PRs welcome. This lab is for **authorized** mobile-app security testing only.
