#!/system/bin/sh
# battery_limit.sh - long-life charging for an always-plugged GT-S5570I (CM11, max8986)
#
# - Holds the battery between LOW% and HIGH%
# - Charges at a reduced current (less heat)
# - Pauses charging if the battery gets warm
#
# Uses the charger driver's own command interface:
#   echo "c stop"      > /sys/module/max8986_power/parameters/debug
#   echo "c start <N>" > /sys/module/max8986_power/parameters/debug
# Never writes to isFullcharged / EOC / reCharge.

HIGH=50          # stop charging at this %
LOW=40           # resume charging at this %

# Charging current code (MAX8986 MBCCTRL4):
#   16=200mA 17=250mA 18=300mA 19=350mA 20=400mA 21=450mA (wall charger default)
CURRENT=19

TEMP_STOP=400    # pause charging at 40.0 C (value is in tenths of a degree)
TEMP_RESUME=350  # allow charging again below 35.0 C

INTERVAL=60

# On/off switch: if this file exists, the 40-50% limit is OFF and the battery
# charges to 100%. The temperature guard stays active either way.
OFF=/data/local/battery_limit.off

CTL=/sys/module/max8986_power/parameters/debug
PSY=/sys/class/power_supply/max8986-battery
PIDF=/dev/.battery_limit.pid
LOG=/data/local/tmp/battery_limit.log
WL=battery_limit

log() { echo "$(date) $1" >> $LOG; }

if [ -f $PIDF ] && kill -0 $(cat $PIDF) 2>/dev/null; then
  exit 0
fi
echo $$ > $PIDF
echo -17 > /proc/$$/oom_adj 2>/dev/null

[ -f $LOG ] && mv $LOG $LOG.old
log "started: ${LOW}-${HIGH}%, current code $CURRENT, temp limit $TEMP_STOP"

holding=0       # level reached HIGH, waiting for LOW
hot=0           # battery too warm
stopped=0       # we have charging stopped
was_plugged=0
awake=0
limit_on=1

while true; do
  level=$(cat $PSY/capacity 2>/dev/null)
  status=$(cat $PSY/status 2>/dev/null)
  temp=$(cat $PSY/temp 2>/dev/null)
  [ -z "$temp" ] && temp=0

  # Read the on/off switch
  if [ -f $OFF ]; then
    if [ $limit_on = 1 ]; then
      limit_on=0; holding=0; was_plugged=0
      log "limit switched OFF: charging to 100%"
    fi
  elif [ $limit_on = 0 ]; then
    limit_on=1; was_plugged=0
    log "limit switched ON: ${LOW}-${HIGH}%"
  fi

  case "$status" in
    Discharging|Unknown|"") plugged=0 ;;
    *) plugged=1 ;;
  esac

  # Stay awake only while plugged in, so checks keep running
  if [ $plugged = 1 ] && [ $awake = 0 ]; then
    echo $WL > /sys/power/wake_lock 2>/dev/null && awake=1
  elif [ $plugged = 0 ] && [ $awake = 1 ]; then
    echo $WL > /sys/power/wake_unlock 2>/dev/null; awake=0
  fi

  if [ $plugged = 1 ] && [ -n "$level" ]; then
    # Temperature guard
    if [ $hot = 0 ] && [ "$temp" -ge $TEMP_STOP ]; then
      hot=1; log "battery ${temp} (tenths C) too warm: pausing"
    elif [ $hot = 1 ] && [ "$temp" -le $TEMP_RESUME ]; then
      hot=0; log "battery cooled to ${temp}"
    fi

    # Level window (only when the limit is ON)
    if [ $limit_on = 0 ]; then
      holding=0
    elif [ "$level" -ge $HIGH ]; then
      [ $holding = 0 ] && log "level $level% reached $HIGH%"
      holding=1
    elif [ $holding = 1 ] && [ "$level" -le $LOW ]; then
      holding=0; log "level $level% down to $LOW%"
    fi

    if [ $hot = 1 ] || [ $holding = 1 ]; then
      # Re-sent every cycle: driver timers or a re-plug can restart charging
      echo "c stop" > $CTL
      [ $stopped = 0 ] && log "charging stopped (level $level%, temp $temp)"
      stopped=1
    elif [ $stopped = 1 ] || [ $was_plugged = 0 ]; then
      # Resume, or charger just connected: charge at our reduced current
      echo "c start $CURRENT" > $CTL
      log "charging at current code $CURRENT (level $level%, temp $temp)"
      stopped=0
    fi
  elif [ $plugged = 0 ] && [ $was_plugged = 1 ]; then
    holding=0; hot=0; stopped=0
    log "charger removed (level $level%)"
  fi

  was_plugged=$plugged
  sleep $INTERVAL
done
