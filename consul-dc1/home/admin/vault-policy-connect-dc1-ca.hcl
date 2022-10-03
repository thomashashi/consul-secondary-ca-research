# Consul Managed PKI Mounts
path "/sys/mounts" {
  capabilities = [ "read" ]
}

path "/sys/mounts/connect_dc1_root" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "/sys/mounts/connect_dc1_inter" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "/connect_dc1_root/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "/connect_dc1_inter/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

