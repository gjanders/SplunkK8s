#!/bin/sh
log=/opt/splunk/var/log/splunk/splunk_enable_detention.log

echo "$(date) Splunk enabling manual detention script begins" | tee -a ${log}
/opt/splunk/bin/splunk edit shcluster-config -manual_detention on -auth admin:`cat /mnt/splunk-secrets/password` 2>&1 | tee -a ${log}
/opt/splunk/bin/splunk status 2>&1 | tee -a ${log}

time_count=0
while [ $time_count -le 400 ]; do
   OUTPUT=$(/opt/splunk/bin/splunk list shcluster-member-info -auth admin:`cat /mnt/splunk-secrets/password` | grep "active" | grep "active_historical_search_count:0")
   ret_code=$?
   if [ $ret_code -eq 0 ]; then
     echo "$(date) historical search count 0 after time_count=${time_count}" | tee -a ${log}
     break
   else
     echo "$(date) historical search count did not match count=0, time_count=${time_count}, will sleep and try again in 15 seconds" | tee -a ${log}
   fi
   sleep 15
   time_count=$(( $time_count + 15 ))
done