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
  }
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
            65:a6:ae:51:30:df:6a:aa:0c:06:7a:2f:e1:24:ed:20:2b:79:0e:ff
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-1iq1vb2.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  3 21:30:02 2022 GMT
            Not After : Sep 30 21:30:32 2032 GMT
        Subject: CN = pri-1iq1vb2.vault.ca.0d2a1c3d.consul
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:36:63:30:fa:b8:91:cd:2d:e6:c8:42:91:c0:c0:
                    c1:fa:ea:68:b9:c3:2d:9b:47:a5:b8:93:52:c6:90:
                    6d:31:21:1e:1b:b6:43:9f:c5:3f:e9:75:e2:13:5a:
                    b6:7c:1d:a4:b8:2c:56:17:0c:a1:1b:bf:dc:ae:b7:
                    31:cc:9a:99:03
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier:
                7D:66:9C:6D:06:D6:DE:40:10:41:06:AF:A4:5F:C0:5C:CD:65:07:2A
            X509v3 Authority Key Identifier:
                keyid:7D:66:9C:6D:06:D6:DE:40:10:41:06:AF:A4:5F:C0:5C:CD:65:07:2A

            X509v3 Subject Alternative Name:
                DNS:pri-1iq1vb2.vault.ca.0d2a1c3d.consul, URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul
    Signature Algorithm: ecdsa-with-SHA256
         30:44:02:20:2b:96:4a:e1:56:f3:da:7c:8a:bd:ad:f0:63:27:
         3d:15:ce:2c:35:97:b9:cd:15:c1:24:ef:a9:b0:d4:22:ac:77:
         02:20:1d:0d:2d:4a:60:e7:71:f4:73:5e:11:58:fb:28:ea:77:
         e2:e2:d9:20:b7:82:35:dc:49:d1:20:60:df:c3:fd:7a
```

3. `jq -r '.Roots[0].IntermediateCerts[0]' dc1-consul-ca-roots.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            6e:f6:26:86:f6:75:15:79:da:cb:76:6b:56:73:b6:a8:f0:3b:f8:86
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-1iq1vb2.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  3 21:30:02 2022 GMT
            Not After : Oct  3 21:30:32 2023 GMT
        Subject: CN = pri-z1zeikz2.vault.ca.0d2a1c3d.consul
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:35:83:c8:96:e8:a4:b3:85:d7:61:52:2e:fa:55:
                    7a:ef:c0:12:76:4b:2c:87:9c:2a:06:50:83:5b:ca:
                    c6:f4:52:fd:74:c8:f7:aa:ab:63:cb:86:e9:aa:c9:
                    a3:44:c7:ea:41:f3:55:90:0a:fe:3d:b0:75:45:92:
                    30:4d:47:17:a5
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier:
                BD:56:DB:5E:54:1E:1A:03:42:68:3F:CD:53:86:A2:8B:85:47:7E:B2
            X509v3 Authority Key Identifier:
                keyid:7D:66:9C:6D:06:D6:DE:40:10:41:06:AF:A4:5F:C0:5C:CD:65:07:2A

            X509v3 Subject Alternative Name:
                DNS:pri-z1zeikz2.vault.ca.0d2a1c3d.consul, URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:20:53:16:51:27:7f:f2:67:0b:b5:65:f4:d4:ad:ba:
         75:82:46:39:2b:c0:c1:cc:c4:b1:76:ef:a7:de:6f:64:6a:7e:
         02:21:00:c4:7d:26:96:61:72:2a:40:19:8f:23:a8:05:3b:7f:
         9e:df:93:8d:02:e7:91:39:0c:31:5e:c8:69:9b:c4:0b:05
```

4. `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/leaf/service-a > dc1-service-a-certs.json`
5. `jq -r '.CertPEM' dc1-service-a-certs.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            1f:0d:d8:e0:6c:63:dc:cd:ee:c9:50:57:16:bb:41:f3:1c:47:84:b1
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-z1zeikz2.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  3 21:34:46 2022 GMT
            Not After : Oct  6 21:35:16 2022 GMT
        Subject:
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:df:d0:b9:fe:af:0c:db:44:10:40:88:6c:79:6f:
                    f4:54:8f:b7:ee:54:ea:b8:dc:f5:34:9c:0c:b0:89:
                    3d:ac:ea:ad:78:34:2d:31:e2:a2:fd:b7:25:0d:f1:
                    72:ab:32:7b:2c:2a:f9:52:43:c9:2b:59:83:d0:c7:
                    89:bd:6f:ae:10
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Extended Key Usage:
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Subject Key Identifier:
                2D:0D:13:15:14:95:74:69:8F:2B:A8:06:36:D9:7E:2B:DA:E1:52:D6
            X509v3 Authority Key Identifier:
                keyid:BD:56:DB:5E:54:1E:1A:03:42:68:3F:CD:53:86:A2:8B:85:47:7E:B2

            X509v3 Subject Alternative Name: critical
                URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul/ns/default/dc/dc1/svc/service-a
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:20:0d:50:11:00:45:00:36:1e:8b:9e:92:f9:10:00:
         35:3e:67:e9:48:99:0a:56:c1:0f:54:0d:6d:6c:c5:57:f3:40:
         02:21:00:e5:35:c2:fb:81:70:e5:1d:57:cb:df:33:6c:9c:a9:
         c2:05:08:0f:2b:bd:90:0a:74:45:88:f4:c7:15:a3:58:a4
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
5. `consul join -wan 10.0.255.202`

# get certs for dc2

