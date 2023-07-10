data "aws_caller_identity" "current" {}

# Parse json file
locals {
  # Get json
  json = jsondecode(file("../vars/mediaconnect.json"))

  # Get variables
  vpc_cidr            = { for region in local.json.regions : region.region => region.vpc_cidr }
  private_subnet_cidr = { for region in local.json.regions : region.region => region.private_subnet_cidr }
  flows               = { for region in local.json.regions : region.region => region.flows }
}

resource "aws_iam_role" "mediaconnect" {
  name               = "mediaconnect-role"
  path               = "/mediaconnect/"
  assume_role_policy = data.aws_iam_policy_document.mediaconnect-assume-role-policy.json
}

data "aws_iam_policy_document" "mediaconnect-assume-role-policy" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["${data.aws_caller_identity.current.account_id}"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:mediaconnect:*:${data.aws_caller_identity.current.account_id}:flow:*"]
    }

    principals {
      type        = "Service"
      identifiers = ["mediaconnect.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "mediaconnect-attach" {
  role       = aws_iam_role.mediaconnect.name
  policy_arn = aws_iam_policy.mediaconnect-policy.arn
}

resource "aws_iam_policy" "mediaconnect-policy" {
  name        = "mediaconnect-policy"
  description = "VPC access for mediaconnect"
  policy      = data.aws_iam_policy_document.mediaconnect-policy.json
}

data "aws_iam_policy_document" "mediaconnect-policy" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:describeNetworkInterfaces",
      "ec2:describeSecurityGroups",
      "ec2:describeSubnets",
      "ec2:createNetworkInterface",
      "ec2:createNetworkInterfacePermission",
      "ec2:deleteNetworkInterface",
      "ec2:deleteNetworkInterfacePermission",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "mediaconnect-secrets-policy" {
  role       = aws_iam_role.mediaconnect.name
  policy_arn = aws_iam_policy.mediaconnect-secrets-policy.arn
}

resource "aws_iam_policy" "mediaconnect-secrets-policy" {
  name        = "mediaconnect-secrets-policy"
  description = "Secrets manager for mediaconnect"
  policy      = data.aws_iam_policy_document.mediaconnect-secrets-policy.json
}

data "aws_iam_policy_document" "mediaconnect-secrets-policy" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:srt-password*"]

    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
  }
}

# us-east-2 module
module "mediaconnect-useast2" {
  source              = "./mediaconnect"
  private_subnet_cidr = local.private_subnet_cidr["us-east-2"]
  hub_subnet_cidr     = local.private_subnet_cidr["us-east-2"]
  vpc_cidr            = local.vpc_cidr["us-east-2"]
  mediaconnect_role   = aws_iam_role.mediaconnect.arn
  flows               = local.flows["us-east-2"]
  vpc_peer            = null
  spoke_region        = false

  providers = {
    aws = aws.us-east-2
  }
}

# eu-west-2 module
module "mediaconnect-euwest2" {
  source              = "./mediaconnect"
  private_subnet_cidr = local.private_subnet_cidr["eu-west-2"]
  hub_subnet_cidr     = local.private_subnet_cidr["us-east-2"]
  vpc_cidr            = local.vpc_cidr["eu-west-2"]
  mediaconnect_role   = aws_iam_role.mediaconnect.arn
  vpc_peer            = aws_vpc_peering_connection.euwest2.id
  flows               = local.flows["us-east-2"]
  spoke_region        = true

  providers = {
    aws = aws.eu-west-2
  }
}

# Accept peering connection from spokes and create routes

# Accept peering connection from eu-west-2
resource "aws_vpc_peering_connection" "euwest2" {
  vpc_id      = module.mediaconnect-useast2.vpc_id
  peer_vpc_id = module.mediaconnect-euwest2.vpc_id
  peer_region = "eu-west-2"
  auto_accept = false

  tags = {
    Side = "Requester"
  }
}

resource "aws_route_table" "euwest2" {
  vpc_id = module.mediaconnect-useast2.vpc_id

  route {
    cidr_block                = local.private_subnet_cidr["eu-west-2"]
    vpc_peering_connection_id = aws_vpc_peering_connection.euwest2.id
  }
}

resource "aws_route_table_association" "euwest2" {
  subnet_id      = module.mediaconnect-useast2.private_subnet_id
  route_table_id = aws_route_table.euwest2.id
}

# Set password for SRT
resource "aws_secretsmanager_secret" "srt-password" {
  name = "srt-password"
}

resource "random_password" "password" {
  length           = 12
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret_version" "srt-password" {
  secret_id     = aws_secretsmanager_secret.srt-password.id
  secret_string = random_password.password.result
}