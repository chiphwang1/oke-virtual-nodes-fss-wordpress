variable "region" { type = string }
variable "compartment_ocid" { type = string }
variable "cluster_mode" { type = string
  default = "existing"
}
variable "existing_cluster_ocid" { type = string default = "" }
variable "cluster_name" { type = string
  default = "wordpress-virtual-fss"
}
variable "kubernetes_version" { type = string
  default = "v1.36.1"
}
variable "vcn_ocid" { type = string default = "" }
variable "control_plane_subnet_ocid" { type = string default = "" }
variable "load_balancer_subnet_ocid" { type = string default = "" }
variable "control_plane_is_public" { type = bool
  default = false
}
variable "pods_cidr" { type = string
  default = "10.244.0.0/16"
}
variable "services_cidr" { type = string
  default = "10.96.0.0/16"
}
variable "availability_domain" { type = string }
variable "virtual_node_subnet_ocid" { type = string }
variable "virtual_node_pool_name" { type = string
  default = "wordpress-virtual-nodes"
}
variable "virtual_node_count" { type = number
  default = 2
}
variable "pod_shape" { type = string
  default = "Pod.Standard.E4.Flex"
}
variable "fss_mode" { type = string
  default = "existing"
}
variable "create_fss_mount_target" { type = bool
  default = true
}
variable "fss_mount_target_subnet_ocid" { type = string default = "" }
variable "existing_fss_export_set_ocid" { type = string default = "" }
variable "fss_export_path" { type = string
  default = "/wordpress"
}
variable "allowed_pod_cidr" { type = string
  default = "10.0.0.0/16"
}
variable "mysql_mode" { type = string
  default = "existing"
}
variable "mysql_subnet_ocid" { type = string default = "" }
variable "mysql_shape_name" { type = string
  default = "MySQL.2"
}
variable "mysql_admin_username" { type = string
  default = "wordpress"
}
variable "mysql_admin_password" { type = string
  default = ""
  sensitive = true
}
variable "mysql_storage_gb" { type = number
  default = 50
}
variable "mysql_high_availability" { type = bool
  default = false
}
variable "existing_mysql_host" { type = string default = "" }
