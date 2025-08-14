#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf

# This script is designed to offline or stop a splunk instance gracefully
# for indexer within the cluster that involves an offline

LOG_FILE=/opt/splunkforwarder/var/log/splunk/k8s_node_offline.log

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

type=$1
namespace=$2
pod=$3
log "$0 running with type=$type, namespace=$namespace, pod=$pod"

# determine password to offline said indexer
if [ $type == "indexer" ]; then
  tmpfile=/tmp/pod_names_$$.txt
  #kubectl get pods -A | grep cluster-manager > ${tmpfile}
  #while IFS= read -r line; do
  #  name=`echo $line | awk '{ print $2 }' | cut -d "-" -f2`
  #  ns=`echo $line | awk '{ print $1 }'`
  #  # secrets are filesystem mounted, we don't need to retrieve them like this
  #  secret=`kubectl get secret splunk-${name}-secret -n $ns -o jsonpath='{.data.password}' | base64 --decode`
  #  if [ "$ns" == "$namespace" ]; then
  #      break
  #  fi
  #done < ${tmpfile}
  #rm ${tmpfile}
  log "kubectl exec -n $namespace $pod -- cat /mnt/splunk-secrets/password"
  password=`kubectl exec -n $namespace $pod -- cat /mnt/splunk-secrets/password`
  log "kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk offline -auth admin:password"
  kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk offline -auth admin:$password 2>&1 | tee -a ${LOG_FILE}
elif [ $type == "searchhead" ]; then
  log "$date kubectl cp -n $namespace /root/scripts/splunk_enable_detention.sh $pod:/opt/splunk/var/splunk_enable_detention.sh"
  kubectl cp -n $namespace /root/scripts/splunk_enable_detention.sh $pod:/opt/splunk/var/splunk_enable_detention.sh 2>&1 | tee -a ${LOG_FIE}
  log "kubectl exec -n $namespace $pod -- sh /opt/splunk/var/splunk_enable_detention.sh"
  kubectl exec -n $namespace $pod -- sh /opt/splunk/var/splunk_enable_detention.sh 2>&1 | tee -a ${LOG_FILE}
else
  log "pod=$pod namespace=$namespace, non-indexers/search heads will be stopped without offline/detention"
fi
log "kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk stop"
kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk stop 2>&1 | tee -a ${LOG_FILE}
log "kubectl delete pod -n $namespace $pod"
kubectl delete pod -n $namespace $pod 2>&1 | tee -a ${LOG_FILE}
