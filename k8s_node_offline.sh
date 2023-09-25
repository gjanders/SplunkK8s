#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf

date=`/bin/date +"%Y-%m-%d %H:%M:%S.%3N %z"`
log=/opt/splunkforwarder/var/log/splunk/k8s_node_offline.sh

echo $date nkubectl cordon `hostname` > ${log}
kubectl cordon `hostname` 2>&1 | tee -a ${log}
kubectl drain `hostname` --ignore-daemonsets 2>&1 | tee -a ${log}
