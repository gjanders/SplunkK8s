#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf

LOG_FILE=/opt/splunkforwarder/var/log/splunk/k8s_node_offline.sh

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

log kubectl cordon `hostname`
kubectl cordon `hostname` 2>&1 | tee -a ${LOG_FILE}

kubectl get pods -o wide -A | grep $(hostname) | grep "splunk-" > /tmp/pod_output.txt
while IFS= read -r line; do
    log "$line is running on this node"
    cm=`echo $line | grep "cluster-manager"`
    indexer=`echo $line | grep "indexer"`
    searchhead=`echo $line | grep "search-head"`
    splunk=`echo $line | grep " splunk-"`
    namespace=`echo $line | awk '{ print $1 }'`
    pod=`echo $line | awk '{ print $2 }'`
    if [ "x$indexer" != "x" ]; then
        log "$pod is an indexer in namespace $namespace. Calling /root/scripts/offline_remove_pod.sh indexer $namespace $pod"
        /root/scripts/offline_remove_pod.sh "indexer" "$namespace" "$pod" &
        pids+=($!)
    elif [ "x$cm" != "x" ]; then
        log "$pod is a cluster manager in namespace $namespace. Calling /root/scripts/offline_remove_pod.sh clustermanager $namespace $pod"
        /root/scripts/offline_remove_pod.sh "clustermanager" "$namespace" "$pod" &
        pids+=($!)
    elif [ "x${searchhead}" != "x" ]; then
        log "$pod is a search head in namespace $namespace. Calling /root/scripts/offline_remove_pod.sh searchhead $namespace $pod"
        /root/scripts/offline_remove_pod.sh "searchhead" "$namespace" "$pod" &
        pids+=($!)
    elif [ "x$splunk" != "x" ]; then
        log "$pod is a splunk instance in namespace $namespace. Calling /root/scripts/offline_remove_pod.sh splunk $namespace $pod"
        /root/scripts/offline_remove_pod.sh "splunk" "$namespace" "$pod" &
        pids+=($!)
    fi
    #echo namespace is $namespace
    #echo pod is $pod
done < /tmp/pod_output.txt

for pid in "${pids[@]}"; do
    wait "${pid}"
    status+=($?)
done

for i in "${!status[@]}"; do
    log "job $i exited with ${status[$i]}"
done

log "kubectl drain `hostname` --ignore-daemonsets"
kubectl drain `hostname` --ignore-daemonsets 2>&1 | tee -a ${LOG_FILE}
