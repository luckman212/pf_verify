#!/bin/sh

# verify integrity of base system files against known-good hashes
# checksum files can be downloaded from: {url}
# usage:
#   sh pf_verify.sh [checksum_filename]
#   without a filename, a checksum file will be generated for the running system

if [ -e "$1" ]; then
  shasum -c "$1" | grep -v ': OK$'
  exit $?
fi

outfile=$HOME/checksums_$HOST
workfile=pf_verify_tmp
pkginfo=pkginfo_tmp
cd /tmp || exit 1
rm "$workfile" 2>/dev/null

echo "this will take a few seconds..."
pkg-static info pfSense-base >$pkginfo 2>/dev/null
echo "# generated on $(date)" >$outfile
echo "# pfSense $(awk -F': ' '/Version/ { print $2 }' $pkginfo)" >>$outfile
echo "# arch: $(awk -F': ' '/Architecture/ { print $2 }' $pkginfo) [$(freebsd-version)]" >>$outfile

# "special" dirs
echo "/etc/inc"
find /etc/inc -type f -name "*.inc" -exec shasum -a256 {} + >$workfile 2>/dev/null
echo "/boot"
find /boot -type f ! \( -name "*.conf" -or -name "*.cache" -or -name "*.hints" \) -exec shasum -a256 {} + >>$workfile 2>/dev/null
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

sort -k2 $workfile >>$outfile
rm $workfile $pkginfo 2>/dev/null

echo "$outfile has been generated"
