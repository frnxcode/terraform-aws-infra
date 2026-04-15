data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

resource "aws_key_pair" "webserver" {
  key_name   = "${var.instance_name}-key"
  public_key = var.public_key

  tags = {
    Name = "${var.instance_name}-key"
  }
}

resource "aws_iam_role" "webserver" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.instance_name}-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.webserver.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "webserver" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.webserver.name
}

resource "aws_security_group" "webserver" {
  name        = "${var.instance_name}-sg"
  description = "Allow HTTP, HTTPS, and restricted SSH inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "webserver" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = aws_key_pair.webserver.key_name
  iam_instance_profile   = aws_iam_instance_profile.webserver.name
  vpc_security_group_ids = [aws_security_group.webserver.id]

  tags = {
    Name = var.instance_name
  }
}
