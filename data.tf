data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "availability_zones" {}

data "aws_acm_certificate" "issued" {
  domain   = var.magento["mage_domain"]
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "subnet_ids" {
   vpc_id = data.aws_vpc.default.id
}

data "aws_security_group" "security_group" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}

data "aws_ami" "ubuntu_2004" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"]
  }
}

