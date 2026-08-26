variable "region" {
  description = "OCI region for the stack."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment that contains the OKE and FSS resources."
  type        = string
}

variable "cluster_mode" {
  description = "Create an Enhanced cluster or add the Virtual Node pool to an existing cluster."
  type        = string
  default     = "existing"
}

variable "existing_cluster_ocid" {
  description = "OCID of the existing Enhanced OKE cluster."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Name used for newly created resources."
  type        = string
  default     = "wordpress-virtual-fss"
}

variable "kubernetes_version" {
  description = "Kubernetes version for a newly created OKE cluster."
  type        = string
  default     = "v1.36.1"
}

variable "vcn_ocid" {
  description = "OCID of the VCN for a newly created cluster."
  type        = string
  default     = ""
}

variable "control_plane_subnet_ocid" {
  description = "OCID of the API endpoint subnet for a newly created cluster."
  type        = string
  default     = ""
}

variable "load_balancer_subnet_ocid" {
  description = "OCID of the load balancer subnet for a newly created cluster."
  type        = string
  default     = ""
}

variable "control_plane_is_public" {
  description = "Whether a newly created cluster has a public Kubernetes API endpoint."
  type        = bool
  default     = false
}

variable "pods_cidr" {
  description = "Pod CIDR for a newly created cluster."
  type        = string
  default     = "10.244.0.0/16"
}

variable "services_cidr" {
  description = "Service CIDR for a newly created cluster."
  type        = string
  default     = "10.96.0.0/16"
}

variable "availability_domain" {
  description = "Availability domain used for virtual nodes and a newly created FSS file system."
  type        = string
}

variable "fault_domain" {
  description = "Fault domain used for the Virtual Node pool placement."
  type        = string
}

variable "virtual_node_subnet_ocid" {
  description = "Subnet OCID used by the Virtual Node pool and its pods."
  type        = string
}

variable "virtual_node_pool_name" {
  description = "Display name of the Virtual Node pool."
  type        = string
  default     = "wordpress-virtual-nodes"
}

variable "virtual_node_count" {
  description = "Number of Virtual Nodes to create."
  type        = number
  default     = 2
}

variable "pod_shape" {
  description = "OCI pod shape used by the Virtual Node pool."
  type        = string
  default     = "Pod.Standard.E4.Flex"
}

variable "fss_mode" {
  description = "Create an FSS file system and export, or use existing FSS infrastructure."
  type        = string
  default     = "existing"
}

variable "create_fss_mount_target" {
  description = "Create a mount target when creating FSS resources."
  type        = bool
  default     = true
}

variable "fss_mount_target_subnet_ocid" {
  description = "Subnet OCID for a newly created FSS mount target."
  type        = string
  default     = ""
}

variable "existing_fss_export_set_ocid" {
  description = "Export-set OCID used when adding an export to an existing mount target."
  type        = string
  default     = ""
}

variable "fss_export_path" {
  description = "FSS export path."
  type        = string
  default     = "/wordpress"
}

variable "allowed_pod_cidr" {
  description = "CIDR permitted to mount the FSS export."
  type        = string
  default     = "10.0.0.0/16"
}

variable "mysql_mode" {
  description = "Create a MySQL DB System or use an existing reachable MySQL endpoint."
  type        = string
  default     = "existing"
}

variable "mysql_subnet_ocid" {
  description = "Subnet OCID for a newly created MySQL DB System."
  type        = string
  default     = ""
}

variable "mysql_shape_name" {
  description = "Shape of a newly created MySQL DB System."
  type        = string
  default     = "MySQL.2"
}

variable "mysql_admin_username" {
  description = "Administrator username for a newly created MySQL DB System."
  type        = string
  default     = "wordpress"
}

variable "mysql_admin_password" {
  description = "Administrator password for a newly created MySQL DB System."
  type        = string
  default     = ""
  sensitive   = true
}

variable "mysql_storage_gb" {
  description = "Storage allocation in GB for a newly created MySQL DB System."
  type        = number
  default     = 50
}

variable "mysql_high_availability" {
  description = "Enable high availability on a newly created MySQL DB System."
  type        = bool
  default     = false
}

variable "existing_mysql_host" {
  description = "Existing MySQL host and port, for example mysql.internal.example.com:3306."
  type        = string
  default     = ""
}
