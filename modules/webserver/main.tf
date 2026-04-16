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

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.webserver.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "webserver" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.webserver.name
}

resource "aws_security_group" "alb" {
  name        = "${var.instance_name}-alb-sg"
  description = "Allow HTTP and HTTPS inbound traffic to the ALB"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-alb-sg"
  }
}

resource "aws_security_group" "webserver" {
  name        = "${var.instance_name}-sg"
  description = "Allow traffic from ALB and restricted SSH"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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

resource "aws_lb" "webserver" {
  name               = "${var.instance_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.alb_subnet_ids

  tags = {
    Name = "${var.instance_name}-alb"
  }
}

resource "aws_lb_target_group" "webserver" {
  name     = "${var.instance_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  tags = {
    Name = "${var.instance_name}-tg"
  }
}

resource "aws_acm_certificate" "webserver" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name = "${var.instance_name}-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.webserver.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

resource "aws_acm_certificate_validation" "webserver" {
  certificate_arn         = aws_acm_certificate.webserver.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "webserver" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.webserver.dns_name
    zone_id                = aws_lb.webserver.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.webserver.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.webserver.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.webserver.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver.arn
  }
}

resource "aws_launch_template" "webserver" {
  name_prefix   = "${var.instance_name}-"
  image_id      = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.webserver.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.webserver.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.webserver.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.instance_name
    }
  }
}

resource "aws_autoscaling_group" "webserver" {
  name                = "${var.instance_name}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.webserver.arn]

  launch_template {
    id      = aws_launch_template.webserver.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.instance_name}-asg"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.instance_name}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.webserver.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_scaling_target
  }
}

resource "aws_autoscaling_policy" "requests" {
  name                   = "${var.instance_name}-request-scaling"
  autoscaling_group_name = aws_autoscaling_group.webserver.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.webserver.arn_suffix}/${aws_lb_target_group.webserver.arn_suffix}"
    }
    target_value = var.alb_request_scaling_target
  }
}

resource "aws_cloudwatch_log_group" "webserver" {
  name              = "/${var.instance_name}/application"
  retention_in_days = 30

  tags = {
    Name = "${var.instance_name}-logs"
  }
}

resource "aws_sns_topic" "alarms" {
  name = "${var.instance_name}-alarms"

  tags = {
    Name = "${var.instance_name}-alarms"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.instance_name}-cpu-high"
  alarm_description   = "Average CPU utilization exceeded 80%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webserver.name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.instance_name}-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.instance_name}-unhealthy-hosts"
  alarm_description   = "One or more targets in the ALB target group are unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = aws_lb.webserver.arn_suffix
    TargetGroup  = aws_lb_target_group.webserver.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.instance_name}-unhealthy-hosts"
  }
}
