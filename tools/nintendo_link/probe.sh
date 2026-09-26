#!/system/bin/sh
# Nintendo Link Bridge, test 1 (docs/NINTENDO_LINK_ANDROID_PORT.md): what the
# phone's Wi-Fi driver offers.  READ-ONLY: it changes no setting, interface
# or Wi-Fi state.  Needs root.
#
#   From a computer (wireless debugging paired and connected):
#     adb push tools/nintendo_link/probe.sh /data/local/tmp/
#     adb shell su -c 'sh /data/local/tmp/probe.sh' > probe.txt
#   On the phone (Termux, rooted):
#     su -c 'sh probe.sh' > probe.txt
# Then send probe.txt back.  For the nl80211 capability list install `iw`
# first (Termux: pkg install root-repo && pkg install iw) or put a static
# arm64 iw in /data/local/tmp/iw.

section() { echo; echo "===== $1"; }

section "device"
getprop ro.product.device; getprop ro.product.model
getprop ro.build.fingerprint; uname -a
id; getenforce 2>/dev/null

section "wifi modules"
lsmod 2>/dev/null | grep -i -E "bcmdhd|dhd|wonder|cfg80211|wlan" || cat /proc/modules | grep -i -E "bcmdhd|dhd|wonder"
ls /vendor/lib/modules 2>/dev/null | grep -i -E "bcmdhd|dhd|wonder|wlan"
ls /vendor_dlkm/lib/modules 2>/dev/null | grep -i -E "bcmdhd|dhd|wonder|wlan"

section "driver parameters"
for d in /sys/module/bcmdhd*; do
  [ -d "$d/parameters" ] || continue
  echo "$d"
  for p in dhd_use_idsup firmware_path nvram_path op_mode; do
    [ -r "$d/parameters/$p" ] && echo "  $p = $(cat "$d/parameters/$p" 2>/dev/null)"
  done
done

section "firmware files"
ls -la /vendor/firmware 2>/dev/null | grep -i -E "fw_bcm|bcm4390|clm|nvram|\.bin" | head -20

section "interfaces"
ls /sys/class/net; ls /sys/class/ieee80211 2>/dev/null
ip -brief link 2>/dev/null || ip link
for i in /sys/class/net/*; do
  [ -d "$i/wireless" ] || [ -d "$i/phy80211" ] && echo "wireless: $(basename "$i") type=$(cat "$i/type") addr=$(cat "$i/address")"
done

section "iw"
IW=$(command -v iw || ls /data/local/tmp/iw 2>/dev/null || ls /data/data/com.termux/files/usr/bin/iw 2>/dev/null)
if [ -n "$IW" ]; then
  "$IW" dev
  "$IW" list | sed -n '/Supported interface modes/,/software interface modes/p'
  echo "--- supported commands"
  "$IW" list | sed -n '/Supported commands/,/WoWLAN\|Supported TX frame types/p'
  echo "--- frame types"
  "$IW" list | sed -n '/Supported TX frame types/,/Supported RX frame types/p' | head -40
  "$IW" list | grep -i -E "ext_feature|control_port|4way|monitor" | head -40
else
  echo "iw not found (see the note at the top)"
fi

section "dmesg (driver lines, needs root)"
dmesg 2>/dev/null | grep -i -E "4-way handshake mode|dhd_use_idsup|monitor|wonder|bcm4390|Firmware version|FW version|CLM" | tail -40

section "wondertap / wonder interface"
ls /sys/class/net | grep -i wonder || echo "no wonder* interface right now"
grep -l -i wonder /vendor/etc/init/*.rc 2>/dev/null

echo; echo "done"
