count=`ps -ef | grep /root/scripts/roll_and_resync_buckets_v2.py | grep -v grep | wc -l`

if [ $count -ne 0 ]; then
  pid=`ps -ef | grep /root/scripts/roll_and_resync_buckets_v2.py | grep -v grep | awk '{ print $2 }'`
  file_mod_time=$(stat --format='%Y' /proc/${pid})
  # Get the current time in seconds since the epoch
  current_time=$(date +"%s")
  time_difference=$((current_time - file_mod_time))
  if [ "$time_difference" -gt 1200 ]; then
    echo "$pid has continued to run for >20 mins, killing and starting again"
    kill $pid
  else
    exit 1
  fi
fi

python3 /root/scripts/roll_and_resync_buckets_v2.py $1 2>&1 | tee /tmp/roll_and_resync_buckets_v2.log

