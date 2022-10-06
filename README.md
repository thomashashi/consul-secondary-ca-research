# dc1 vault configuration

## `/etc/vault.d/vault.hcl`

```
ui = true
storage "file" {
  path = "/opt/vault/data"
}
# HTTP listener
listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = 1
}
```

## setup

1. `sudo install -o vault -g vault -m 2750 -d /opt/vault`
2. `sudo install -o vault -g vault -m 2750 -d /opt/vault/data`
3. `sudo systemctl enable vault.service`
4. `sudo systemctl start vault.service`
5. `export VAULT_ADDR=http://127.0.0.1:8200`
6. `vault operator init -n 1 -t 1 -format json > dc1-vault-keys.json`
7. `vault operator unseal $(jq -r '.unseal_keys_b64[0]' dc1-vault-keys.json)`
8. `export VAULT_TOKEN=$(jq -r '.root_token' dc1-vault-keys.json )`

## `vault-policy-connect-dc1-ca.hcl`

```
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

# Consul PR 14898
path "/sys/mounts/connect_dc1_inter/tune" {
  capabilities = [ "update" ]
}

path "/connect_dc1_root/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "/connect_dc1_inter/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
```

## policy setup

1. `vault policy write connect-dc1-ca vault-policy-connect-dc1-ca.hcl`
2. `vault token create -policy=connect-dc1-ca -format json > dc1-consul-vault-token.json`

# dc1 consul setup

## `/etc/consul.d/consul.hcl`

```
datacenter = "dc1"
data_dir = "/opt/consul/data"
client_addr = "0.0.0.0"
ui_config{
  enabled = true
}
server = true

bind_addr = "0.0.0.0" # Listen on all IPv4
bootstrap_expect=1
connect {
  enabled = true
  ca_provider = "vault"
  ca_config {
    address = "http://127.0.0.1:8200"
    token = "XXX"
    root_pki_path = "connect_dc1_root"
    intermediate_pki_path = "connect_dc1_inter"
    leaf_cert_ttl = "1h"
    root_cert_ttl = "6h"
    intermediate_cert_ttl = "3h"
  }
}
ports {
  grpc = 8502
}
```

## start tcpdump

1. `sudo tcpdump -i lo -s0 -w dc1-consul.pcap port 8500 or port 8300 or port 8200`

## setup

1. `sudo install -o consul -g consul -m 2750 -d /opt/consul`
2. `sudo install -o consul -g consul -m 2750 -d /opt/consul/data`
3. `sudo systemctl enable consul.service`
4. `sudo systemctl start consul.service`

# get certs for dc1

1. `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/roots > dc1-consul-ca-roots.json`
2. `jq -r '.Roots[0].RootCert' dc1-consul-ca-roots.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            3f:5f:02:48:94:90:b2:8a:1c:b6:d5:1f:15:de:4b:3f:c7:fb:24:11
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-8tp5lllp.vault.ca.ff3d324a.consul
        Validity
            Not Before: Oct  6 20:30:23 2022 GMT
            Not After : Oct  7 02:30:53 2022 GMT
        Subject: CN = pri-8tp5lllp.vault.ca.ff3d324a.consul
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:95:d6:54:53:04:b7:2d:2a:9e:49:e1:be:de:c7:
                    da:9c:a1:29:76:c0:ec:53:e4:7c:bc:12:4b:b7:78:
                    d4:17:97:8c:8e:82:fa:b1:20:3a:bf:4a:e5:45:d4:
                    3d:ec:c6:9b:f3:db:19:18:fb:05:b5:cc:75:fa:82:
                    c5:cb:1b:e2:99
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                15:C1:20:EE:E4:31:05:82:6C:0B:36:B3:93:5E:75:73:19:2F:84:47
            X509v3 Authority Key Identifier: 
                keyid:15:C1:20:EE:E4:31:05:82:6C:0B:36:B3:93:5E:75:73:19:2F:84:47

            X509v3 Subject Alternative Name: 
                DNS:pri-8tp5lllp.vault.ca.ff3d324a.consul, URI:spiffe://ff3d324a-6aeb-c57c-57c9-9ac62fe01f1f.consul
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:20:07:b6:f9:c2:41:44:9c:12:ec:36:82:13:03:42:
         4c:51:cd:dc:b5:5b:3c:9a:7e:a4:3a:cf:e0:58:27:6f:ef:5e:
         02:21:00:8f:43:4f:9e:83:14:72:29:04:8f:cc:a1:41:95:c3:
         6f:da:bb:3b:8e:1c:ac:6a:84:48:3a:e0:8c:2c:66:3c:80
```

