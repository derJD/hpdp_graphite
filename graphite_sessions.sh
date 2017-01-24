#!/bin/bash

DEBUG=1
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/omni/bin:/opt/omni/lbin:/opt/omni/sbin:/usr/local/rvm/bin:/opt/omni/bin:/opt/omni/lbin:/opt/omni/sbin
GRAPHITEHOST=$(hostname -f)

function get_sessions() {
  omnirpt -tab -report list_sessions -timeframe 24 672 -group "$1" -no_copylist -no_verificationlist -no_conslist -datalist "$2" |\
    awk -v h="$(hostname -f)"\
        -v c="$1"\
        -F '\t' '$1 !~ /^#/ {
      split($10, s, ":"); gsub(/\./,"_", h); gsub(/ /, "_", $2);
      print "hpdp."h".session."c"."$2".duration", s[1]*3600+s[2]*60, $6;
      print "hpdp."h".session."c"."$2".written", $11*1024, $6;
      print "hpdp."h".session."c"."$2".errors", $13, $6;
      print "hpdp."h".session."c"."$2".warnings", $14, $6;
      print "hpdp."h".session."c"."$2".fails", $17, $6;
      print "hpdp."h".session."c"."$2".completes", $18, $6;
      print "hpdp."h".session."c"."$2".objects", $19, $6;
      print "hpdp."h".session."c"."$2".files", $20, $6
    }'
}

function get_copy_sessions() {
  omnirpt -tab -report list_sessions -timeframe 24 672 -group "$1" -no_datalist -no_verificationlist -no_conslist -copylist_post "$2" |\
    awk -v h="$(hostname -f)"\
        -v c="$1"\
        -F '\t' '$1 !~ /^#/ {
      split($10, s, ":"); gsub(/\./,"_", h); gsub(/ /, "_", $2);
      print "hpdp."h".session."c"."$2".duration", s[1]*3600+s[2]*60, $6;
      print "hpdp."h".session."c"."$2".written", $11*1024, $6;
      print "hpdp."h".session."c"."$2".errors", $13, $6;
      print "hpdp."h".session."c"."$2".warnings", $14, $6;
      print "hpdp."h".session."c"."$2".fails", $17, $6;
      print "hpdp."h".session."c"."$2".completes", $18, $6;
      print "hpdp."h".session."c"."$2".objects", $19, $6;
      print "hpdp."h".session."c"."$2".files", $20, $6
    }'
}

if [ "$(host $@ > /dev/null 2>&1; echo $?)" -eq 0 ]; then
  GRAPHITEHOST=$1
else
  if [ $DEBUG -eq 0 ]; then
    echo "Host \"$@\" not found!"
    echo "Usage: $0 <grpahitehost>"
    exit 1
  fi
fi

# Type Backup
#days: 86400
#weeks: 604800
#permanent: -1
for i in $(grep -IRl GROUP /etc/opt/omni/server/datalists | xargs awk '$0 ~ /GROUP/ {gsub(/\"/, "", $2); g=$2}; $2 ~ /-protect/ {sub(/.*datalists\//, "", FILENAME); if($3=="permanent") ttl=-1; if($3=="days") ttl=86400*$4; if($3 == "weeks") ttl=604800*$4; print g"."FILENAME"."ttl}'); do
  customer=$(echo $i | awk -F '.' '{print $1}')
  job=$(echo $i | awk -F '.' '{print $2}')
  ttl=$(echo $i | awk -F '.' '{print $3}')

  if [ $DEBUG -eq 0 ]; then
    nc "${GRAPHITEHOST}" 2003 < <(echo hpdp.$(hostname -f| sed 's/\./_/g').session.${customer}.${job}.retention ${ttl} $(date +%s))
    nc "${GRAPHITEHOST}" 2003 < <(get_sessions "${customer}" "${job}" "${mode}")
  else
    echo hpdp.$(hostname -f| sed 's/\./_/g').session.${customer}.${job}.retention ${ttl} $(date +%s)
    get_sessions "${customer}" "${job}"
  fi
done

# Type Online Backup
for i in $(grep -IZRl GROUP /etc/opt/omni/server/barlists/ | xargs -0 awk '$0 ~ /GROUP/ {gsub(/\"/, "", $2); g=$2}; $2 ~ /-protect/ {sub(/.*barlists\//, "", FILENAME); sub(/\//, "::", FILENAME); gsub(/ /, "::", FILENAME); if($3=="permanent") ttl=-1; if($3=="days") ttl=86400*$4; if($3 == "weeks") ttl=604800*$4; print g"."FILENAME"."ttl}'); do
  customer=$(echo $i | awk -F '.' '{print $1}')
  job=$(echo $i | awk -F '.' '{split($2, s, "::"); print toupper(s[1]), s[2], s[3]}' | sed -r 's/\s+$//g')
  ttl=$(echo $i | awk -F '.' '{print $3}')

  if [ $DEBUG -eq 0 ]; then
    nc "${GRAPHITEHOST}" 2003 < <(echo hpdp.$(hostname -f| sed 's/\./_/g').session.${customer}.$(echo ${job} | sed 's/ /_/g').retention ${ttl} $(date +%s))
    nc "${GRAPHITEHOST}" 2003 < <(get_sessions "${customer}" "${job}" "${mode}")
  else
   echo hpdp.$(hostname -f| sed 's/\./_/g').session.${customer}.$(echo ${job} | sed 's/ /_/g').retention ${ttl} $(date +%s)
   get_sessions "${customer}" "${job}"
  fi
done

# Type Copy
for i in $(egrep -IR 'OPTIONS|datalist' -A2 /etc/opt/omni/server/copylists/afterbackup/ | awk '$2 ~ /_/ {gsub(/\"/, "", $2); g=$2}; $2 ~ /-protect/ {sub(/.*afterbackup\//, "", $1); if($3=="permanent") ttl=-1; if($3=="days") ttl=86400*$4; if($3 == "weeks") ttl=604800*$4}; $2 ~ /_/ {gsub(/\"/, "", $2); sub(/.*afterbackup\//, "", $1); sub(/-$/, "", $1); print g"."$1"."ttl}'); do
  datalist=$(echo $i | awk -F '.' '{print $1}')
  customer=$(find /etc/opt/omni/server/datalists/ -name "*${datalist}" -exec awk 'BEGIN {g="Default"}; $1 ~ /GROUP/ {gsub(/\"/, "", $2); g=$2}; END {print g}' {} \;)
  job=$(echo $i | awk -F '.' '{print $2}')
  ttl=$(echo $i | awk -F '.' '{print $3}')

  if [ $DEBUG -eq 0 ]; then
    nc "${GRAPHITEHOST}" 2003 < <(echo hpdp.$(hostname -f| sed 's/\./_/g').session.${customer}.$(echo ${job} | sed 's/ /_/g').retention ${ttl} $(date +%s))
    nc "${GRAPHITEHOST}" 2003 < <(get_sessions "${customer}" "${job}" "${mode}")
  else
   echo hpdp.$(hostname -f| sed 's/\./_/g').session.${customer}.$(echo ${job} | sed 's/ /_/g').retention ${ttl} $(date +%s)
   get_copy_sessions "${customer}" "${job}" "${mode}"
  fi
done
