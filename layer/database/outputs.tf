output "db_system_id" {
  value = oci_mysql_mysql_db_system.main.id
}

output "db_private_ip" {
  value = oci_mysql_mysql_db_system.main.ip_address
}

output "db_port" {
  value = oci_mysql_mysql_db_system.main.port
}

output "db_mysql_version" {
  value = oci_mysql_mysql_db_system.main.mysql_version
}