3. `jq -r '.Roots[0].IntermediateCerts[0]' dc1-consul-ca-roots.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            4a:77:f8:54:4d:11:1f:71:c7:0e:af:28:e7:b8:47:06:ac:86:2a:46
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-8tp5lllp.vault.ca.ff3d324a.consul
        Validity
            Not Before: Oct  6 20:30:23 2022 GMT
            Not After : Oct  6 23:30:53 2022 GMT
        Subject: CN = pri-gvkobi4.vault.ca.ff3d324a.consul
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:d0:ad:ea:6d:db:6b:34:8f:ee:e0:46:3b:62:fa:
                    dd:04:41:83:d7:a2:5b:4c:96:fd:77:4e:22:67:95:
                    19:e0:68:4e:2d:df:a6:fa:2c:44:09:1b:86:fa:b8:
                    24:40:b5:62:ef:5f:d4:81:bd:c2:61:c8:23:ad:c6:
                    27:cf:e4:60:c6
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                6D:94:08:0E:6D:81:82:1F:47:53:38:78:5D:E5:95:8E:17:ED:45:B8
            X509v3 Authority Key Identifier: 
                keyid:15:C1:20:EE:E4:31:05:82:6C:0B:36:B3:93:5E:75:73:19:2F:84:47

            X509v3 Subject Alternative Name: 
                DNS:pri-gvkobi4.vault.ca.ff3d324a.consul, URI:spiffe://ff3d324a-6aeb-c57c-57c9-9ac62fe01f1f.consul
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:20:30:13:ea:bc:0e:63:77:83:ef:a2:9c:dd:f6:dc:
         1d:13:b5:64:38:ab:a7:62:21:00:2a:ea:6c:fd:ef:5e:7e:26:
         02:21:00:9c:1f:00:17:56:ac:56:e6:63:cf:a4:f6:0d:dc:3d:
         58:32:a1:f8:59:db:79:7d:0a:dc:7e:6d:8c:22:a2:dc:74
```

4. `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/leaf/service-a > dc1-service-a-certs.json`
5. `jq -r '.CertPEM' dc1-service-a-certs.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            6f:f2:3b:4d:6c:e7:fe:f8:f3:7e:15:c2:78:e2:b8:58:f7:3c:0e:c4
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-gvkobi4.vault.ca.ff3d324a.consul
        Validity
            Not Before: Oct  6 20:33:29 2022 GMT
            Not After : Oct  6 21:33:59 2022 GMT
        Subject: 
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:06:b6:3f:8e:04:40:d4:69:e3:4e:07:3f:bb:dd:
                    15:f6:07:88:43:01:2f:57:b4:87:ec:1e:36:d8:60:
                    3e:2f:23:df:12:50:5f:e1:a0:18:a7:16:00:94:b9:
                    24:94:45:74:84:91:4a:c8:d9:c9:56:ae:8a:a3:43:
                    c0:e7:6c:9f:bc
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Subject Key Identifier: 
                5A:2B:3D:B8:44:F2:17:70:EF:C4:DC:1F:FB:F7:95:D2:60:2D:55:99
            X509v3 Authority Key Identifier: 
                keyid:6D:94:08:0E:6D:81:82:1F:47:53:38:78:5D:E5:95:8E:17:ED:45:B8

            X509v3 Subject Alternative Name: critical
                URI:spiffe://ff3d324a-6aeb-c57c-57c9-9ac62fe01f1f.consul/ns/default/dc/dc1/svc/service-a
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:20:7d:44:34:db:98:07:0a:4e:0b:4f:15:37:09:19:
         6c:e6:d5:63:f3:2d:3e:e7:a6:8c:4d:dd:f2:6e:1f:5a:05:18:
         02:21:00:d5:9b:7e:13:de:21:b5:3a:3c:3d:12:dd:cb:74:1e:
         4b:f9:65:e6:2e:b9:cd:f9:a9:02:5b:66:6a:24:3a:6b:5b
```


# dc2 vault configuration

## `/etc/vault.d/vault.hcl`

```
ui = true
storage "file" {
  path = "/opt/vault/data"
}
# HTTP listener
listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = 1
}
```

## setup

1. `sudo install -o vault -g vault -m 2750 -d /opt/vault`
2. `sudo install -o vault -g vault -m 2750 -d /opt/vault/data`
3. `sudo systemctl enable vault.service`
4. `sudo systemctl start vault.service`
5. `export VAULT_ADDR=http://127.0.0.1:8200`
6. `vault operator init -n 1 -t 1 -format json > dc2-vault-keys.json`
7. `vault operator unseal $(jq -r '.unseal_keys_b64[0]' dc2-vault-keys.json)`
8. `export VAULT_TOKEN=$(jq -r '.root_token' dc2-vault-keys.json )`

## `vault-policy-connect-dc2-ca.hcl`

```
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

# Consul PR 14898
path "/sys/mounts/connect_dc2_inter/tune" {
  capabilities = [ "update" ]
}

path "/connect_dc2_root/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "/connect_dc2_inter/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
```

