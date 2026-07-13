provider "aws" {
  region = "us-east-2"
}

module "networkd-fw-vpc" {
  source                    = "github.com/champ-oss/terraform-aws-vpc.git?ref=v1.0.63-722aa5b"
  name                      = "network-firewall-vpc"
  cidr_block                = "10.0.0.0"
  availability_zones_count  = 1
  tags = {
    purpose = "network-firewall-testing"
  }
}