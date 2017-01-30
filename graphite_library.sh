#!/bin/bash

DEBUG=0
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/omni/bin:/opt/omni/lbin:/opt/omni/sbin:/usr/local/rvm/bin:/opt/omni/bin:/opt/omni/lbin:/opt/omni/sbin
GRAPHITEHOST=$(hostname -f)

if [ "$(host $@ > /dev/null 2>&1; echo $?)" -eq 0 ]; then
  GRAPHITEHOST=$1
else
  echo "Host \"$@\" not found!"
  echo "Usage: $0 <grpahitehost>"
  exit 1
fi
# General
function pool_general() {
  omnirpt -tab  -report pool_list | \
    awk -F '\t'\
        -v h="$(hostname -f)" '$1 !~ /#/ {
      gsub(/ /, "_", $1); gsub(/\./,"_", h);
      print "hpdp."h".pool."$1".full", $4, systime();
      print "hpdp."h".pool."$1".appendable", $5, systime();
      print "hpdp."h".pool."$1".free", $6, systime();
      print "hpdp."h".pool."$1".poor", $7, systime();
      print "hpdp."h".pool."$1".fair", $8, systime();
      print "hpdp."h".pool."$1".good", $9, systime();
      print "hpdp."h".pool."$1".media", $10, systime();
    }'
}
if [ $DEBUG -eq 0 ]; then
  nc "${GRAPHITEHOST}" 2003 < <(pool_general)
else
  pool_general
fi

#Media
function media_list() {
  for p in $(omnirpt -report pool_list -tab | awk '$1 !~ /#/ {print $1}'); do
    omnirpt -tab -report media_list -pool $p | \
      awk -F "\t"\
          -v p="$p" -v h="$(hostname -f)" '$1 !~ /#/ {
        gsub(/.*] /, "", $2); gsub(/\./,"_", h);
        if ($5 ~ /Permanent/) {ttl="-1"};
        if ($5 ~ /None/) {ttl="0"};
        print "hpdp."h".pool." p ".media." $2 ".status", $4, systime();
        if ($5 !~ /Permanent|None/) {
          system("date -d \"" $5 "\" +hpdp." h ".pool." p ".media." $2 ".protection\\ %s\\ " systime());
        } else {
          print "hpdp."h".pool." p ".media." $2 ".protection", ttl, systime(); };
        print "hpdp."h".pool." p ".media." $2 ".used_mb", $6, systime();
        print "hpdp."h".pool." p ".media." $2 ".total_mb", $7, systime();
        print "hpdp."h".pool." p ".media." $2 ".last_used", $9, systime();
      }'
  done
}
if [ $DEBUG -eq 0 ]; then
  nc "${GRAPHITEHOST}" 2003 < <(media_list)
else
  media_list
fi

#SOS
function sos_info() {
  for i in $(omnirpt -tab  -report pool_list | awk -F '\t' '$0 ~ /StoreOnce software deduplication/ {print $1}'); do
    omnib2dinfo -store_info -b2ddevice $i | \
    awk -v s="$i" -v h="$(hostname -f)" '{gsub(/\./,"_", h)};
      $0 ~ /Store Status/ {o=0; if($3=="Online"){o=1}; print "hpdp."h".storeonce."s".status", o, systime()};
      $0 ~ /User Data Stored/ {print "hpdp."h".storeonce."s".real_used", $4, systime()};
      $0 ~ /Store Data Size/ {print "hpdp."h".storeonce."s".disk_used", $4, systime()};
      $0 ~ /Soft Quota Store Size/ {print "hpdp."h".storeonce."s".soft_qouta", $5*1024, systime()};
    '
    omnib2dinfo -get_server_properties -b2ddevice $i | \
    awk -v s="$i" -v h="$(hostname -f)" '{gsub(/\./,"_", h)}
      $0 ~ /Disk Size/ {print "hpdp."h".storeonce."s".disk_size", $3, systime()};
      $0 ~ /Disk Free/ {print "hpdp."h".storeonce."s".disk_free", $3, systime()};
    '
  done
}
if [ $DEBUG -eq 0 ]; then
  nc "${GRAPHITEHOST}" 2003 < <(sos_info)
else
  sos_info
fi
