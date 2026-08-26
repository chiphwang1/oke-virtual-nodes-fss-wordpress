# OKE Virtual Nodes with FSS: WordPress

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/chiphwang1/oke-virtual-nodes-fss-wordpress/archive/refs/heads/main.zip)

WordPress on OKE Virtual Nodes, OCI File Storage (FSS), and external MySQL.

- `blog/` contains the article and architecture image.
- `helm/` contains the application chart.
- `orm/` creates a Virtual Node pool on an existing OKE cluster and optionally creates FSS or MySQL prerequisites.

The stack prompts for new or existing FSS and MySQL. It creates infrastructure only; install the Helm chart afterwards.
