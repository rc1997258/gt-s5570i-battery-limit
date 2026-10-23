# How charging is controlled

## The kernel driver

The GT-S5570I's charger is the **MAX8986** PMIC, handled by `drivers/power/max8986-power.c` in the CM11 kernel for BCM21553 devices (`tassve` is the GT-S5570I).

## Why the usual battery files don't work

The driver exposes many writable-looking files under:

```
/sys/devices/platform/i2cbcm.0/i2c-0/0-0008/max8986-power/power_supply/battery/
```

These include `isFullcharged`, `EOC`, `reCharge`, `timerExpire`, `batt_temp` and more. They're Samsung factory-test attributes, and **in this kernel their write handler is entirely disabled** (`#if 0`). Every write:

1. does nothing, and
2. reports that 0 bytes were written.

`echo` then retries forever, which looks like the phone or shell "hanging." There is no i2c deadlock; these files simply can't control charging. **Don't write to them.**

There is also no standard `charging_enabled` file on this kernel.

## What does work: the driver's debug interface

The driver's one module parameter is a small command interface:

```
/sys/module/max8986_power/parameters/debug
```

| Command | Effect |
|---|---|
| `c stop` | Calls `pmu_stop_charging()`: charger disabled (`MBCCTRL2 = 0`) |
| `c start <N>` | Calls `pmu_start_charging()`, then sets charging current `<N>` |
| `b volt` / `b temp` | Prints raw ADC values to `dmesg` |
| anything else, or reading it | Prints usage to `dmesg` |

`pmu_start_charging()` first sets the normal current for the connected charger type. A **valid** `<N>` (16–31) then overrides it. An **invalid** value, such as `99`, is rejected with `fc charging current param INVALID`, so the default current stays. The scripts use `c start 19` (350 mA).

Verified on the device:

```
pmu_stop_charging
Charging current: 99
pmu_start_charging: charger_type:3
max8986_get_charging_current:cc = 21,supply_type = 2
max8986_set_fc_current: fc charging current param INVALID
```

## Why `battery_limit.sh` re-sends `c stop` every minute

The driver can turn charging back on by itself:

- when the charger is replugged,
- through its 5-hour charge timer, which alternates 90 minutes on and 30 seconds off after expiry,
- through low-battery recovery.

So while the level is at or above `HIGH` (or the battery is too warm), the script re-sends `c stop` every cycle. The command is harmless to repeat.

## Wake lock

While a charger is connected, the script holds a wake lock (`/sys/power/wake_lock`) so its checks keep running when the screen is off. With no charger connected, the phone sleeps normally.

## Battery percentage

This driver estimates charge from battery voltage, and voltage reads higher while charging. The percentage can therefore drop a few points as soon as charging stops; the 10-point window absorbs that.
