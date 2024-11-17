# SplunkK8s
This repository hosts K8s related scripts, the files purposes are quite simple:

### trigger_roll_and_resync.sh
`trigger_roll_and_resync.sh` and the related files, `roll_and_resync_buckets_v2.sh/py` relate to rolling buckets not meeting the replication factor within a K8s indexer cluster(s).

This script exists because we are using local storage, if the bucket is not meeting replication factor there is a risk of data loss if the data is not uploaded to S3. This automation handles the rolling across multiple indexer clusters located with K8s.

### k8s_healthcheck.sh
`k8s_healthcheck.sh` exists for a specific purpose...originally we had local (non-replicated) storage under the cluster manager. If the node failed, we could delete the PVC to force the CM to re-locate the cluster manager to a healthy K8s node in a node loss scenario.

However, the issue was that the appframework did not re-deploy the cluster manager apps to the members, therefore the bundle push was an empty bundle when the CM restarted.

The workaround used was to delete & re-create the cluster manager CR (custom resource), this forces the appframework to re-deploy all previous applicationsi.

This setup was later replaced by Pireaus Datastore, the [post here](/posts/kubernetes-storage) describes the details of this replicated storage option.


### k8s_offline.service
`k8s_offline.service` is a systemd unit file that can be combined with `k8s_node_offlinev2.sh` and `offline_remove_pod.sh` or the simpler `k8s_node_offline.sh`

While K8s 1.24 was documented to handle graceful shutdown, I found that when the Splunk pods in the tested version received the shutdown signal, as tested on Splunk version 9.0.3 and 9.1.3, the pods did not always shutdown Splunk. In many cases the Splunk instance abruptly terminated resulting in bucket corruption on startup.

To resolve this, the custom Systemd unit file ensures a Splunk offline command is run prior to the node going offline, the online service simply removes the cordon from the node.

This may not be required if you can see your Splunk instances shutting down cleanly with OS shutdown.

