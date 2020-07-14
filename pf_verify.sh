#!/bin/sh

# verify integrity of base system files against known-good hashes
# checksum files can be downloaded from: {url}
# usage:
#   sh pf_verify.sh [checksum_filename]
#   without a filename, a checksum file will be generated for the running system

ts=$(date '+%Y%m%d_%H%M%S')
outfile=$HOME/pfv_${HOST}_${ts}.sha256
workfile=/tmp/pf_verify_tmp
pkginfo=/tmp/pkginfo_tmp
rm $workfile $outfile $pkginfo 2>/dev/null
pkg-static info pfSense-base >$pkginfo 2>/dev/null
if [ ! -e "$pkginfo" ]; then
  echo "error reading pfSense base version (pkg)"
  exit 1
fi
ver="$(awk -F': ' '/Version/ { print $2 }' $pkginfo)"
hw="$(echo '<?php include("config.inc"); $p = system_identify_specific_platform(); $d = $p['descr']; $o = (($d) ? $d : 'unknown'); echo $o; ?>' | /usr/local/bin/php -q)"
arch="$(awk -F': ' '/Architecture/ { print $2 }' $pkginfo) [$(freebsd-version)]"

if [ -n "$1" ]; then
  if [ -e "$1" ]; then
    file_ver=$(awk 'BEGIN{FS=": "} /^# version:/{gsub(/^[ ]+|[ ]+$/,"",$2); print $2}' "$1")
    file_hw=$(awk 'BEGIN{FS=": "} /^# hardware:/{gsub(/^[ ]+|[ ]+$/,"",$2); print $2}' "$1")
    file_arch=$(awk 'BEGIN{FS=": "} /^# architecture:/{gsub(/^[ ]+|[ ]+$/,"",$2); print $2}' "$1")
    if [ "$file_ver" != "$ver" ]; then
      echo "checksum file was generated on a different pfSense version"
      exit 1
    fi
    if [ "$file_hw" != "$hw" ]; then
      echo "checksum file was generated on different hardware"
      exit 1
    fi
    if [ "$file_arch" != "$arch" ]; then
      echo "checksum file was generated on a different OS architecture"
      exit 1
    fi
    shasum -c "$1" | grep -v ': OK$'
    [ $? -eq 0 ] || echo "all files passed integrity check"
    exit
  else
    echo "$1 not found"
    exit 1
  fi
fi

echo "this will take a few seconds..."

cat <<EOF >>$outfile
# pf_verify checksum file
# hostname:      ${HOST}
# generated on:  $(date)
# version:       $ver
# hardware:      $hw
# architecture:  $arch

EOF

# "special" dirs
echo "/etc/inc"
find /etc/inc -type f -name "*.inc" -exec shasum -a256 {} + >$workfile 2>/dev/null
echo "/boot"
find /boot -type f ! \( -name "*.conf" -or -name "*.cache" -or -name "*.hints" -or -path "*/kernel.old/*" \) -exec shasum -a256 {} + >>$workfile 2>/dev/null

# generically-handled dirs
while read -r DIR; do
  echo $DIR
  find $DIR -type f -exec shasum -a256 {} + >>$workfile 2>/dev/null
done <<EOD
/bin
/etc/rc.d
/sbin
/usr/bin
/usr/lib
/usr/libexec
/usr/local/bin
/usr/local/lib
/usr/local/libexec
/usr/local/sbin
/usr/local/www
/usr/sbin
/usr/share/firmware
/usr/share/keys/pkg
EOD

# exclusions
while read -r MATCH; do
  sed -i.bak -E "\|$MATCH|d" $workfile
done <<EOS
/boot/entropy
/boot/firmware/
/boot/menu.rc.sample
/etc/inc/priv/
/usr/lib/debug/
/usr/local/bin/speedtest
/usr/local/bin/speedtest-cli
/usr/local/lib/perl5/
/usr/local/lib/python[0-9.]+/
/usr/local/sbin/iftop
/usr/local/sbin/vnstatd
/usr/local/www/acme/
/usr/local/www/aws-sdk/
/usr/local/www/csrf/csrf-secret.php
/usr/local/www/haproxy/
/usr/local/www/packages/
/usr/local/www/shortcuts/
/usr/local/www/status_traffic_totals.php
/usr/local/www/system_patches.php
/usr/local/www/system_patches_edit.php
/usr/local/www/vnstat_fetch_json.php
/usr/local/www/vpn_ipsec_profile.php
/usr/local/www/vpn_openvpn_export.php
/usr/local/www/vpn_openvpn_export_shared.php
/usr/local/www/widgets/include/widget-haproxy.inc
/usr/local/www/widgets/widgets/haproxy.widget.php
/usr/local/www/wizards/
^.*\.orig$
EOS

sort -k2 $workfile >>$outfile
rm $workfile $pkginfo 2>/dev/null

echo "$outfile has been generated"
