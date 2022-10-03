resource "aws_instance" "consul-server-0-dc2" {
  ami           = data.aws_ami.debian.id
  instance_type = "t3.micro"

  key_name                    = "thomas-yubikey"
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.consul.id]

  user_data_base64 = "${data.template_cloudinit_config.consul-server-0-dc2-config.rendered}"

  tags = merge({ Name = "consul-server-0-dc2" }, local.tags)
}

data "template_file" "consul-server-0-dc2-config" {
  template = "${file("${path.module}/init.tpl")}"
  vars = {
     hostname = "consul-server-0-dc2"
  }
}

data "template_cloudinit_config" "consul-server-0-dc2-config" {
  gzip          = true 
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = "${data.template_file.consul-server-0-dc2-config.rendered}"
  }
}

output "consul-server-0-dc2" {
  value = "admin@${aws_instance.consul-server-0-dc2.public_dns}"
}

resource "aws_instance" "consul-client-0-dc2" {
  ami           = data.aws_ami.debian.id
  instance_type = "t3.micro"

  key_name                    = "thomas-yubikey"
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.consul.id]

  user_data_base64 = "${data.template_cloudinit_config.consul-client-0-dc2-config.rendered}"

  tags = merge({ Name = "consul-client-0-dc2" }, local.tags)
}

data "template_file" "consul-client-0-dc2-config" {
  template = "${file("${path.module}/init.tpl")}"
  vars = {
     hostname = "consul-client-0-dc2"
  }
}

data "template_cloudinit_config" "consul-client-0-dc2-config" {
  gzip          = true 
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = "${data.template_file.consul-client-0-dc2-config.rendered}"
  }
}

output "consul-client-0-dc2" {
  value = "admin@${aws_instance.consul-client-0-dc2.public_dns}"
}
