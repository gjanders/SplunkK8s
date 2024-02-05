#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf
date=`/bin/date +"%Y-%m-%d %H:%M:%S.%3N %z"`
log=/opt/splunkforwarder/var/log/splunk/k8s_node_online.log

# sleep 1 minute to allow services to come online
sleep 60
echo $date kubectl uncordon `hostname` > ${log}
kubectl uncordon `hostname` 2>&1 | tee -a ${log}

# uncordon twice will work if it took an unusually long period of time to get everything online
# and will do no harm
sleep 120
echo $date kubectl uncordon `hostname` (round 2) > ${log}
kubectl uncordon `hostname` 2>&1 | tee -a ${log}
