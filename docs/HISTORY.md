# Investigation history

A record of how this project got where it is, including the wrong turns, so nobody has to repeat them.

## 1. First attempt: Samsung sysfs files

Writing `isFullcharged`, `EOC` and `reCharge` under the MAX8986 `power_supply/battery` folder was tried for a 55–60% limit. Every write "hung" the shell or phone, and forced reboots followed.

The original theory was an i2c bus deadlock. **That was wrong.** Reading the kernel source showed the write handler for all those files is disabled and returns 0, so `echo` retries forever. See [HOW_IT_WORKS.md](HOW_IT_WORKS.md).

Some suggestions in early notes also didn't apply to this phone: Magisk (it was never installed and isn't needed), Doze (it doesn't exist on Android 4.4), and `extundelete` (it doesn't work on yaffs2).

## 2. "Corrupted internal storage"

After the forced reboots, CM File Manager crashed and storage looked corrupted. The investigation found:

- `/data` was healthy (40% used), with no corruption.
- `/data/media/0` held only empty folders, created by earlier "fix" commands.
- On this ROM, **`sdcard0` is the microSD slot** (`noemulatedsd`), and the kernel reported that no card was present.
- The file manager crash came from `getExternalFilesDir()` returning an empty list, because Android had no mounted storage.

**Resolution:** `dualstorage.sh` serves internal storage at `/storage/internal`, and at `sdcard0` when no card is present. This needed the FUSE daemon to run in the `sdcardd` SELinux context, since SELinux is enforcing. CM File Manager still requires a real card, because Android only tracks the slot, and inserting a microSD card fixed it.

## 3. Working charge control

A read-only scan of `/sys` and the driver source found the `max8986_power` module's `debug` parameter, which provides `c stop` and `c start <N>`. Both were tested by hand and confirmed in `dmesg`.

## 4. Long-life settings for a solar wall display

The phone became a permanent, always-plugged wall display for a DIY solar battery bank and inverter. Settings were chosen for battery life:

- a 40–50% window,
- 350 mA charging current,
- a 40 °C temperature pause.

An on/off switch (`bl.sh`) and the Battery Limit app were added to allow occasional full charges.
