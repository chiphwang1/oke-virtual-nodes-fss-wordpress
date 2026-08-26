locals {
  create_cluster = var.cluster_mode == "create"
  create_fss     = var.fss_mode == "create"
  create_mysql   = var.mysql_mode == "create"
  cluster_id     = local.create_cluster ? oci_containerengine_cluster.wordpress[0].id : var.existing_cluster_ocid
}

resource "oci_containerengine_cluster" "wordpress" {
  count              = local.create_cluster ? 1 : 0
  compartment_id     = var.compartment_ocid
  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vcn_id             = var.vcn_ocid
  type               = "ENHANCED_CLUSTER"
  endpoint_config {
    is_public_ip_enabled = var.control_plane_is_public
    subnet_id            = var.control_plane_subnet_ocid
  }
  options {
    service_lb_subnet_ids = [var.load_balancer_subnet_ocid]
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
    admission_controller_options { is_pod_security_policy_enabled = false }
    kubernetes_network_config {
      pods_cidr     = var.pods_cidr
      services_cidr = var.services_cidr
    }
  }
}

resource "oci_containerengine_virtual_node_pool" "wordpress" {
  compartment_id = var.compartment_ocid
  cluster_id     = local.cluster_id
  display_name   = var.virtual_node_pool_name
  size           = var.virtual_node_count
  placement_configurations {
    availability_domain = var.availability_domain
    fault_domain        = [var.fault_domain]
    subnet_id           = var.virtual_node_subnet_ocid
  }
  pod_configuration {
    subnet_id = var.virtual_node_subnet_ocid
    shape     = var.pod_shape
  }
  taints {
    key    = "workload"
    value  = "wordpress"
    effect = "NO_SCHEDULE"
  }
  initial_virtual_node_labels {
    key   = "workload"
    value = "wordpress"
  }
}

resource "oci_file_storage_file_system" "wordpress" {
  count               = local.create_fss ? 1 : 0
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "${var.cluster_name}-wordpress"
}

resource "oci_file_storage_mount_target" "wordpress" {
  count               = local.create_fss && var.create_fss_mount_target ? 1 : 0
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  subnet_id           = var.fss_mount_target_subnet_ocid
  display_name        = "${var.cluster_name}-wordpress"
}

resource "oci_file_storage_export" "wordpress" {
  count          = local.create_fss ? 1 : 0
  export_set_id  = var.create_fss_mount_target ? oci_file_storage_mount_target.wordpress[0].export_set_id : var.existing_fss_export_set_ocid
  file_system_id = oci_file_storage_file_system.wordpress[0].id
  path           = var.fss_export_path
  export_options {
    source                         = var.allowed_pod_cidr
    access                         = "READ_WRITE"
    identity_squash                = "NONE"
    require_privileged_source_port = false
  }
}

resource "oci_mysql_mysql_db_system" "wordpress" {
  count                   = local.create_mysql ? 1 : 0
  availability_domain     = var.availability_domain
  compartment_id          = var.compartment_ocid
  subnet_id               = var.mysql_subnet_ocid
  shape_name              = var.mysql_shape_name
  display_name            = "${var.cluster_name}-wordpress"
  admin_username          = var.mysql_admin_username
  admin_password          = var.mysql_admin_password
  data_storage_size_in_gb = var.mysql_storage_gb
  is_highly_available     = var.mysql_high_availability
}
