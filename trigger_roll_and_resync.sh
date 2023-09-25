#/bin/bash
kubectl get pods -A | grep cluster-manager > /tmp/pod_names.txt
while IFS= read -r line; do
    name=`echo $line | awk '{ print $2 }' | cut -d "-" -f2`
    ns=`echo $line | awk '{ print $1 }'`
    secret=`kubectl get secret splunk-${name}-secret -n $ns -o jsonpath='{.data.password}' | base64 --decode`
    kubectl exec -n $ns splunk-${name}-cm-cluster-manager-0 -- /opt/splunk/bin/splunk list user  -auth "admin:$secret" | grep "roll_buckets_automated"
    ret_code=$?
    # user does not exist and must be created, assume role must be created too
    if [ $ret_code -ne 0 ]; then
        kubectl exec -n $ns splunk-${name}-cm-cluster-manager-0 -- /opt/splunk/bin/splunk _internal call /services/authorization/roles -post:capabilities edit_indexer_cluster -post:capabilities list_indexer_cluster -post:name roll_buckets_automated -auth "admin:$secret"
        kubectl exec -n $ns splunk-${name}-cm-cluster-manager-0 -- /opt/splunk/bin/splunk  add user roll_buckets_automated -password {{ roll_buckets_automated_k8s }} -role roll_buckets_automated -auth "admin:$secret"
    fi
done < /tmp/pod_names.txt

cluster_managers=`kubectl get virtualservice -n istio-system | grep "\-cm.network" | awk '{ print $3 }' | cut -d '"' -f2`
for cluster_manager in `echo $cluster_managers`; do
    /root/scripts/roll_and_resync_buckets_v2.sh $cluster_manager
    sleep 30
done

