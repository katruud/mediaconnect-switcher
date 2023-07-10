## https://medium.com/swlh/creating-an-aws-ecs-cluster-of-ec2-instances-with-terraform-85a10b5cfbe3
## https://engineering.finleap.com/posts/2020-02-20-ecs-fargate-terraform/

######### DATA SOURcES #########

data "aws_region" "current" {}

data "aws_vpc" "media_dev" {
  id = var.vpc_id
}

locals {
  raw_data       = jsondecode(file("taskdefinition.json"))
  container_name = local.raw_data[0].name
}

######### ECR REPOSITORY #########

resource "aws_ecr_repository" "flask-webapp" {
  name = "flask-webapp"
}

resource "aws_ecr_lifecycle_policy" "flask-webapp" {
  repository = aws_ecr_repository.flask-webapp.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
}

########## ECS SERVICE ##########

resource "aws_ecs_cluster" "cluster" {
  name = "ecs-cluster"
}

resource "aws_ecs_task_definition" "service" {
  family                   = "service"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = 768
  memory                   = 768
  container_definitions    = file("taskdefinition.json")
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_ecs_service" "flask_webapp" {
  name            = "flask-webapp"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs" {
  cluster_name = aws_ecs_cluster.cluster.name
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 1
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.flask_webapp.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = "capacity-provider-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
  }
}

resource "aws_cloudwatch_log_group" "flask_webapp" {
  name = "awslogs-nginx-ecs"
}
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [var.thumbprint]
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_repo]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
  }
}

########## IAM ##########

resource "aws_iam_role" "github_actions" {
  name               = "github_actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions.json
}

resource "aws_iam_role_policy_attachment" "ecs_role" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_role" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "ecs_task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json
}

data "aws_iam_policy_document" "ecs_task" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# EC2 IAM

data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name               = "ecs_agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs_agent"
  role = aws_iam_role.ecs_agent.name
}

########## NETWORKING ##########

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = data.aws_vpc.media_dev.id
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = data.aws_vpc.media_dev.id
  cidr_block = var.public_subnet_cidr
}

resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.media_dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ecs_sg" {
  vpc_id      = data.aws_vpc.media_dev.id
  name = "ecs_security_group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########## EC2 ##########

data "aws_ami" "amazon-linux-2023-ECS" {
  most_recent = true
  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-2023*"]
  }
}

resource "aws_launch_template" "ecs_launch" {
  name = "ecs_launch"

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_agent.arn
  }

  image_id = data.aws_ami.amazon-linux-2023-ECS.id

  instance_type = "t4g.small"

  network_interfaces {
    network_interface_id = aws_network_interface.public_ip.id
  }


  user_data = filebase64("${path.module}/userdata.sh")

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "ecs_instance"
    }
  }
}

resource "aws_network_interface" "public_ip" {
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.ecs_sg.id]
}

resource "aws_eip" "public_ip" {
  network_interface = aws_network_interface.public_ip.id
}

resource "aws_autoscaling_group" "ecs_asg" {
  name               = "ecs_asg"
  availability_zones = ["us-east-2a"]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1

  launch_template {
    id      = aws_launch_template.ecs_launch.id
    version = "$Latest"
  }
}

########## ROUTE53 ##########

data "aws_route53_zone" "primary" {
  name = "${var.domain}"
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${var.subdomain}.${var.domain}"
  type    = "A"
  ttl     = 60
  records = [aws_eip.public_ip.public_ip]
}