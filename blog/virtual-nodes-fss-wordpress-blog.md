# Build Stateful Kubernetes Applications on OKE Virtual Nodes with OCI File Storage

OCI File Storage, or FSS, persistent volumes are now available for OCI Kubernetes Engine, or OKE, Virtual Nodes. This new capability brings durable shared filesystem storage to the serverless Kubernetes model.

OKE Virtual Nodes let Kubernetes schedule pods while OCI operates the underlying worker infrastructure. Application teams do not need to provision, patch, scale, or maintain worker nodes. Until FSS persistent storage became available, that simplicity made Virtual Nodes best suited to applications that did not need durable local files.

Pods can restart, be replaced, or move as an application scales, so files written only inside a container are not durable. FSS changes that. Virtual Node workloads can now retain shared application files beyond the lifecycle of an individual pod while keeping the operational simplicity of serverless Kubernetes compute.

## From ephemeral pods to durable shared files

FSS integrates with Kubernetes through the familiar PersistentVolume and PersistentVolumeClaim model. An application requests storage with a PVC, and Kubernetes mounts the resulting volume into the pod.

FSS supports the `ReadWriteMany`, or RWX, access mode. Multiple pods can mount the same filesystem for read and write access at the same time. This makes the pattern useful for content services, shared workspaces, build artifacts, data-processing stages, and AI or machine-learning datasets and model artifacts.

The FSS CSI driver supports two approaches. Dynamic provisioning creates the required filesystem resources from the StorageClass and PVC. Static provisioning connects a pre-created FSS filesystem and export through a PersistentVolume. This example uses dynamic provisioning.

## Why WordPress is a useful example

WordPress has two kinds of state that need different homes. Database records belong in MySQL. Uploads, themes, plugins, and other `wp-content` files need a shared filesystem. Separating those responsibilities allows two WordPress replicas to serve the same site.

| State | Location |
| --- | --- |
| Posts, users, settings, and comments | External MySQL |
| Uploads, themes, plugins, and `wp-content` files | FSS RWX volume |
| Web-serving compute | OKE Virtual Nodes |

Both WordPress pods mount the same FSS-backed PVC and connect to the same external MySQL DB System. The Helm chart also supplies identical WordPress authentication keys and salts to each replica, so the load balancer can send a request to either pod without sticky sessions.

## Architecture

An OCI Load Balancer distributes traffic to two WordPress pods in a Virtual Node pool. The pods access shared content through the Kubernetes PVC and PV layer, then the FSS mount target and export. They use a private MySQL endpoint for relational data.

![OKE Virtual Nodes, FSS, and external MySQL architecture](assets/wordpress-virtual-node-fss-architecture-v2.svg)

FSS and its mount target are OCI resources in the VCN, outside the OKE cluster boundary. The application data path is pod to PVC to PV to FSS export. A StorageClass defines how the PVC is provisioned. It is not mounted directly by a pod.

## Deploy the pattern

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress/releases/download/v0.1.1/oke-vn-fss-wordpress-orm.zip)

The Resource Manager stack can use an existing Enhanced OKE cluster or create one. It creates the Virtual Node pool and prompts for new or existing FSS and MySQL prerequisites. Creating a MySQL DB System incurs service charges.

The stack provisions OCI infrastructure. It does not install the application. After the stack completes, use the included [WordPress Helm chart](https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress/tree/main/helm/wordpress-virtual-fss) to deploy WordPress.

The chart expects a Kubernetes Secret named `wordpress-db` with `host`, `database`, `username`, and `password` keys. Review its values, then install it into its own namespace.

```bash
git clone https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress.git
helm upgrade --install wordpress \
  ./oke-virtual-nodes-fss-wordpress/helm/wordpress-virtual-fss \
  --namespace wordpress --create-namespace \
  --set fss.availabilityDomain='<availability-domain>' \
  --set fss.compartmentOcid='<compartment-ocid>' \
  --set fss.mountTargetSubnetOcid='<mount-target-subnet-ocid>'
```

Set `fss.mode=dynamic-existing-mount-target` and provide `fss.mountTargetOcid` when the CSI driver should use an existing mount target. Set `mysql.tls.enabled=true` only after MySQL has been configured to require TLS and the application connection has been tested.

## Validate, scale, and operate

Start by confirming the claim, pods, and load balancer are ready.

```bash
kubectl -n wordpress get pvc,pods,service
kubectl -n wordpress rollout status deployment/wordpress
```

The PVC should be `Bound`, both WordPress pods should be `Ready`, and the LoadBalancer Service should receive an external address. Upload a file and retrieve it through both replicas to confirm that FSS content is shared. Also verify that WordPress can create and read database content through MySQL.

The chart starts two replicas with required anti-affinity. If only two Virtual Nodes are available, a third replica remains Pending. Expand the Virtual Node topology before increasing replicas or configuring an HPA above the available capacity.

For production, use a highly available MySQL deployment, backups, restore tests, Vault or another approved secret-delivery system, TLS, a DNS name, and a tested WordPress image tag or digest. The chart sets identical pod-level CPU and memory requests and limits, which Virtual Nodes require. Size those values for the workload and cost model.

A PVC capacity request is required by Kubernetes, but it does not create a fixed-size FSS filesystem. Plan FSS capacity and cost separately. The example StorageClass uses `Retain`, so deleting the PVC leaves FSS data behind. Define backup, retention, and cleanup procedures before deployment.

## Cleanup

Uninstall the application with `helm uninstall wordpress --namespace wordpress`. Then review the Resource Manager stack, FSS exports, file systems, mount targets, and MySQL DB Systems before deleting them. Retained FSS data and MySQL resources can continue to incur charges.

## Conclusion

FSS-backed persistent volumes are a new capability that extends OKE Virtual Nodes to workloads needing durable shared files. Virtual Nodes run the web tier, MySQL stores relational data, and FSS stores shared application content. Together, they provide a Kubernetes-native way to run file-oriented stateful applications without managing worker nodes.
