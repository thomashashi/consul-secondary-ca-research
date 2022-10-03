terraform {
  cloud {
    organization = "thomashashi-research"

    workspaces {
      name = "consul-secondary-ca-research"
    }
  }
}
