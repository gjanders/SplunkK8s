#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf

# This script is designed to offline or stop a splunk instance gracefully
# for indexer within the cluster that involves an offline

date=`/bin/date +"%Y-%m-%d %H:%M:%S.%3N %z"`
log=/opt/splunkforwarder/var/log/splunk/k8s_node_offline.sh
type=$1
namespace=$2
pod=$3
echo "$date $0 running with type=$type, namespace=$namespace, pod=$pod" | tee -a ${log}

# determine password to offline said indexer
if [ $type == "indexer" ]; then
  tmpfile=/tmp/pod_names_$$.txt
  kubectl get pods -A | grep cluster-manager > ${tmpfile}
  while IFS= read -r line; do
    name=`echo $line | awk '{ print $2 }' | cut -d "-" -f2`
    ns=`echo $line | awk '{ print $1 }'`
    secret=`kubectl get secret splunk-${name}-secret -n $ns -o jsonpath='{.data.password}' | base64 --decode`
    if [ "$ns" == "$namespace" ]; then
        break
    fi
  done < ${tmpfile}
  rm ${tmpfile}
  echo "$date kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk offline -auth admin:" | tee -a ${log}
  kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk offline -auth admin:$secret 2>&1 | tee -a ${log}
else
  echo "$date pod=$pod namespace=$namespace, non-indexers will be stopped without an offline" | tee -a ${log}
fi
echo "$date kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk stop" | tee -a ${log}
kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk stop 2>&1 | tee -a ${log}
echo "$date kubectl delete pod -n $namespace $pod"
kubectl delete pod -n $namespace $pod 2>&1 | tee -a ${log}
