#!/bin/bash
date=`/bin/date +"%Y-%m-%d %H:%M:%S.%3N %z"`
log=/opt/splunkforwarder/var/log/splunk/k8s_node_healthcheck.log
echo "$date beginning checking for down workers" > ${log}
echo "$date running kubectl get node -l node-role.kubernetes.io/worker= -o json"  >> ${log}
kubectl get node -l node-role.kubernetes.io/worker= -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].lastHeartbeatTime}{"\n"}' > /tmp/combined.txt

current_time=$(date +%s)

echo "$date results below" >> ${log}
cat /tmp/combined.txt >> ${log}

while IFS= read -r line; do
    # Process each line here (e.g., print it)
    node=`echo $line | cut -d " " -f1`
    time=`echo $line | cut -d " " -f2`
    if [ "x$node" = "x" ]; then
      echo "$date empty line"
      continue
    fi
    #echo $node
    #echo $time
    target_time=$(date -d "$time" +%s)
    seconds_difference=$((current_time - target_time))
    #echo "$node seconds difference is $seconds_difference"
    echo "$date node=$node found seconds_difference=$seconds_difference" >> ${log}
    if [ $seconds_difference -gt 800 ]; then
        echo "$date $node down for more than 12 minutes, something is broken here seconds_difference=$seconds_difference > threshold" >> ${log}
        pods=`kubectl get pods -A --field-selector spec.nodeName=$node --selector app.kubernetes.io/name=cluster-manager | grep -v "NAMESPACE"`
        if [ "x$pods" != "x" ]; then
            echo "$date node=$node has pods $pods including a CM" >> ${log}
            namespace=`echo $pods | awk '{ print $1 }'`
            pvc=`kubectl get pvc -n $namespace -o name | grep cluster-manager`
            echo "$date node=$node has CM pvc $pvc" >> ${log}
            for a_pvc in $pvc; do
                echo "$date kubectl delete -n $namespace $a_pvc" >> ${log}
                kubectl delete -n $namespace $a_pvc 2>&1 >> ${log} &
                sleep 10
                echo "$date kubectl get -n $namespace $a_pvc" >> ${log}
                res=`kubectl get -n $namespace $a_pvc`
                echo "$date $res" >> ${log}
                if [ "x$res" != "x" ]; then
                    echo "$date kubectl patch -n $namespace $a_pvc -p '{\"metadata\":{\"finalizers\":null}}'" >> ${log}
                    kubectl patch -n $namespace $a_pvc -p '{"metadata":{"finalizers":null}}' 2>&1 >> ${log}
                    sleep 3
                fi
            done
            the_pod=`echo $pods | awk '{ print $2 }'`
            echo "$date kubectl delete pod -n $namespace ${the_pod}" >> ${log}
            kubectl delete pod -n $namespace ${the_pod} --grace-period 0 --force 2>&1 >> ${log}
        else
            echo "$date No cluster managers found on $node" >> ${log}
        fi
    fi
done < /tmp/combined.txt
