resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.env_name}/rds/${var.db_name}"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.env_name}-rds-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.env_name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.env_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.env_name}-rds-sg"
  description = "Allow PostgreSQL inbound from webserver only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from webserver"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.webserver_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env_name}-rds-sg"
  }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.env_name}-db"
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = var.multi_az
  publicly_accessible     = false
  backup_retention_period = 7

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${var.env_name}-db-final-snapshot"
  deletion_protection       = var.deletion_protection

  tags = {
    Name = "${var.env_name}-db"
  }
}
