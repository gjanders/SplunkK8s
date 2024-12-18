#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf
date=`/bin/date +"%Y-%m-%d %H:%M:%S.%3N %z"`
log=/opt/splunkforwarder/var/log/splunk/k8s_node_online.log

namespace_pod_array=()
pids=()

# function to online search heads if they exist
online_search_heads() {
    while IFS= read -r line; do
        echo $date $line is running on this node | tee -a ${log}
        namespace=`echo $line | awk '{ print $1 }'`
        pod=`echo $line | awk '{ print $2 }'`
        namespace_pod="$namespace:$pod"
        if [[ " ${namespace_pod_array[*]} " =~ [[:space:]]${namespace_pod}[[:space:]] ]]; then
            continue
        fi
        namespace_pod_array+=($namespace_pod)
        echo "$date $pod is a search head in namespace $namespace. Copying splunk_disable_detention.sh" | tee -a ${log}
        kubectl cp -n $namespace /root/scripts/splunk_disable_detention.sh $pod:/opt/splunk/var/splunk_disable_detention.sh
        kubectl exec -n $namespace $pod -- sh /opt/splunk/var/splunk_disable_detention.sh &
        pids+=($!)
    done < /tmp/pod_output.txt
}

# sleep 1 minute to allow services to come online
sleep 60
echo $date kubectl uncordon `hostname` > ${log}
kubectl uncordon `hostname` 2>&1 | tee -a ${log}

# in some cases it takes longer than 1 minute, in these cases we can sleep longer
# and the extra uncordon will do no harm
sleep 120
echo $date kubectl uncordon `hostname` round 2 > ${log}
kubectl uncordon `hostname` 2>&1 | tee -a ${log}

kubectl get pods -A -o wide | grep `hostname` | grep "search-head.*Running" > /tmp/pod_output.txt
ret_code=$?

if [ $ret_code -eq 0 ]; then
    echo $date running search heads found on `hostname` | tee -a ${log}
    online_search_heads
fi

sleep 120
echo $date kubectl uncordon `hostname` round 3 > ${log}
kubectl uncordon `hostname` 2>&1 | tee -a ${log}

kubectl get pods -A -o wide | grep `hostname` | grep "search-head.*Running" > /tmp/pod_output.txt
ret_code=$?
if [ $ret_code -eq 0 ]; then
    echo $date running search heads found on `hostname` | tee -a ${log}
    online_search_heads
fi

sleep 300
echo $date kubectl uncordon `hostname` round 4 > ${log}
kubectl uncordon `hostname` 2>&1 | tee -a ${log}

kubectl get pods -A -o wide | grep `hostname` | grep "search-head.*Running" > /tmp/pod_output.txt
ret_code=$?
if [ $ret_code -eq 0 ]; then
    echo $date running search heads found on `hostname` | tee -a ${log}
    online_search_heads
fi

# just in case
sleep 600
kubectl get pods -A -o wide | grep `hostname` | grep "search-head.*Running" > /tmp/pod_output.txt
ret_code=$?
if [ $ret_code -eq 0 ]; then
    echo $date running search heads found on `hostname` | tee -a ${log}
    online_search_heads
fi

# confirm status of the online scripts we ran in search heads if they exist
for pid in "${pids[@]}"; do
    wait "${pid}"
    status+=($?)
done

for i in "${!status[@]}"; do
    echo "$date job $i exited with ${status[$i]}" | tee -a ${log}
done