## policy setup

1. `vault policy write connect-dc2-ca vault-policy-connect-dc2-ca.hcl`
2. `vault token create -policy=connect-dc2-ca -format json > dc2-consul-vault-token.json`

# dc2 consul setup

## `/etc/consul.d/consul.hcl`

```
datacenter = "dc2"
primary_datacenter = "dc1"
data_dir = "/opt/consul/data"
client_addr = "0.0.0.0"
ui_config{
  enabled = true
}
server = true

bind_addr = "0.0.0.0" # Listen on all IPv4
bootstrap_expect=1
connect {
  enabled = true
  ca_provider = "vault"
  ca_config {
    address = "http://127.0.0.1:8200"
    token = "XXX"
    root_pki_path = "connect_dc2_root"
    intermediate_pki_path = "connect_dc2_inter"
  }
}
```

## start tcpdump

1. `sudo tcpdump -i lo -s0 -w dc2-consul.pcap port 8500 or port 8300 or port 8200`

## setup

1. `sudo install -o consul -g consul -m 2750 -d /opt/consul`
2. `sudo install -o consul -g consul -m 2750 -d /opt/consul/data`
3. `sudo systemctl enable consul.service`
4. `sudo systemctl start consul.service`
5. `consul join -wan <ip of primary consul server>`

# get certs for dc2

1. `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/roots > dc2-consul-ca-roots.json`
2. `jq -r '.Roots[0].RootCert' dc2-consul-ca-roots.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            3f:5f:02:48:94:90:b2:8a:1c:b6:d5:1f:15:de:4b:3f:c7:fb:24:11
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-8tp5lllp.vault.ca.ff3d324a.consul
        Validity
            Not Before: Oct  6 20:30:23 2022 GMT
            Not After : Oct  7 02:30:53 2022 GMT
        Subject: CN = pri-8tp5lllp.vault.ca.ff3d324a.consul
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:95:d6:54:53:04:b7:2d:2a:9e:49:e1:be:de:c7:
                    da:9c:a1:29:76:c0:ec:53:e4:7c:bc:12:4b:b7:78:
                    d4:17:97:8c:8e:82:fa:b1:20:3a:bf:4a:e5:45:d4:
                    3d:ec:c6:9b:f3:db:19:18:fb:05:b5:cc:75:fa:82:
                    c5:cb:1b:e2:99
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                15:C1:20:EE:E4:31:05:82:6C:0B:36:B3:93:5E:75:73:19:2F:84:47
            X509v3 Authority Key Identifier: 
                keyid:15:C1:20:EE:E4:31:05:82:6C:0B:36:B3:93:5E:75:73:19:2F:84:47

            X509v3 Subject Alternative Name: 
                DNS:pri-8tp5lllp.vault.ca.ff3d324a.consul, URI:spiffe://ff3d324a-6aeb-c57c-57c9-9ac62fe01f1f.consul
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:20:07:b6:f9:c2:41:44:9c:12:ec:36:82:13:03:42:
         4c:51:cd:dc:b5:5b:3c:9a:7e:a4:3a:cf:e0:58:27:6f:ef:5e:
         02:21:00:8f:43:4f:9e:83:14:72:29:04:8f:cc:a1:41:95:c3:
         6f:da:bb:3b:8e:1c:ac:6a:84:48:3a:e0:8c:2c:66:3c:80
```

3. `jq -r '.Roots[0].IntermediateCerts[1]' dc2-consul-ca-roots.json | openssl x509 -noout -text`

**Note** it's `IntermediateCerts[1]` here to get the intermediates for dc2
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            72:06:51:6e:f6:93:5e:d8:37:f1:af:8a:46:20:e5:4a:b3:62:ee:ac
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-8tp5lllp.vault.ca.ff3d324a.consul
        Validity
            Not Before: Oct  6 20:39:49 2022 GMT
            Not After : Oct  6 23:40:19 2022 GMT
        Subject: CN = sec-d5k6jm6.vault.ca.ff3d324a.consul
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:92:4c:87:2f:8e:92:a5:70:16:a3:81:60:a5:7e:
                    cf:a2:3a:b6:ed:60:1b:1c:66:65:06:bc:8a:74:55:
                    de:b0:29:13:fd:e5:d4:93:aa:c3:5a:5e:cc:18:5f:
                    6b:79:0f:23:ea:8b:43:c8:77:be:06:10:bc:2c:49:
                    4f:fd:fa:fc:f5
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:0
            X509v3 Subject Key Identifier: 
                C6:CF:F7:F0:D0:BF:8D:2D:B5:0C:19:FD:D8:96:0D:CA:61:0A:BA:2D
            X509v3 Authority Key Identifier: 
                keyid:15:C1:20:EE:E4:31:05:82:6C:0B:36:B3:93:5E:75:73:19:2F:84:47

            X509v3 Subject Alternative Name: 
                DNS:sec-d5k6jm6.vault.ca.ff3d324a.consul, URI:spiffe://ff3d324a-6aeb-c57c-57c9-9ac62fe01f1f.consul
    Signature Algorithm: ecdsa-with-SHA256
         30:44:02:20:0c:ea:02:7a:33:05:18:84:b9:b2:9c:fc:62:dc:
         a4:e9:75:25:56:6a:f5:d9:38:58:19:94:4f:6c:30:5a:96:5f:
         02:20:05:53:ec:c7:66:3f:68:7a:aa:13:b9:a6:c5:5a:d7:d0:
         dd:36:62:f5:d5:84:b5:d0:e8:46:91:de:80:68:42:bd
