# Troubleshooting

## Battery limit

**Check that it's running:**
```sh
su
cat /data/local/tmp/battery_limit.log
cat /sys/class/power_supply/max8986-battery/status
dmesg | grep pmu_stop_charging | tail -n 3
```

**Confirm the driver interface exists** (read-only):
```sh
cat /sys/module/max8986_power/parameters/debug
dmesg | tail -n 12        # should show "Usage: echo 'cmd string' > ..."
```

**Manual test with the charger connected:**
```sh
echo "c stop" > /sys/module/max8986_power/parameters/debug        # -> Not charging
echo "c start 19" > /sys/module/max8986_power/parameters/debug    # -> Charging
```

**The log says "charging stopped" but the status is still Charging:** SELinux may be blocking the write. Check:
```sh
grep -i -E "debug|max8986" /data/misc/audit/audit.log | tail -n 10
```

**The app shows a red card:** set Settings → Developer options → Root access to "Apps and ADB", check that `/data/local/bl.sh` exists, then reopen the app and allow the superuser prompt.

## Storage

**Is the SD card detected?**
```sh
vdc volume list            # 0 = no card, 1 = card not mounted, 4 = mounted, 7 = shared with PC
cat /proc/partitions       # a detected card appears as mmcblk0 / mmcblk0p1
dmesg | grep -i mmc        # "SD Card removed physically" = slot sees no card
```

**Is internal storage mounted?**
```sh
cat /data/local/tmp/dualstorage.log
grep -E "sdcard0|internal" /proc/mounts
ps -Z | grep sdcard        # should show u:r:sdcardd:s0
```

**CM File Manager crashes** with `ArrayIndexOutOfBoundsException: length=0` in `getExternalFilesDir`: Android reports no storage. Insert a microSD card, or use another file manager.

## Useful facts about this ROM

| Item | Value |
|---|---|
| `/system`, `/data`, `/cache` | yaffs2 on raw flash (`mtdblock8/10/9`) |
| `sdcard0` | microSD slot (`bcm_sdhc.3`), `noemulatedsd` |
| SELinux | Enforcing |
| Boot hook | `/system/etc/init.d/90userinit` runs `/data/local/userinit.sh` |
| `head` | BusyBox: use `head -n 60`, not `head -60` |
