#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf

date=`/bin/date +"%Y-%m-%d %H:%M:%S.%3N %z"`
log=/opt/splunkforwarder/var/log/splunk/k8s_node_offline.sh

echo $date kubectl cordon `hostname` > ${log}
kubectl cordon `hostname` 2>&1 | tee -a ${log}

kubectl get pods -o wide -A | grep $(hostname) | grep "splunk-" > /tmp/pod_output.txt
while IFS= read -r line; do
    echo $date $line is running on this node | tee -a ${log}
    cm=`echo $line | grep "cluster-manager"`
    indexer=`echo $line | grep "indexer"`
    searchhead=`echo $line | grep "search-head"`
    splunk=`echo $line | grep " splunk-"`
    namespace=`echo $line | awk '{ print $1 }'`
    pod=`echo $line | awk '{ print $2 }'`
    if [ "x$indexer" != "x" ]; then
        echo "$date $pod is an indexer in namespace $namespace. Calling /root/scripts/offline_remove_pod.sh indexer $namespace $pod" | tee -a ${log}
        /root/scripts/offline_remove_pod.sh "indexer" "$namespace" "$pod" &
        pids+=($!)
    elif [ "x$cm" != "x" ]; then
        echo "$date $pod is a cluster manager in namespace $namespace. Calling /root/scripts/offline_remove_pod.sh clustermanager $namespace $pod" | tee -a ${log}
        /root/scripts/offline_remove_pod.sh "clustermanager" "$namespace" "$pod" &
        pids+=($!)
    elif [ "x${searchhead}" != "x" ]; then
        echo "$date $pod is a search head in namespace $namespace. Calling /root/scripts/offline_remove_pod.sh searchhead $namespace $pod" | tee -a ${log}
        /root/scripts/offline_remove_pod.sh "searchhead" "$namespace" "$pod" &
        pids+=($!)
    elif [ "x$splunk" != "x" ]; then
        echo "$date $pod is a splunk instance in namespace $namespace. Calling /root/scripts/offline_remove_pod.sh splunk $namespace $pod" | tee -a ${log}
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
    echo "$date job $i exited with ${status[$i]}" | tee -a ${log}
done

echo "$date kubectl drain `hostname` --ignore-daemonsets" | tee -a ${log}
kubectl drain `hostname` --ignore-daemonsets 2>&1 | tee -a ${log}
