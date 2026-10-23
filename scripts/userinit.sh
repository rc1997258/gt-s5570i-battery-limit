#!/system/bin/sh
# Run by CM11's /system/etc/init.d/90userinit at every boot.
# Starts the background scripts so boot isn't held up.
/system/bin/sh /data/local/dualstorage.sh > /dev/null 2>&1 &
/system/bin/sh /data/local/battery_limit.sh > /dev/null 2>&1 &
