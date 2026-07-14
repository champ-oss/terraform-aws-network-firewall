provider "aws" {
  region = "us-east-2"
}

module "network-fw-vpc" {
  source                    = "github.com/champ-oss/terraform-aws-vpc.git?ref=v1.0.63-722aa5b"
  name                      = "network-firewall-vpc"
  cidr_block                = "10.0.0.0"
  availability_zones_count  = 1
  tags = {
    purpose = "network-firewall-testing"
  }
}

################ Network Firewall ######################
#create network firewall stateful rule group
resource "aws_networkfirewall_rule_group" "domain-list-stateful-rule-group" {
  name        = "domain-list-stateful-rule-group"
  capacity    = 100
  type        = "STATEFUL"
  rule_group {
    
    stateful_rule_options {
      rule_order = "STRICT_ORDER" # Critical: Must match the policy
    }
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST"]
        targets              = ["google.com"]
      }
    }
  }
}

#Create network firewall policy for above stateful rule group
resource "aws_networkfirewall_firewall_policy" "network-firewall-policy" {
  name        = "network-firewall-policy"
  description = "Network firewall policy for the network firewall"
  firewall_policy {
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateless_default_actions          = ["aws:forward_to_sfe"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.domain-list-stateful-rule-group.arn
    }
  }
}

#Retrieve private subnet from aws account
#data "aws_subnets" "private" {
#  tags = {
#    purpose = "network-firewall-testing"
#    Type    = "Private"
#  }
#}

#Create Network Firewall
resource "aws_networkfirewall_firewall" "network-firewall" {
  name              = "network-firewall"
  vpc_id            = module.network-fw-vpc.vpc_id
  subnet_mapping {
    subnet_id = module.network-fw-vpc.private_subnets_ids[0]
  }
  firewall_policy_arn = aws_networkfirewall_firewall_policy.network-firewall-policy.arn
  tags = {
    Name = "network-firewall"
  }
}

################ EC2 Instances ######################
data "aws_availability_zones" "availability_zones" {
  state = "available"
}


#Create private subnet for ec2 instances
resource "aws_subnet" "ec2-private-subnet" {
  vpc_id            = module.network-fw-vpc.vpc_id
  cidr_block        = "10.0.5.0/24"
  availability_zone = data.aws_availability_zones.availability_zones.names[0]
  tags = {
    Name = "ec2-private-subnet"
  }
}

#Get nat gateway from aws account
#data "aws_nat_gateway" "nat_gateway" {
#  filter {
#    name   = "tag:Name"
#    values = ["network-firewall-vpc-0"]
#  }
#}



#Create route table for private subnet
resource "aws_route_table" "ec2-private-route-table" {
  vpc_id = module.network-fw-vpc.vpc_id
 
  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_networkfirewall_firewall.network-firewall.firewall_status[0].sync_states[0].attachment[0].endpoint_id
  }
 
  tags = {
    Name = "ec2-private-route-table"
  }
}

resource "aws_route_table_association" "ec2-private-route-table-association" {
  subnet_id      = aws_subnet.ec2-private-subnet.id
  route_table_id = aws_route_table.ec2-private-route-table.id
}