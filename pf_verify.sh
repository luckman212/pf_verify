#!/bin/sh

# verify integrity of base system files against known-good hashes
# checksum files can be downloaded from: {url}
# usage:
#   sh pf_verify.sh [checksum_filename]
#   without a filename, a checksum file will be generated for the running system

if [ -n "$1" ]; then
  if [ -e "$1" ]; then
    shasum -c "$1" | grep -v ': OK$'
    [ $? -eq 0 ] || echo "all files passed integrity check"
    exit
  else
    echo "$1 not found"
    exit 1
  fi
fi

ts=$(date '+%Y%m%d_%H%M%S')
outfile=$HOME/pfv_${HOST}_${ts}.sha256
workfile=pf_verify_tmp
pkginfo=pkginfo_tmp
cd /tmp || exit 1
rm $workfile $outfile $pkginfo 2>/dev/null

echo "this will take a few seconds..."
pkg-static info pfSense-base >$pkginfo 2>/dev/null
model="$(echo '<?php include("config.inc"); $p = system_identify_specific_platform(); $d = $p['descr']; $o = (($d) ? $d : 'unknown'); echo $o; ?>' | /usr/local/bin/php -q)"
ver="$(awk -F': ' '/Version/ { print $2 }' $pkginfo)"
arch="$(awk -F': ' '/Architecture/ { print $2 }' $pkginfo) [$(freebsd-version)]"

cat <<EOF >>$outfile
# pf_verify checksum file
# hostname:      ${HOST}
# generated on:  $(date)
# version:       $ver [$model]
# architecture:  $arch

EOF

# "special" dirs
echo "/etc/inc"
find /etc/inc -type f -name "*.inc" -exec shasum -a256 {} + >$workfile 2>/dev/null
echo "/boot"
find /boot -type f ! \( -name "*.conf" -or -name "*.cache" -or -name "*.hints" -or -path "*/kernel.old/*" \) -exec shasum -a256 {} + >>$workfile 2>/dev/null
echo "/usr/local/www"
find /usr/local/www -type f ! -name "*.orig" -exec shasum -a256 {} + >>$workfile 2>/dev/null

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
/usr/sbin
/usr/share/firmware
/usr/share/keys/pkg
EOD

# omits
while read -r MATCH; do
  sed -i.bak -E "\|$MATCH|d" $workfile
done <<EOS
/boot/menu.rc.sample
/etc/inc/priv/cron.priv.inc
/usr/lib/debug/
/usr/local/bin/speedtest
/usr/local/bin/speedtest-cli
/usr/local/lib/perl5/
/usr/local/lib/python[0-9.]+/
/usr/local/sbin/iftop
/usr/local/www/csrf/csrf-secret.php
/usr/local/www/packages/
EOS

sort -k2 $workfile >>$outfile
rm $workfile $pkginfo 2>/dev/null

echo "$outfile has been generated"