```

4. `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/leaf/service-b > dc2-service-b-certs.json`
5. `jq -r '.CertPEM' dc2-service-b-certs.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            7f:98:bc:b0:a0:25:37:90:64:1a:e2:41:cb:65:5d:4a:1b:93:a1:de
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = sec-d5k6jm6.vault.ca.ff3d324a.consul
        Validity
            Not Before: Oct  6 20:43:21 2022 GMT
            Not After : Oct  6 21:43:51 2022 GMT
        Subject: 
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:7e:1a:c5:6b:12:b2:af:7f:da:7e:ca:db:f4:5c:
                    d7:1c:9f:df:8c:75:1d:47:d2:32:dd:13:1c:f1:b5:
                    74:5b:c7:f5:17:00:12:3b:af:94:f4:01:9d:65:a3:
                    3d:4f:89:fc:fb:84:da:cc:29:2e:fb:92:16:7d:ce:
                    00:bd:18:86:8e
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Subject Key Identifier: 
                D0:1C:DE:80:B8:2E:43:27:0D:6B:C3:5C:F1:37:A4:0C:6C:10:AC:92
            X509v3 Authority Key Identifier: 
                keyid:C6:CF:F7:F0:D0:BF:8D:2D:B5:0C:19:FD:D8:96:0D:CA:61:0A:BA:2D

            X509v3 Subject Alternative Name: critical
                URI:spiffe://ff3d324a-6aeb-c57c-57c9-9ac62fe01f1f.consul/ns/default/dc/dc2/svc/service-b
    Signature Algorithm: ecdsa-with-SHA256
         30:46:02:21:00:b8:83:ad:b7:c8:17:5b:10:18:2f:42:7a:6f:
         af:a4:e1:c8:b9:34:3c:5a:82:2a:ac:bb:8b:20:1f:c1:23:00:
         3c:02:21:00:b7:3a:be:bd:85:15:76:f1:ad:2e:58:c1:c8:69:
         0b:99:86:92:d9:08:28:b0:3a:23:38:a1:1d:c9:7e:c3:49:53
```

# Analysis

Looking at the pcap from the DC2 consul server, we see this request go to the DC2 Vault server:

XXX redo

```
PUT /v1/connect_dc2_inter/sign/leaf-cert HTTP/1.1
Host: 127.0.0.1:8200
User-Agent: Go-http-client/1.1
Content-Length: 524
X-Vault-Request: true
X-Vault-Token: XXX
Accept-Encoding: gzip

{"csr":"-----BEGIN CERTIFICATE REQUEST-----\nMIIBLzCB1wIBADAAMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEPEiyr5OqgYE1\nkDDl2kkFWAfD605wvyrzTh9/UP2NsU73NFkQ9/NZk1rlmXG3ncD/CSmnIqlN969r\n7bzUtv6CuKB1MHMGCSqGSIb3DQEJDjFmMGQwYgYDVR0RAQH/BFgwVoZUc3BpZmZl\nOi8vMGQyYTFjM2QtY2EyNi0zMzgzLWEwZDktMTUyZjVjYTIzM2IzLmNvbnN1bC9u\ncy9kZWZhdWx0L2RjL2RjMi9zdmMvc2VydmljZS1iMAoGCCqGSM49BAMCA0cAMEQC\nIEH8RpjYNEPTnzSEOMWAa1BYoKa4RUPyb1QWprVua9mwAiBdTcb7MNoSbzoA4Z4r\nP8NP1NOs+kuv3W45HELj9pBs1g==\n-----END CERTIFICATE REQUEST-----\n","ttl":"72h0m0s"}
```

Pulling that CSR apart we see:

```
Certificate Request:
    Data:
        Version: 0 (0x0)
        Subject:
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:3c:48:b2:af:93:aa:81:81:35:90:30:e5:da:49:
                    05:58:07:c3:eb:4e:70:bf:2a:f3:4e:1f:7f:50:fd:
                    8d:b1:4e:f7:34:59:10:f7:f3:59:93:5a:e5:99:71:
                    b7:9d:c0:ff:09:29:a7:22:a9:4d:f7:af:6b:ed:bc:
                    d4:b6:fe:82:b8
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        Attributes:
        Requested Extensions:
            X509v3 Subject Alternative Name: critical
                URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul/ns/default/dc/dc2/svc/service-b
    Signature Algorithm: ecdsa-with-SHA256
         30:44:02:20:41:fc:46:98:d8:34:43:d3:9f:34:84:38:c5:80:
         6b:50:58:a0:a6:b8:45:43:f2:6f:54:16:a6:b5:6e:6b:d9:b0:
         02:20:5d:4d:c6:fb:30:da:12:6f:3a:00:e1:9e:2b:3f:c3:4f:
         d4:d3:ac:fa:4b:af:dd:6e:39:1c:42:e3:f6:90:6c:d6
