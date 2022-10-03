resource "aws_security_group" "consul" {
  description = "Traffic allowed to bastion host"
  tags        = local.tags
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "external_to_consul" {
  security_group_id = aws_security_group.consul.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["71.27.135.189/32"]
}

resource "aws_security_group_rule" "internal_to_consul_tcp" {
  security_group_id = aws_security_group.consul.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 0
  to_port           = 65535
  cidr_blocks       = ["10.0.0.0/16"]
}

resource "aws_security_group_rule" "internal_to_consul_udp" {
  security_group_id = aws_security_group.consul.id
  type              = "ingress"
  protocol          = "udp"
  from_port         = 0
  to_port           = 65535
  cidr_blocks       = ["10.0.0.0/16"]
}
   
resource "aws_security_group_rule" "consul_out" {
  security_group_id = aws_security_group.consul.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
