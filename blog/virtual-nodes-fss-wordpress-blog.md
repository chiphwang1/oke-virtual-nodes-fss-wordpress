# Build Stateful Kubernetes Applications on OKE Virtual Nodes with OCI File Storage

OCI Kubernetes Engine, or OKE, Virtual Nodes offer a serverless Kubernetes experience. Kubernetes schedules pods while OCI operates the underlying worker infrastructure. That model removes the need to provision, patch, scale, or maintain node pools for the application.

For a long time, however, one important question limited which workloads were a good fit. Where does durable application data live when the pod itself is ephemeral?

This pattern combines Virtual Nodes with OCI File Storage, or FSS, for shared WordPress content and an external MySQL DB System for relational data.

Persistent storage is now available for OKE Virtual Nodes, enabling workloads that need durable shared application files.

## What the pattern builds

Two WordPress replicas run in a Virtual Node pool. An OCI Load Balancer sends traffic to the pods. The pods share a ReadWriteMany PVC that is backed by an FSS export and connect to a private MySQL endpoint.

![OKE Virtual Nodes, FSS, and external MySQL architecture](assets/wordpress-virtual-node-fss-architecture-v2.svg)

FSS and its mount target are OCI resources in the VCN, outside the OKE cluster boundary. The application path is pod to PVC to PV to FSS export. A pod does not mount a StorageClass directly.

## Deploy the infrastructure

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress/releases/download/v0.1.1/oke-vn-fss-wordpress-orm.zip)

The Resource Manager stack can use an existing Enhanced OKE cluster or create one. It creates the Virtual Node pool and prompts for new or existing FSS and MySQL prerequisites. Creating a MySQL DB System incurs service charges.

The stack provisions OCI infrastructure only. It does not install a Helm release.

## Deploy WordPress

The [WordPress Helm chart](https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress/tree/main/helm/wordpress-virtual-fss) creates the FSS StorageClass and PVC when dynamic provisioning is selected. It expects a Kubernetes Secret named `wordpress-db` with `host`, `database`, `username`, and `password` keys.

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

The chart creates and retains a Secret containing the shared WordPress authentication keys and salts unless `wordpress.configSecret` names a centrally managed Secret. Every replica uses the same values, so requests can be served by either WordPress pod without session affinity.

## WordPress state separation

| State | Location |
| --- | --- |
| Posts, users, settings, and comments | External MySQL |
| Uploads, themes, plugins, and `wp-content` files | FSS RWX volume |
| Web-serving compute | OKE Virtual Nodes |

FSS is for shared files, not relational database state. MySQL holds the database, and the two WordPress pods mount the same `wp-content` claim.

## Scaling and validation

The chart starts two replicas with required anti-affinity. With only two usable Virtual Nodes, a third replica remains Pending. Expand the Virtual Node topology before increasing replicas or configuring an HPA above the available capacity.

Confirm the deployment before exposing it to users.

```bash
kubectl -n wordpress get pvc,pods,service
kubectl -n wordpress rollout status deployment/wordpress
```

Expect the PVC to be `Bound`, both WordPress pods to be `Ready`, and the LoadBalancer Service to receive an external address. Test an upload and retrieve it through both replicas to confirm shared FSS content. Also verify WordPress can create and read database content through the MySQL endpoint.

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

The practical split is straightforward. Virtual Nodes run the web tier, MySQL stores relational data, and FSS stores shared application files. Validate the capability in the target tenancy and region, then use the Resource Manager stack and Helm chart as separate, deliberate deployment stages.
