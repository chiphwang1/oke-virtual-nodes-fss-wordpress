# Running Stateful Workloads on OKE Virtual Nodes with OCI File Storage

OCI Kubernetes Engine, or OKE, Virtual Nodes are a good fit when a team wants Kubernetes without operating worker nodes. OCI handles the worker infrastructure while Kubernetes still schedules the pods.

The hard part used to be application files. A Virtual Node pod can be restarted, replaced, or moved, so anything left only in its container filesystem goes with it. That ruled out a number of otherwise sensible workloads.

FSS-backed persistent volumes change that. A pod can now use durable shared storage through the same Kubernetes PVC workflow used on managed nodes. In the Phoenix test described here, two WordPress pods ran on separate Virtual Nodes, shared one FSS volume for `wp-content`, and used an external MySQL database for site data.

![OKE Virtual Nodes, FSS, and external MySQL architecture](assets/wordpress-virtual-node-fss-architecture.png)

## Deploy this pattern

You can start with the accompanying OCI Resource Manager stack. It presents the infrastructure choices in Terraform and then hands off to the included Helm chart for the application deployment.

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress/archive/refs/heads/main.zip)

The stack prompts for three choices

- **OKE cluster:** use an existing cluster or create a new Enhanced OKE cluster.
- **FSS:** create a new FSS share or use an existing one.
- **External MySQL:** create a new MySQL DB System or connect WordPress to an existing service.

The button opens OCI Resource Manager with the GitHub Terraform package already selected. Review the variables, especially anything that creates a billable MySQL DB System, then run the apply job. When it finishes, use the outputs to configure the Helm chart and install WordPress in the target cluster. The button follows Oracle's [Deploy to Oracle Cloud button guidance](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Tasks/deploybutton.htm).

## Why persistent storage changes the Virtual Node use case

Pods are disposable by design. A pod can be restarted, replaced during a rollout, or rescheduled as the application scales. Anything written only to the container filesystem is therefore not durable.

Before FSS-backed volumes, Virtual Node workloads worked best when they were fully stateless or pushed every bit of state into an external service. That remains a solid design, but it does not help applications that need a shared filesystem for uploads, generated content, artifacts, model files, or a workspace shared by several pods.

OCI FSS fills that gap. Its CSI driver exposes FSS through familiar Kubernetes storage resources

1. A `StorageClass` describes how FSS should be provisioned.
2. A `PersistentVolumeClaim` (PVC) requests storage.
3. Pods mount the claim just like any other Kubernetes volume.

With the `ReadWriteMany` access mode, multiple pods can mount the same filesystem read-write at the same time. The data outlives individual pods and remains available when Virtual Node pods are replaced.

That opens the door to shared application content, build workspaces, CI/CD artifacts, processing pipelines, datasets and checkpoints for ML workflows, and other applications that need a durable shared filesystem without customer-managed worker nodes.

## The WordPress pattern

WordPress makes the split easy to see because it has two kinds of state

| State | Recommended location | Why |
| --- | --- | --- |
| Posts, users, settings, comments, and transactional state | External MySQL | This is relational database state and needs database semantics. |
| Media uploads, themes, plugins, and other `wp-content` files | OCI FSS RWX PVC | Every WordPress replica needs to see the same files. |
| Web-serving compute | OKE Virtual Nodes | Pods can be replaced or scaled without managing worker nodes. |

The WordPress Deployment runs two replicas, and required pod anti-affinity places them on separate Virtual Nodes. An OCI Load Balancer created by a Kubernetes `Service` distributes HTTP traffic to the replicas. Both replicas mount the FSS PVC at `/var/www/html/wp-content` and connect to the same external MySQL database.

FSS is the right solution for shared *files*. It is not a replacement for MySQL. Keep relational data in the database and use FSS for application content that must be identical across replicas.

## What we validated

The Phoenix environment was validated end to end