1. `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/roots > dc2-consul-ca-roots.json`
2. `jq -r '.Roots[0].RootCert' dc2-consul-ca-roots.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            65:a6:ae:51:30:df:6a:aa:0c:06:7a:2f:e1:24:ed:20:2b:79:0e:ff
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-1iq1vb2.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  3 21:30:02 2022 GMT
            Not After : Sep 30 21:30:32 2032 GMT
        Subject: CN = pri-1iq1vb2.vault.ca.0d2a1c3d.consul
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:36:63:30:fa:b8:91:cd:2d:e6:c8:42:91:c0:c0:
                    c1:fa:ea:68:b9:c3:2d:9b:47:a5:b8:93:52:c6:90:
                    6d:31:21:1e:1b:b6:43:9f:c5:3f:e9:75:e2:13:5a:
                    b6:7c:1d:a4:b8:2c:56:17:0c:a1:1b:bf:dc:ae:b7:
                    31:cc:9a:99:03
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                7D:66:9C:6D:06:D6:DE:40:10:41:06:AF:A4:5F:C0:5C:CD:65:07:2A
            X509v3 Authority Key Identifier: 
                keyid:7D:66:9C:6D:06:D6:DE:40:10:41:06:AF:A4:5F:C0:5C:CD:65:07:2A

            X509v3 Subject Alternative Name: 
                DNS:pri-1iq1vb2.vault.ca.0d2a1c3d.consul, URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul
    Signature Algorithm: ecdsa-with-SHA256
         30:44:02:20:2b:96:4a:e1:56:f3:da:7c:8a:bd:ad:f0:63:27:
         3d:15:ce:2c:35:97:b9:cd:15:c1:24:ef:a9:b0:d4:22:ac:77:
         02:20:1d:0d:2d:4a:60:e7:71:f4:73:5e:11:58:fb:28:ea:77:
         e2:e2:d9:20:b7:82:35:dc:49:d1:20:60:df:c3:fd:7a
```

3. `jq -r '.Roots[0].IntermediateCerts[1]' dc2-consul-ca-roots.json | openssl x509 -noout -text`

**Note* it's `IntermediateCerts[1]` here to get the intermediates for dc2
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            17:d5:b3:e6:07:7c:c9:06:ba:80:cb:3e:cc:dd:dc:7c:37:03:2b:f6
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = pri-1iq1vb2.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  3 21:48:32 2022 GMT
            Not After : Oct  3 21:49:02 2023 GMT
        Subject: CN = sec-1of9y0b.vault.ca.0d2a1c3d.consul
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:46:6c:78:61:e9:80:f1:79:df:0c:53:d2:57:27:
                    47:51:13:e3:f9:c0:d9:d1:0c:f2:4a:be:bf:d8:65:
                    b6:ec:78:25:55:81:ce:cb:a9:c6:52:5e:a7:f7:cf:
                    b5:94:57:79:a2:5d:73:47:a9:fa:2d:03:5f:6b:1d:
                    14:00:3f:40:2a
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:0
            X509v3 Subject Key Identifier: 
                AB:B5:8F:BD:83:FB:2E:EF:D3:04:F5:D5:42:B4:8D:53:87:CF:83:BE
            X509v3 Authority Key Identifier: 
                keyid:7D:66:9C:6D:06:D6:DE:40:10:41:06:AF:A4:5F:C0:5C:CD:65:07:2A

            X509v3 Subject Alternative Name: 
                DNS:sec-1of9y0b.vault.ca.0d2a1c3d.consul, URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:20:13:6c:20:d5:d4:81:78:51:7a:f1:d5:32:ee:b3:
         37:02:f1:ed:14:1e:47:da:6e:27:d8:72:35:02:11:16:3d:88:
         02:21:00:dc:0d:a3:64:ba:18:0f:ee:2d:1f:f7:e4:8a:99:30:
         55:d1:2a:55:36:d4:a7:54:05:d2:f1:5d:50:42:bc:fb:4f
```

4. `curl -s http://127.0.0.1:8500/v1/agent/connect/ca/leaf/service-b > dc2-service-b-certs.json`
5. `jq -r '.CertPEM' dc2-service-b-certs.json | openssl x509 -noout -text`

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            6b:24:d4:a6:59:04:e5:6b:c0:98:bd:e7:b0:b8:0a:2a:07:e1:4a:76
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = sec-1of9y0b.vault.ca.0d2a1c3d.consul
        Validity
            Not Before: Oct  3 21:52:40 2022 GMT
            Not After : Oct  6 21:53:10 2022 GMT
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
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Extended Key Usage:
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Subject Key Identifier:
                6D:19:54:12:92:5C:5F:D0:C5:36:5A:69:52:BD:70:86:72:37:70:4F
            X509v3 Authority Key Identifier:
                keyid:AB:B5:8F:BD:83:FB:2E:EF:D3:04:F5:D5:42:B4:8D:53:87:CF:83:BE

            X509v3 Subject Alternative Name: critical
                URI:spiffe://0d2a1c3d-ca26-3383-a0d9-152f5ca233b3.consul/ns/default/dc/dc2/svc/service-b
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:20:41:f4:af:c2:5f:f1:9e:70:90:9e:eb:fe:26:6c:
         a0:d4:2e:8e:c0:b4:c5:0e:80:d2:bd:2b:f8:c6:07:d4:ac:8e:
         02:21:00:d4:3a:dc:59:c1:a2:c4:ae:ce:75:f9:ed:2b:d1:99:
         6d:b0:eb:26:a9:4d:59:5f:b5:a6:02:a5:ea:61:7b:b2:23
```

# analysis

Looking at the pcap from the DC2 consul server, we see this request go to the DC2 Vault server:

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
