# GT-S5570I Battery Limit

Charge limiting, temperature protection and storage fixes for the **Samsung Galaxy Mini GT-S5570I** running **CyanogenMod 11 (Android 4.4.2)**, turning an old phone into an always-plugged-in wall display (here: a DIY solar battery bank / inverter monitor).

- Holds the battery between **40% and 50%** while plugged in
- Charges at a **reduced current (350 mA)** for less heat
- **Pauses charging above 40 °C**, resumes below 35 °C
- **On/off switch** to charge to 100% when you need to unplug
- **Battery Limit app** with colored buttons, so no terminal is needed
- **Storage fix** so internal storage and the SD card both work

> **Device:** GT-S5570I, codename `tassve` (Broadcom BCM21553, MAX8986 PMIC).
> Requires root (CM11's built-in superuser). Not tested on other devices.

---

## Repository layout

```
scripts/
  battery_limit.sh   Background charge limiter (started at boot)
  bl.sh              On/off switch and status for the limiter
  dualstorage.sh     Internal + external storage manager (started at boot)
  userinit.sh        CM11 boot hook that starts both background scripts
app/
  src/, res/,        Source of the Battery Limit app
  AndroidManifest.xml
  build.sh           Builds the APK on Ubuntu/Debian without Android Studio
release/
  BatteryLimit.apk   Prebuilt app
docs/
  HOW_IT_WORKS.md    How charging is controlled, and why the obvious ways fail
  TROUBLESHOOTING.md Diagnostic commands and fixes
  HISTORY.md         Timeline of the investigation
```

---

## Installation

### 1. Enable root for apps and ADB

Settings → Developer options → **Root access** → **Apps and ADB**.

### 2. Copy the scripts to the phone

From a PC (or Termux) with ADB connected:

```sh
adb push scripts/battery_limit.sh scripts/bl.sh scripts/dualstorage.sh scripts/userinit.sh /data/local/tmp/
adb shell
su
cd /data/local/tmp
cp battery_limit.sh bl.sh dualstorage.sh userinit.sh /data/local/
chmod 755 /data/local/battery_limit.sh /data/local/bl.sh /data/local/dualstorage.sh /data/local/userinit.sh
reboot
```

CM11 runs `/data/local/userinit.sh` at every boot (via `/system/etc/init.d/90userinit`), which starts both background scripts. **`/system` is never modified.**

If you edit the scripts on Windows, save them with **Unix (LF) line endings**.

### 3. Install the app

```sh
adb install release/BatteryLimit.apk
```

Or copy it to the SD card and open it with the file manager (enable Settings → Security → **Unknown sources** first). On first launch, tap **Allow** in the superuser prompt and choose to remember it.

---

## Usage

### App

| Button | Effect |
|---|---|
| **KEEP 40-50%** (green) | Limit on, hold between 40% and 50% |
| **CHARGE TO 100%** (orange) | Limit off, charge fully (temperature guard stays active) |
| **REFRESH** (blue) | Update status |

The status card turns green (limit on), orange (full-charge mode) or red (no root or script missing). Changes reach the charger within about a minute.

### Command line (optional)

```sh
su -c "sh /data/local/bl.sh off"   # charge to 100%
su -c "sh /data/local/bl.sh on"    # back to 40-50%
su -c "sh /data/local/bl.sh"       # show state, level and recent log
```

### Logs

```sh
cat /data/local/tmp/battery_limit.log
cat /data/local/tmp/dualstorage.log
```

---

## Settings

All at the top of `scripts/battery_limit.sh`:

| Variable | Default | Meaning |
|---|---|---|
| `HIGH` | `50` | Stop charging at this % |
| `LOW` | `40` | Resume charging at this % |
| `CURRENT` | `19` | Charging current code (see below) |
| `TEMP_STOP` | `400` | Pause charging at 40.0 °C (tenths of a degree) |
| `TEMP_RESUME` | `350` | Allow charging again below 35.0 °C |
| `INTERVAL` | `60` | Seconds between checks |

**Charging current codes** (MAX8986 `MBCCTRL4`): `16`=200 mA, `17`=250 mA, `18`=300 mA, `19`=350 mA, `20`=400 mA, `21`=450 mA (the driver's default for a wall charger).

**Tuning:** with the screen on, the phone uses roughly 150–250 mA. If the level barely rises while charging, raise `CURRENT` to `20` or `21`. If it cycles too often, widen the window (for example `LOW=35`).

---

## Storage

On this ROM, `/storage/sdcard0` is the **microSD slot** (`fstab`: `voldmanaged=sdcard0:auto,noemulatedsd`), not internal memory. Without a card, CM File Manager crashes on startup. `dualstorage.sh` makes the phone usable either way:

| Situation | `/storage/sdcard0` | `/storage/internal` |
|---|---|---|
| SD card inserted | SD card | Internal (`/data/media/0`, ~118 MB) |
| No SD card | Internal | Internal |

Internal storage is served by the ROM's own `sdcard` FUSE daemon, run in the `sdcardd` SELinux context, so app permissions work correctly.

**Recommendation:** keep a microSD card inserted. Android's storage settings only recognise the card slot, so some apps, including CM File Manager, need a real card.

---

## Physical setup for a wall display

- Keep the phone out of direct sun and away from the inverter's heat.
- Leave space behind it for airflow; take it out of any case.
- Use low screen brightness and a dark background.
- **Check the battery for swelling every few weeks.** If the back cover lifts, unplug the phone and replace the battery (EB494353VU).

---

## Uninstall

```sh
su
rm /data/local/userinit.sh /data/local/battery_limit.sh /data/local/bl.sh /data/local/dualstorage.sh /data/local/battery_limit.off
reboot
```

Then uninstall the Battery Limit app normally.

---

## Building the app

```sh
sudo apt install aapt android-sdk-platform-23 dalvik-exchange apksigner zipalign openjdk-17-jdk-headless
sh app/build.sh
```

The signing key (`app/key.jks`) is created on first build and is ignored by git. Keep a private copy: updates to an installed app must be signed with the same key.

---

## Warning

These scripts change how the phone charges its lithium-ion battery. They use the charger driver's own control interface and keep the battery cooler and at a lower charge than normal, but you use them at your own risk.

## License

MIT, see [LICENSE](LICENSE).
