output "cluster_ocid" { value = local.cluster_id }
output "virtual_node_pool_ocid" { value = oci_containerengine_virtual_node_pool.wordpress.id }
output "fss_file_system_ocid" { value = try(oci_file_storage_file_system.wordpress[0].id, null) }
output "mysql_host" { value = local.create_mysql ? oci_mysql_mysql_db_system.wordpress[0].ip_address : var.existing_mysql_host }