- Two Virtual Nodes reached `Ready` state.
- The FSS CSI driver dynamically provisioned an RWX PVC from a `StorageClass`.
- Writer and reader pods on different Virtual Nodes shared the same file successfully.
- Two WordPress pods mounted the same PVC and ran on separate Virtual Nodes.
- External MySQL was initialized with the WordPress schema.
- The public WordPress endpoint returned HTTP 200, and an administrator login succeeded.

The first test in Ashburn showed why this check matters. The PVC provisioned and bound, but the Virtual Node runtime rejected the volume mount. The same Kubernetes configuration worked in Phoenix. Validate the feature in the region and tenancy where you intend to run it before treating it as a production dependency.

## Prerequisites

Before deploying this pattern, make sure that you have:

- An OKE Enhanced cluster with a Virtual Node pool.
- A pod subnet and a subnet suitable for the FSS mount target in the same VCN.
- Network rules that allow application pods to reach the FSS mount target and the external MySQL endpoint.
- The FSS CSI driver available in the cluster.
- IAM permissions for the cluster principal to create and manage FSS resources and use the required VCN resources.
- An external MySQL service reachable from the pod subnet.

For dynamic provisioning, a policy similar to the following is required in the target compartment. Scope and refine it for the tenancy's least-privilege standards:

```text
Allow any-user to manage file-family in compartment id <compartment-ocid>
  where request.principal.type = 'cluster'
Allow any-user to use virtual-network-family in compartment id <compartment-ocid>
  where request.principal.type = 'cluster'
```

## Step 1: Create a dynamic FSS StorageClass and PVC

The following example asks the FSS CSI driver to dynamically create the FSS resources. The mount target subnet, availability domain, and compartment must match the deployment environment.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wordpress-fss
provisioner: fss.csi.oraclecloud.com
reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
  availabilityDomain: <availability-domain>
  mountTargetSubnetOcid: <mount-target-subnet-ocid>
  compartmentOcid: <compartment-ocid>
  exportPath: /wordpress
  exportOptions: '[{"source":"10.0.0.0/16","requirePrivilegedSourcePort":false,"access":"READ_WRITE","identitySquash":"NONE"}]'
  encryptInTransit: "false"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-content
  namespace: wordpress
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: wordpress-fss
  resources:
    requests:
      storage: 50Gi
```

Use a CIDR in `exportOptions.source` that covers the pod addresses that need access. In production, constrain this as tightly as the network design permits. `Retain` is a deliberate choice for application content: deleting the PVC does not automatically remove the underlying data. Establish an explicit lifecycle and backup process for retained storage.

Static provisioning is also available when an organization needs to use an existing FSS filesystem and export. In that model, an administrator creates the `PersistentVolume` that references the pre-existing OCI FSS resource, then applications consume it through a PVC. Dynamic provisioning is often simpler for application teams; static provisioning is useful when storage ownership and lifecycle are centralized.

## Step 2: Create the external database secret

Store the MySQL endpoint and credentials in a Kubernetes Secret, ideally sourced from OCI Vault through the organization's approved secret-delivery mechanism. Do not commit database credentials to source control.

```bash
kubectl -n wordpress create secret generic wordpress-db \
  --from-literal=host='<mysql-private-ip>:3306' \
  --from-literal=database='wordpress' \
  --from-literal=username='wordpress' \
  --from-literal=password='<password>'
```

Create the `wordpress` database before deploying the application. The example environment used a short Kubernetes Job with the MySQL client to create the schema. In a production delivery pipeline, database creation and user grants are normally handled through a controlled database migration process.

## Step 3: Deploy WordPress on Virtual Nodes

The key parts of the Deployment are the Virtual Node toleration, anti-affinity, external database variables, and FSS mount:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: wordpress
              topologyKey: kubernetes.io/hostname
      tolerations:
        - key: workload
          operator: Equal
          value: wordpress
          effect: NoSchedule
      containers:
        - name: wordpress
          image: wordpress:6.8.2-apache
          envFrom:
            - secretRef:
                name: wordpress-auth
          env:
            - name: WORDPRESS_DB_HOST
              valueFrom: {secretKeyRef: {name: wordpress-db, key: host}}
            - name: WORDPRESS_DB_NAME
              valueFrom: {secretKeyRef: {name: wordpress-db, key: database}}
            - name: WORDPRESS_DB_USER
              valueFrom: {secretKeyRef: {name: wordpress-db, key: username}}
            - name: WORDPRESS_DB_PASSWORD
              valueFrom: {secretKeyRef: {name: wordpress-db, key: password}}
          volumeMounts:
            - name: wordpress-content
              mountPath: /var/www/html/wp-content
      volumes:
        - name: wordpress-content
          persistentVolumeClaim:
            claimName: wordpress-content
```

