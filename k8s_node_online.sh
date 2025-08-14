#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf
LOG_FILE=/opt/splunkforwarder/var/log/splunk/k8s_node_online.log

set -o pipefail

namespace_pod_array=()
pids=()
start_time=$(date +%s)
max_duration=$((16 * 60 * 60))  # 16 hours in seconds

# Logging function
log() {
    local message="$1"
    if [ -f "$LOG_FILE" ]; then
        local log_size
        log_size=$(stat -c%s "$LOG_FILE")
        if [ "$log_size" -ge "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "${LOG_FILE}.1"
        fi
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S.%3N %z') - $message" | tee -a "$LOG_FILE"
}

# function to online search heads if they exist
online_search_heads() {
    while IFS= read -r line; do
        log "$line is running on this node"
        namespace=`echo $line | awk '{ print $1 }'`
        pod=`echo $line | awk '{ print $2 }'`
        namespace_pod="$namespace:$pod"
        if [[ " ${namespace_pod_array[*]} " =~ [[:space:]]${namespace_pod}[[:space:]] ]]; then
            continue
        fi
        namespace_pod_array+=($namespace_pod)
        log "$pod is a search head in namespace $namespace. Copying splunk_disable_detention.sh"
        kubectl cp -n $namespace /root/scripts/splunk_disable_detention.sh $pod:/opt/splunk/var/splunk_disable_detention.sh
        kubectl exec -n $namespace $pod -- sh /opt/splunk/var/splunk_disable_detention.sh &
        pids+=($!)
    done < /tmp/pod_output.txt
}

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ "$elapsed" -ge "$max_duration" ]; then
        log "Max duration reached without a successful uncordon. Exiting."
        break
    fi

    log "Attempting kubectl uncordon"
    kubectl uncordon "$(hostname)" 2>&1 | tee -a "$LOG_FILE"
    rc=${PIPESTATUS[0]}

    if [ "$rc" -eq 0 ]; then
        log "kubectl uncordon returned 0. Exiting loop."
        break
    fi

    log "Sleeping 60 seconds before next round"
    sleep 60
done

# wait 120 seconds for scheduler to allocate the pods as expected
sleep 120
kubectl get pods -A -o wide | grep `hostname` | grep "search-head.*Running" > /tmp/pod_output.txt
ret_code=$?

if [ $ret_code -eq 0 ]; then
    log "Running search heads found on `hostname`"
    online_search_heads
fi

# confirm status of the online scripts we ran in search heads if they exist
for pid in "${pids[@]}"; do
    wait "${pid}"
    status+=($?)
done

for i in "${!status[@]}"; do
    log "job $i exited with ${status[$i]}"
done

log "k8s_node_online script complete"

