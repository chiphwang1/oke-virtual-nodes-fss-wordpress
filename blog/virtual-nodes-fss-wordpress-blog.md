# Build Stateful Applications on OKE Virtual Nodes with OCI File Storage

Persistent storage is now available for OCI Kubernetes Engine, or OKE, Virtual Nodes with OCI File Storage, or FSS. Applications can use Kubernetes persistent volumes to retain files across pod restarts and replacements while continuing to run without customer-managed worker nodes.

This expands the kinds of workloads that fit the Virtual Node model. Content services can retain uploads, CI and build systems can share workspaces and artifacts, data-processing stages can exchange files, and AI workloads can keep datasets, checkpoints, and model artifacts in durable shared storage.

## Persistent storage without worker-node management

Virtual Nodes provide serverless Kubernetes compute. Kubernetes schedules pods and OCI operates the underlying worker infrastructure, so application teams do not need to provision, patch, scale, or maintain worker nodes.

Pods remain ephemeral by design. A pod can be restarted, replaced, or rescheduled at any time. Data written only to a container filesystem is therefore not a durable application-data strategy.

FSS-backed persistent volumes solve that problem using the Kubernetes storage model developers already know. An application requests storage with a PersistentVolumeClaim, or PVC, and Kubernetes mounts the resulting volume in the pod. With FSS, the claim can use `ReadWriteMany`, or RWX, so multiple pods can read and write the same filesystem.

The OCI FSS CSI driver supports two provisioning models.

- Dynamic provisioning creates the filesystem resources required by a StorageClass and PVC.
- Static provisioning connects a pre-created FSS filesystem and export through a PersistentVolume.

This article demonstrates the dynamic pattern with WordPress, but the same model can support other workloads that need durable shared files.

## The WordPress example

WordPress is a useful example because it has two different kinds of state. Database records belong in MySQL, while uploads, themes, plugins, and other `wp-content` files need shared filesystem storage. Keeping these responsibilities separate lets two WordPress replicas serve the same site.

| State | Location |
| --- | --- |
| Posts, users, settings, and comments | External MySQL |
| Uploads, themes, plugins, and `wp-content` files | FSS RWX volume |
| Web-serving compute | OKE Virtual Nodes |

The WordPress pods share the FSS-backed PVC and connect to the same external MySQL database. The chart also gives every replica the same WordPress authentication keys and salts, so a request can safely reach either pod without sticky sessions.

## Architecture

Two WordPress replicas run in a Virtual Node pool. An OCI Load Balancer distributes traffic to the pods. The pods reach FSS through a PVC and PV, and connect to a private MySQL endpoint.

![OKE Virtual Nodes, FSS, and external MySQL architecture](assets/wordpress-virtual-node-fss-architecture-v2.svg)

FSS and its mount target are OCI resources in the VCN, outside the OKE cluster boundary. The data path is pod to PVC to PV to FSS export. A StorageClass defines how a PVC is provisioned. It is not mounted directly by a pod.

## Deploy the infrastructure

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress/releases/download/v0.1.1/oke-vn-fss-wordpress-orm.zip)

The Resource Manager stack can use an existing Enhanced OKE cluster or create one. It creates the Virtual Node pool and prompts for new or existing FSS and MySQL prerequisites. Creating a MySQL DB System incurs service charges.

The stack provisions OCI infrastructure. It does not install the WordPress Helm release.

## Deploy WordPress

The included [WordPress Helm chart](https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress/tree/main/helm/wordpress-virtual-fss) creates the FSS StorageClass and PVC when dynamic provisioning is selected. It expects a Kubernetes Secret named `wordpress-db` with `host`, `database`, `username`, and `password` keys.

Clone the repository, review the chart values, then install into its own namespace.

```bash
git clone https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress.git
helm upgrade --install wordpress \
  ./oke-virtual-nodes-fss-wordpress/helm/wordpress-virtual-fss \
  --namespace wordpress --create-namespace \
  --set fss.availabilityDomain='<availability-domain>' \
  --set fss.compartmentOcid='<compartment-ocid>' \
  --set fss.mountTargetSubnetOcid='<mount-target-subnet-ocid>'
```

Use `fss.mode=dynamic-existing-mount-target` and set `fss.mountTargetOcid` when the CSI driver must use an existing mount target. Set `mysql.tls.enabled=true` only after MySQL has been configured to require TLS and the setting has been tested with the application.

## Scale and validate

The chart starts two replicas with required anti-affinity. With only two usable Virtual Nodes, a third replica remains Pending. Expand the Virtual Node topology before increasing replicas or configuring an HPA above the available capacity.

Confirm the deployment before exposing it to users.

```bash
kubectl -n wordpress get pvc,pods,service
kubectl -n wordpress rollout status deployment/wordpress
```

Expect the PVC to be `Bound`, both WordPress pods to be `Ready`, and the LoadBalancer Service to receive an external address. Test an upload and retrieve it through both replicas to confirm shared FSS content. Also verify that WordPress can create and read database content through the MySQL endpoint.

## Production guidance

- Use a highly available MySQL deployment, backups, and restore tests.
- Put database credentials in Vault or an approved secret-delivery system.
- Use TLS for the public endpoint, a DNS name, and TLS for MySQL.
- The chart sets identical pod-level CPU and memory requests and limits, as required for Virtual Nodes. Size them for the workload and cost model.
- Pin the WordPress image to a tested tag or immutable digest.
- A PVC capacity request is required by Kubernetes but does not create a fixed-size FSS filesystem. Plan FSS capacity and cost separately.
- The StorageClass uses `Retain`. Deleting the PVC leaves FSS data behind. Define explicit backup, retention, and cleanup procedures.

## Cleanup

Uninstall the Helm release with `helm uninstall wordpress --namespace wordpress`. Review FSS exports, file systems, mount targets, MySQL DB Systems, and the Resource Manager stack before deleting them. Retained FSS data and MySQL resources can continue to incur charges.

## Conclusion

FSS-backed persistent volumes bring durable shared file storage to OKE Virtual Nodes through standard Kubernetes APIs. Virtual Nodes run the web tier, MySQL stores relational data, and FSS stores shared application files. That combination lets teams evaluate a wider range of stateful, file-oriented workloads without managing worker nodes.