Expose the deployment with a `LoadBalancer` Service. The full working manifests for this test are available alongside this post:

- `storage-and-rwx-test.yaml` creates the namespace, dynamic FSS StorageClass, PVC, and cross-node RWX test.
- `mysql-init.yaml` initializes the WordPress database.
- `wordpress.yaml` creates the two-replica deployment, service, PDB, and HPA.

## Step 4: Validate the deployment

Start with Kubernetes status:

```bash
kubectl -n wordpress get pvc,pods,svc -o wide
kubectl -n wordpress rollout status deployment/wordpress
```

The PVC should be `Bound`, both WordPress replicas should be `Running`, and the `LoadBalancer` Service should receive an external IP address.

To prove RWX behavior, schedule a writer and reader on different Virtual Nodes. Have the writer create a file in the PVC and have the reader print it. A successful read confirms that the same FSS data is visible across pods and nodes.

Finally, access the public service, complete the one-time WordPress setup, and test an administrator login. For an application-level storage test, upload media through one replica and verify it remains visible through the load-balanced service after a pod replacement.

## Do clients need to stay on the same pod?

Not for standard WordPress. WordPress authentication is cookie-based, and the two replicas use the same MySQL database, FSS-backed content, and shared WordPress cookie salts. A request can safely reach either pod.

The shared salts are important. Put the eight `WORDPRESS_*_KEY` and `WORDPRESS_*_SALT` values in one Kubernetes Secret and inject the same values into every replica. Do not let each pod generate its own values.

Sticky sessions become relevant only if a plugin, theme, or custom PHP code stores session state in the local pod. The preferred fix is to externalize that state. If stickiness is genuinely required, an OCI Load Balancer Service can use cookie-based session persistence. Do not depend on this with an OCI Network Load Balancer, because cookie session persistence is supported on OCI Load Balancers, not NLBs.

## Production guidance

This pattern is viable for WordPress and other shared-filesystem workloads, but a production implementation should also include:

- **Highly available database:** Run MySQL with an HA topology or use a managed HA database service. Two WordPress pods do not make a single database instance highly available.
- **Backups and restore tests:** Back up MySQL and FSS independently; test restoration, not just backup creation.
- **Secrets management:** Use OCI Vault or an approved external-secrets workflow for database credentials and WordPress salts.
- **TLS and a DNS name:** Terminate TLS with OCI Certificates or an ingress/load-balancer configuration, and do not leave the initial WordPress installer publicly exposed.
- **Observability:** Monitor application errors, database capacity, FSS utilization and throughput, load balancer health, and pod availability.
- **Content change discipline:** RWX enables concurrent access but does not make arbitrary application writes conflict-free. Use release practices that avoid simultaneous plugin/theme updates from multiple replicas.
- **Security and least privilege:** Restrict FSS export options, security rules, and IAM permissions to the minimum required scope.
- **Capacity and cost planning:** Virtual Nodes remove worker-node administration, but FSS, load balancers, database services, egress, and observability still have capacity and cost characteristics to plan for.

## Conclusion

FSS-backed persistent volumes make OKE Virtual Nodes useful for a wider class of applications. Teams can pair serverless Kubernetes compute with durable, shared file storage while retaining the Kubernetes workflow they already know: StorageClass, PVC, and pod volume mounts.

For WordPress, the division of responsibility is clear: Virtual Nodes run the web tier, MySQL owns relational state, and FSS provides shared persistent application content. That architecture preserves the operational simplicity of Virtual Nodes without forcing the application to give up the durable shared filesystem it needs.
