#!/system/bin/sh
# Nintendo Link Bridge, test 2 (docs/NINTENDO_LINK_ANDROID_PORT.md): can the
# phone's `wonder` radio hear a Switch hosting a local-wireless room.
#
# It only LISTENS.  It never associates, never transmits, never touches wlan0
# or your home Wi-Fi.  It puts the existing monitor interface (wondertap0) up,
# hops the three channels LDN uses (1, 6, 11), and counts the management
# frames whose vendor id is Nintendo's (00:22:aa).  A Switch sitting in
# FireRed/LeafGreen's Union Room, or any Switch game's local play, sends these.
#
# Run it with the Switch a metre away, in a local-wireless screen:
#   adb push tools/nintendo_link/listen.sh /data/local/tmp/
#   adb shell su -c 'sh /data/local/tmp/listen.sh 20'
# or in Termux (rooted):  su -c 'sh listen.sh 20'
# The argument is seconds per channel (default 15).  Needs tcpdump; Termux:
# pkg install tcpdump, or put a static arm64 tcpdump in /data/local/tmp.
#
# Nothing here changes a saved setting.  On exit it puts wondertap0 back down.

SECS="${1:-15}"
MON=wondertap0
NINTENDO_OUI="00:22:aa"

TCPDUMP=$(command -v tcpdump || ls /data/local/tmp/tcpdump 2>/dev/null || ls /data/data/com.termux/files/usr/bin/tcpdump 2>/dev/null)
IW=$(command -v iw || ls /data/local/tmp/iw 2>/dev/null || ls /data/data/com.termux/files/usr/bin/iw 2>/dev/null)

echo "== interface"
ip link show "$MON" 2>/dev/null || { echo "no $MON -- run probe.sh first"; exit 1; }

was_up=$(ip link show "$MON" | grep -c "state UP")
ip link set "$MON" up 2>&1 || { echo "could not bring $MON up (need root)"; exit 1; }

restore() {
  [ "$was_up" = "0" ] && ip link set "$MON" down 2>/dev/null
  echo "== $MON left as found"
}
trap restore EXIT INT TERM

echo "== listening $SECS s per channel on 1 / 6 / 11 (Nintendo OUI $NINTENDO_OUI)"
total=0
for ch in 1 6 11 ; do
  if [ -n "$IW" ]; then "$IW" dev "$MON" set channel "$ch" 2>/dev/null; fi
  echo "-- channel $ch"
  if [ -n "$TCPDUMP" ]; then
    # management + action frames; save a small pcap and count Nintendo vendor frames
    out="/data/local/tmp/ldn_ch${ch}.pcap"
    "$TCPDUMP" -i "$MON" -I -c 2000 -w "$out" -G "$SECS" -W 1 \
      'type mgt' >/dev/null 2>&1
    # count frames whose 802.11 vendor-specific element carries the Nintendo OUI
    n=$("$TCPDUMP" -r "$out" -nn -e 2>/dev/null | grep -ic "$NINTENDO_OUI")
    seen=$("$TCPDUMP" -r "$out" 2>/dev/null | wc -l)
    echo "   mgmt frames captured: $seen   Nintendo-OUI frames: $n   ($out)"
    total=$((total + n))
  else
    echo "   tcpdump not found -- see the note at the top"
  fi
done

echo
echo "== Nintendo-OUI management frames seen in total: $total"
if [ "$total" -gt 0 ]; then
  echo "PASS: the phone hears a Switch room on the wonder radio."
  echo "Keep the newest ldn_ch*.pcap; the room advertisement in it is what"
  echo "test 3 (join) uses -- its BSSID, channel and hidden SSID."
else
  echo "No Nintendo frames. Check: the Switch is in a local-wireless screen"
  echo "(Union Room / a game's local play), close by, and try again."
fi
