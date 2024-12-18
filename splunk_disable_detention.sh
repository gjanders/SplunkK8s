log=/opt/splunk/var/log/splunk/splunk_disable_detention.log

echo "$(date) Splunk disable detention script begins" | tee -a ${log}
/opt/splunk/bin/splunk status 2>&1 | tee -a ${log}

time_count=0
while [ $time_count -le 1200 ]; do
        OUTPUT=$(/opt/splunk/bin/splunk edit shcluster-config -manual_detention off -auth admin:`cat /mnt/splunk-secrets/password`)
        ret_code=$?
        if [ $ret_code -eq 0 ]; then
                echo "$(date) splunk edit shcluster-config -manual_detention off return code 0 after time_count=${time_count}. Manual detention disabled..." | tee -a ${log}
                break
        else
                echo "$(date) splunk edit shcluster-config -manual_detention off did not match return code=0, time_count=${time_count} will sleep and try again in 15 seconds" | tee -a ${log}
        fi
        sleep 15
        time_count=$(( $time_count + 15 ))
done

if [ $time_count -ge 1200 ]; then
    echo "$(date) time limit exceeded and removing manual detention has not succeeded, giving up" | tee -a $(log)
fi