```

Vault returns the signed cert:

```
{
  "request_id": "b9a9b6e6-aaea-006f-c159-55c1267afcea",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": {
    "ca_chain": [
      "-----BEGIN CERTIFICATE-----\nMIICLzCCAdWgAwIBAgIUF9Wz5gd8yQa6gMs+zN3cfDcDK/YwCgYIKoZIzj0EAwIw\nLzEtMCsGA1UEAxMkcHJpLTFpcTF2YjIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3Vs\nMB4XDTIyMTAwMzIxNDgzMloXDTIzMTAwMzIxNDkwMlowLzEtMCsGA1UEAxMkc2Vj\nLTFvZjl5MGIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3VsMFkwEwYHKoZIzj0CAQYI\nKoZIzj0DAQcDQgAERmx4YemA8XnfDFPSVydHURPj+cDZ0QzySr6/2GW27HglVYHO\ny6nGUl6n98+1lFd5ol1zR6n6LQNfax0UAD9AKqOBzjCByzAOBgNVHQ8BAf8EBAMC\nAQYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUq7WPvYP7Lu/TBPXVQrSN\nU4fPg74wHwYDVR0jBBgwFoAUfWacbQbW3kAQQQavpF/AXM1lByowZQYDVR0RBF4w\nXIIkc2VjLTFvZjl5MGIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3VshjRzcGlmZmU6\nLy8wZDJhMWMzZC1jYTI2LTMzODMtYTBkOS0xNTJmNWNhMjMzYjMuY29uc3VsMAoG\nCCqGSM49BAMCA0gAMEUCIBNsINXUgXhRevHVMu6zNwLx7RQeR9puJ9hyNQIRFj2I\nAiEA3A2jZLoYD+4tH/fkipkwVdEqVTbUp1QF0vFdUEK8+08=\n-----END CERTIFICATE-----",
      "-----BEGIN CERTIFICATE-----\nMIICKzCCAdKgAwIBAgIUZaauUTDfaqoMBnov4STtICt5Dv8wCgYIKoZIzj0EAwIw\nLzEtMCsGA1UEAxMkcHJpLTFpcTF2YjIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3Vs\nMB4XDTIyMTAwMzIxMzAwMloXDTMyMDkzMDIxMzAzMlowLzEtMCsGA1UEAxMkcHJp\nLTFpcTF2YjIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3VsMFkwEwYHKoZIzj0CAQYI\nKoZIzj0DAQcDQgAENmMw+riRzS3myEKRwMDB+upoucMtm0eluJNSxpBtMSEeG7ZD\nn8U/6XXiE1q2fB2kuCxWFwyhG7/crrcxzJqZA6OByzCByDAOBgNVHQ8BAf8EBAMC\nAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUfWacbQbW3kAQQQavpF/AXM1l\nByowHwYDVR0jBBgwFoAUfWacbQbW3kAQQQavpF/AXM1lByowZQYDVR0RBF4wXIIk\ncHJpLTFpcTF2YjIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3VshjRzcGlmZmU6Ly8w\nZDJhMWMzZC1jYTI2LTMzODMtYTBkOS0xNTJmNWNhMjMzYjMuY29uc3VsMAoGCCqG\nSM49BAMCA0cAMEQCICuWSuFW89p8ir2t8GMnPRXOLDWXuc0VwSTvqbDUIqx3AiAd\nDS1KYOdx9HNeEVj7KOp34uLZILeCNdxJ0SBg38P9eg==\n-----END CERTIFICATE-----"
    ],
    "certificate": "-----BEGIN CERTIFICATE-----\nMIICCDCCAa6gAwIBAgIUayTUplkE5WvAmL3nsLgKKgfhSnYwCgYIKoZIzj0EAwIw\nLzEtMCsGA1UEAxMkc2VjLTFvZjl5MGIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3Vs\nMB4XDTIyMTAwMzIxNTI0MFoXDTIyMTAwNjIxNTMxMFowADBZMBMGByqGSM49AgEG\nCCqGSM49AwEHA0IABDxIsq+TqoGBNZAw5dpJBVgHw+tOcL8q804ff1D9jbFO9zRZ\nEPfzWZNa5Zlxt53A/wkppyKpTfeva+281Lb+grijgdYwgdMwDgYDVR0PAQH/BAQD\nAgOoMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUbRlU\nEpJcX9DFNlppUr1whnI3cE8wHwYDVR0jBBgwFoAUq7WPvYP7Lu/TBPXVQrSNU4fP\ng74wYgYDVR0RAQH/BFgwVoZUc3BpZmZlOi8vMGQyYTFjM2QtY2EyNi0zMzgzLWEw\nZDktMTUyZjVjYTIzM2IzLmNvbnN1bC9ucy9kZWZhdWx0L2RjL2RjMi9zdmMvc2Vy\ndmljZS1iMAoGCCqGSM49BAMCA0gAMEUCIEH0r8Jf8Z5wkJ7r/iZsoNQujsC0xQ6A\n0r0r+MYH1KyOAiEA1DrcWcGixK7OdfntK9GZbbDrJqlNWV+1pgKl6mF7siM=\n-----END CERTIFICATE-----",
    "expiration": 1665093190,
    "issuing_ca": "-----BEGIN CERTIFICATE-----\nMIICLzCCAdWgAwIBAgIUF9Wz5gd8yQa6gMs+zN3cfDcDK/YwCgYIKoZIzj0EAwIw\nLzEtMCsGA1UEAxMkcHJpLTFpcTF2YjIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3Vs\nMB4XDTIyMTAwMzIxNDgzMloXDTIzMTAwMzIxNDkwMlowLzEtMCsGA1UEAxMkc2Vj\nLTFvZjl5MGIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3VsMFkwEwYHKoZIzj0CAQYI\nKoZIzj0DAQcDQgAERmx4YemA8XnfDFPSVydHURPj+cDZ0QzySr6/2GW27HglVYHO\ny6nGUl6n98+1lFd5ol1zR6n6LQNfax0UAD9AKqOBzjCByzAOBgNVHQ8BAf8EBAMC\nAQYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUq7WPvYP7Lu/TBPXVQrSN\nU4fPg74wHwYDVR0jBBgwFoAUfWacbQbW3kAQQQavpF/AXM1lByowZQYDVR0RBF4w\nXIIkc2VjLTFvZjl5MGIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3VshjRzcGlmZmU6\nLy8wZDJhMWMzZC1jYTI2LTMzODMtYTBkOS0xNTJmNWNhMjMzYjMuY29uc3VsMAoG\nCCqGSM49BAMCA0gAMEUCIBNsINXUgXhRevHVMu6zNwLx7RQeR9puJ9hyNQIRFj2I\nAiEA3A2jZLoYD+4tH/fkipkwVdEqVTbUp1QF0vFdUEK8+08=\n-----END CERTIFICATE-----",
    "serial_number": "6b:24:d4:a6:59:04:e5:6b:c0:98:bd:e7:b0:b8:0a:2a:07:e1:4a:76"
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null
}
```

We've already pulled apart the leaf cert above, and saw that `Issuer: CN = sec-1of9y0b.vault.ca.0d2a1c3d.consul` was set. Let's follow the `ca_chain` above:


```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            17:d5:b3:e6:07:7c:c9:06:ba:80:cb:3e:cc:dd:dc:7c:37:03:2b:f6
    Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN=pri-1iq1vb2.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  3 21:48:32 2022 GMT
            Not After : Oct  3 21:49:02 2023 GMT
        Subject: CN=sec-1of9y0b.vault.ca.0d2a1c3d.consul
