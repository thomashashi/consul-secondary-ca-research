# Consul Managed PKI Mounts
path "/sys/mounts" {
  capabilities = [ "read" ]
}

path "/sys/mounts/connect_dc2_root" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "/sys/mounts/connect_dc2_inter" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "/connect_dc2_root/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "/connect_dc2_inter/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
