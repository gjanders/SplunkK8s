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
  echo "$date kubectl exec -n $namespace $pod -- cat /mnt/splunk-secrets/password" | tee -a ${log}
  password=`kubectl exec -n $namespace $pod -- cat /mnt/splunk-secrets/password`
  echo "$date kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk offline -auth admin:password" | tee -a ${log}
  kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk offline -auth admin:$password 2>&1 | tee -a ${log}
elif [ $type == "searchhead" ]; then
  echo "$date kubectl cp -n $namespace /root/scripts/splunk_enable_detention.sh $pod:/opt/splunk/var/splunk_enable_detention.sh" | tee -a ${log}
  kubectl cp -n $namespace /root/scripts/splunk_enable_detention.sh $pod:/opt/splunk/var/splunk_enable_detention.sh
  echo "$date kubectl exec -n $namespace $pod -- sh /opt/splunk/var/splunk_enable_detention.sh" | tee -a ${log}
  kubectl exec -n $namespace $pod -- sh /opt/splunk/var/splunk_enable_detention.sh 2>&1 | tee -a ${log}
else
  echo "$date pod=$pod namespace=$namespace, non-indexers/search heads will be stopped without offline/detention" | tee -a ${log}
fi
echo "$date kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk stop" | tee -a ${log}
kubectl exec -n $namespace $pod -- /opt/splunk/bin/splunk stop 2>&1 | tee -a ${log}
echo "$date kubectl delete pod -n $namespace $pod"
kubectl delete pod -n $namespace $pod 2>&1 | tee -a ${log}
