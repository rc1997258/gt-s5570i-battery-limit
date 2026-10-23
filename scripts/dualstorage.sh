#!/system/bin/sh
# dualstorage.sh - internal + external storage for GT-S5570I (CM11 / Android 4.4)
#
# Internal (/data/media/0) is always available at /storage/internal.
# With an SD card:    /storage/sdcard0 = SD card (normal ROM behaviour)
# Without an SD card: /storage/sdcard0 = internal, so apps still have storage
# Card insert/remove is handled automatically (checked every 10 seconds).
#
# Does NOT touch any battery/charging files.

INT_SRC=/data/media/0
INT_MNT=/storage/internal
PRI=/storage/sdcard0
CARD_RAW=/mnt/media_rw/sdcard0
MARKER=.internal_storage
PIDF=/dev/.dualstorage.pid
DPID=/dev/.dualstorage.daemon.pid
LOG=/data/local/tmp/dualstorage.log

# SELinux context the ROM's own sdcard daemon runs in
SDCARD_CTX=u:r:sdcardd:s0
# Set to 1 ONLY if the log says the daemon could not get the sdcardd context.
# This switches SELinux to permissive (less secure, but makes storage work).
ALLOW_PERMISSIVE=0

log() { echo "$(date) $1" >> $LOG; }
mounted() { grep -q " $1 " /proc/mounts; }
daemon_alive() { [ -f $DPID ] && kill -0 $(cat $DPID) 2>/dev/null; }

do_umount() {
  umount $1 2>/dev/null || busybox umount -l $1 2>/dev/null
}

# Only one copy may run
if [ -f $PIDF ] && kill -0 $(cat $PIDF) 2>/dev/null; then
  exit 0
fi
echo $$ > $PIDF

# Protect this script (and the sdcard daemon it starts) from the low-memory killer
echo -17 > /proc/$$/oom_adj 2>/dev/null

# Fresh log each boot, keep the previous one
[ -f $LOG ] && mv $LOG $LOG.old
log "started (SELinux: $(getenforce))"

start_daemon() {
  if [ -x /system/bin/runcon ]; then
    /system/bin/runcon $SDCARD_CTX /system/bin/sdcard -u 1023 -g 1023 -d $INT_SRC $INT_MNT &
  else
    /system/bin/sdcard -u 1023 -g 1023 -d $INT_SRC $INT_MNT &
  fi
  echo $! > $DPID
  sleep 2

  ctx=$(cat /proc/$(cat $DPID)/attr/current 2>/dev/null)
  log "sdcard daemon pid $(cat $DPID), context: $ctx"

  case "$ctx" in
    *sdcardd*) ;;
    *)
      log "WARNING: daemon is not in sdcardd context, apps may fail to write"
      if [ "$ALLOW_PERMISSIVE" = "1" ]; then
        setenforce 0
        log "ALLOW_PERMISSIVE=1: SELinux set to permissive, restarting daemon"
        kill $(cat $DPID) 2>/dev/null
        sleep 1
        do_umount $INT_MNT
        /system/bin/sdcard -u 1023 -g 1023 -d $INT_SRC $INT_MNT &
        echo $! > $DPID
        sleep 2
      fi
      ;;
  esac
}

setup_internal() {
  mkdir -p $INT_SRC
  chown 1023:1023 /data/media $INT_SRC
  chmod 770 /data/media $INT_SRC
  chown -R 1023:1023 $INT_SRC 2>/dev/null
  [ -e $INT_SRC/$MARKER ] || touch $INT_SRC/$MARKER

  if [ ! -d $INT_MNT ]; then
    mount -o remount,rw /
    mkdir $INT_MNT
    chmod 700 $INT_MNT
    mount -o remount,ro /
  fi

  if ! mounted $INT_MNT; then
    start_daemon
    if mounted $INT_MNT; then
      log "internal mounted at $INT_MNT"
    else
      log "ERROR: could not mount internal at $INT_MNT"
    fi
  fi
}

setup_internal

while true; do
  # Restart internal storage if its daemon died (mount would be left dead)
  if mounted $INT_MNT && ! daemon_alive; then
    log "sdcard daemon died, restarting internal storage"
    mounted $CARD_RAW || do_umount $PRI
    do_umount $INT_MNT
  fi
  mounted $INT_MNT || setup_internal

  if mounted $CARD_RAW; then
    # SD card present: make sure the card, not internal, is on sdcard0
    if [ -e $PRI/$MARKER ]; then
      if umount $PRI; then
        log "card detected: sdcard0 handed back to SD card"
      else
        log "card detected but sdcard0 busy, retrying"
      fi
    fi
    if ! mounted $PRI; then
      start fuse_sdcard0
      log "started fuse_sdcard0 for SD card"
    fi
  else
    # No SD card: put internal on sdcard0
    if ! mounted $PRI && mounted $INT_MNT; then
      if mount -o bind $INT_MNT $PRI; then
        log "no card: internal mounted on sdcard0"
      else
        log "ERROR: bind to sdcard0 failed"
      fi
    fi
  fi

  sleep 10
done
