data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # Debian

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = ["debian-10-amd64-*"]
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.debian.id
  instance_type = "t3.micro"

  key_name                    = "thomas-yubikey"
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]

  tags = merge({ Name = "thomas-bastion" }, local.tags)
}

output "bastion" {
  value = "admin@${aws_instance.bastion.public_dns}"
}

resource "aws_security_group" "bastion" {
  description = "Traffic allowed to bastion host"
  tags        = local.tags
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "external_to_bastion" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["71.27.135.179/32"]
}

resource "aws_security_group_rule" "bastion_to_external" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