[... truncated for brevity ...]
```

See that the first entry in the CA chain is the DC2 `intermediate_pki_path` CA. The second entry is:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            65:a6:ae:51:30:df:6a:aa:0c:06:7a:2f:e1:24:ed:20:2b:79:0e:ff
    Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN=pri-1iq1vb2.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  3 21:30:02 2022 GMT
            Not After : Sep 30 21:30:32 2032 GMT
        Subject: CN=pri-1iq1vb2.vault.ca.0d2a1c3d.consul
[... truncated for brevity ...]
```

See that the second entry is the *DC1* `root_pki_path`.

At no point did DC2 ever use it's configured `root_pki_path` --- it is, after all, a secondary DC, and it only has an intermediary cert, which is signed by the DC1, primary, datacenter root cert. Also importantly, in DC2 the Consul server delegated signing of certificates to its CA provider, in this case, a local Vault cluster. And in fact, when DC2 Consul asks the local Vault cluster to create the `connect_dc2_inter` intermediate certificate, it calls `/v1/connect_dc2_inter/intermediate/generate/internal`, which means *Vault cannot export the keying material*. 

And when DC2 generated its intermediate cert, it asked DC1 to sign it, which did the following:

```
PUT /v1/connect_dc1_root/root/sign-intermediate HTTP/1.1
Host: 127.0.0.1:8200
User-Agent: Go-http-client/1.1
Content-Length: 660
X-Vault-Request: true
X-Vault-Token: XXX
Accept-Encoding: gzip

{"csr":"-----BEGIN CERTIFICATE REQUEST-----\nMIIBZDCCAQkCAQAwLzEtMCsGA1UEAxMkc2VjLTFvZjl5MGIudmF1bHQuY2EuMGQy\nYTFjM2QuY29uc3VsMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAERmx4YemA8Xnf\nDFPSVydHURPj+cDZ0QzySr6/2GW27HglVYHOy6nGUl6n98+1lFd5ol1zR6n6LQNf\nax0UAD9AKqB4MHYGCSqGSIb3DQEJDjFpMGcwZQYDVR0RBF4wXIIkc2VjLTFvZjl5\nMGIudmF1bHQuY2EuMGQyYTFjM2QuY29uc3VshjRzcGlmZmU6Ly8wZDJhMWMzZC1j\nYTI2LTMzODMtYTBkOS0xNTJmNWNhMjMzYjMuY29uc3VsMAoGCCqGSM49BAMCA0kA\nMEYCIQCp8ADqA0K89DOKLhTMm91RXEsmW9jfEXF379efyORrzgIhAKi+V1QAQtYi\nJt8YohWfkT/NNhJzFhsVpnyjElKtyhzE\n-----END CERTIFICATE REQUEST-----\n","format":"pem_bundle","max_path_length":0,"ttl":"8760h0m0s","use_csr_values":true}
```

