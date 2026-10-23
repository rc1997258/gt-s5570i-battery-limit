#!/system/bin/sh
# bl.sh - switch the battery limit on or off
#   sh /data/local/bl.sh off   -> charge to 100%
#   sh /data/local/bl.sh on    -> keep at 40-50%
#   sh /data/local/bl.sh       -> show current state
F=/data/local/battery_limit.off
case "$1" in
  off) touch $F; echo "Battery limit OFF: charging to 100% (within 1 minute)" ;;
  on)  rm -f $F; echo "Battery limit ON: holding 40-50% (within 1 minute)" ;;
  *)   if [ -f $F ]; then echo "Battery limit is OFF"; else echo "Battery limit is ON"; fi
       echo "Level: $(cat /sys/class/power_supply/max8986-battery/capacity)%  Status: $(cat /sys/class/power_supply/max8986-battery/status)"
       tail -n 3 /data/local/tmp/battery_limit.log ;;
esac