and what it was asked to sign was:

```
Certificate Request:
    Data:
        Version: 0 (0x0)
        Subject: CN=sec-1of9y0b.vault.ca.0d2a1c3d.consul
	[...]
        Attributes:
        Requested Extensions:
            X509v3 Subject Alternative Name:
                DNS:sec-1of9y0b.vault.ca.0d2a1c3d.consul, URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul
```

# Cert Lifetime

## `/etc/systemd/system/fake-service-dc1.service`

```
[Unit]
Description=Fake Service DC1
After=network-online.target
[Service]
ExecStart=/usr/local/bin/fake-service
Restart=always
RestartSet=5
Environment="MESSAGE=Hello from DC1"
Environment=NAME=fake-service-dc1
Environment="LISTEN_ADDR=127.0.0.1:8000"
[Install]
WantedBy=multi-user.target
```

## `/etc/systemd/system/fake-service-dc2.service`

```
[Unit]
Description=Fake Service DC2
After=network-online.target
[Service]
ExecStart=/usr/local/bin/fake-service
Restart=always
RestartSet=5
Environment="MESSAGE=Hello from DC2"
Environment=NAME=fake-service-dc2
Environment="LISTEN_ADDR=0.0.0.0:8000"
Environment="UPSTREAM_URIS=http://localhost:9000"
[Install]
WantedBy=multi-user.target
```

## `/etc/systemd/system/fake-service-dc1-sidecar.service`

```
[Unit]
Description=Fake Service DC1 Sidecar
After=network-online.target
Wants=consul.service
[Service]
ExecStart=/usr/bin/consul connect envoy -sidecar-for fake-service-dc1-0 -envoy-binary /usr/local/bin/envoy -- -l debug
Restart=always
RestartSet=5
StartLimitIntervalSec=0
[Install]
WantedBy=multi-user.target
```

## `/etc/systemd/system/fake-service-dc2-sidecar.service`

```
[Unit]
Description=Fake Service DC2 Sidecar
After=network-online.target
Wants=consul.service
[Service]
ExecStart=/usr/bin/consul connect envoy -sidecar-for fake-service-dc2-0 -envoy-binary /usr/local/bin/envoy -- -l debug
Restart=always
RestartSet=5
StartLimitIntervalSec=0
[Install]
WantedBy=multi-user.target
```

## `/etc/consul.d/fake-service-dc1.hcl`

```
service {
  name = "fake-service-dc1"
  id = "fake-service-dc1-0"
  port = 8000
  check = {
    http = "http://localhost:8000/health"
    interval = "5s"
    method = "GET"
    name = "http health check"
    timeout = "2s"
  }
  connect {
    sidecar_service {
    }
  }
}
```

## `/etc/consul.d/fake-service-dc2.hcl`

```
service {
  name = "fake-service-dc2"
  id = "fake-service-dc2-0"
  port = 8000
  check = {
    http = "http://localhost:8000/health"
    interval = "5s"
    method = "GET"
    name = "http health check"
    timeout = "2s"
  }
  connect {
    sidecar_service {
      proxy {
        upstreams = [
	  {
	    destination_name = "fake-service-dc1"
	    datacenter = "dc1"
	    local_bind_port = 9000
	  }
	]
      }
    }
  }
}
```

## Get Envoy

1. `curl -LO https://archive.tetratelabs.io/envoy/download/v1.23.1/envoy-v1.23.1-linux-amd64.tar.xz`
2. `tar -Jxvf envoy-v1.23.1-linux-amd64.tar.xz`
3. `sudo install -m 555 envoy-v1.23.1-linux-amd64/bin/envoy /usr/local/bin/envoy`
4. `rm -rf envoy-v1.23.1-linux-amd64*`

## Setup `fake-service-dc1`

1. `curl -LO https://github.com/nicholasjackson/fake-service/releases/download/v0.24.2/fake_service_linux_amd64.zip`
2. `unzip fake_service_linux_amd64.zip`
3. `rm fake_service_linux_amd64.zip`
4. `sudo install -m 555 fake-service /usr/local/bin/`
5. `rm fake-service`
6. `sudo systemctl daemon-reload`
7. `sudo systemctl enable fake-service-dc1.service`
8. `sudo systemctl start fake-service-dc1.service`
9. `consul reload`
10. `sudo systemctl enable fake-service-dc1-sidecar.service`
11. `sudo systemctl start fake-service-dc1-sidecar.service`

## Setup `fake-service-dc2`

1. `curl -LO https://github.com/nicholasjackson/fake-service/releases/download/v0.24.2/fake_service_linux_amd64.zip`
2. `unzip fake_service_linux_amd64.zip`
3. `rm fake_service_linux_amd64.zip`
4. `sudo install -m 555 fake-service /usr/local/bin/`
5. `rm fake-service`
6. `sudo systemctl daemon-reload`
7. `sudo systemctl enable fake-service-dc2.service`
8. `sudo systemctl start fake-service-dc2.service`
9. `consul reload`
10. `sudo systemctl enable fake-service-dc2-sidecar.service`
11. `sudo systemctl start fake-service-dc2-sidecar.service`


# What happens to intermediates when you restart the cluster?

# Shutting down secondary Vault

1. `sudo systemctl stop vault.service`
2. `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/leaf/service-b > dc2-service-b-certs-novault.json`
3. Note that we get a certificate back, but its the same certificate as we had previously, because the local Vault agent will cache certificates:

```
jq -r .CertPEM dc2-service-b-certs-novault.json | openssl x509 -noout -text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            6b:24:d4:a6:59:04:e5:6b:c0:98:bd:e7:b0:b8:0a:2a:07:e1:4a:76
        Validity
            Not Before: Oct  3 21:52:40 2022 GMT
            Not After : Oct  6 21:53:10 2022 GMT
[...]
            X509v3 Subject Alternative Name: critical
                URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul/ns/default/dc/dc2/svc/service-b
```

4. But if we try for a service not cached locally: `curl -v http://127.0.0.1:8500/v1/agent/connect/ca/leaf/service-c`:

```
* Expire in 0 ms for 6 (transfer 0x55ec3fd8f0f0)
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Expire in 200 ms for 4 (transfer 0x55ec3fd8f0f0)
* Connected to 127.0.0.1 (127.0.0.1) port 8500 (#0)
> GET /v1/agent/connect/ca/leaf/service-c HTTP/1.1
> Host: 127.0.0.1:8500
> User-Agent: curl/7.64.0
> Accept: */*
>
< HTTP/1.1 500 Internal Server Error
< Vary: Accept-Encoding
< X-Consul-Default-Acl-Policy: allow
< Date: Tue, 04 Oct 2022 14:09:08 GMT
< Content-Length: 137
< Content-Type: text/plain; charset=utf-8
<
* Connection #0 to host 127.0.0.1 left intact
error issuing cert: Put "http://127.0.0.1:8200/v1/connect_dc2_inter/sign/leaf-cert": dial tcp 127.0.0.1:8200: connect: connection refused
```

## Cache notes

The cached certificates, if any, are cached on the client agent where the API call was made to `/v1/agent/connect/ca/leaf/:service`, they are **not** cached on the Consul servers. This cache lives in memory. Certificates are unique per-agent, if I get on a client system in dc2 and do `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/leaf/service-b > dc2-client-0-service-b-cert.json`, the cert I get back is:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            2c:3a:b1:98:17:58:15:68:d9:af:d4:d9:e6:60:5c:8d:eb:94:ad:1b
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = sec-1of9y0b.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  4 14:18:48 2022 GMT
            Not After : Oct  7 14:19:18 2022 GMT
[...]
            X509v3 Subject Alternative Name: critical
                URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul/ns/default/dc/dc2/svc/service-b
```

Note that the SPIFFE URI SAN is the same as above, but the serial numbers and validity are different, hence, different certificates.
