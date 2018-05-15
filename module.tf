//
// Module: aws_rds
//

// This template creates the following resources
// - An RDS instance
// - A database subnet group
// - You should want your RDS instance in a VPC

resource "aws_db_instance" "main_rds_instance" {
  identifier          = "${var.rds_instance_identifier}"
  allocated_storage   = "${var.rds_allocated_storage}"
  engine              = "${var.rds_engine_type}"
  engine_version      = "${var.rds_engine_version}"
  instance_class      = "${var.rds_instance_class}"
  name                = "${var.database_name}"
  username            = "${var.database_user}"
  password            = "${var.database_password}"
  snapshot_identifier = "${var.snapshot_identifier}"
  port                = "${var.database_port}"

  # Because we're assuming a VPC, we use this option, but only one SG id
  vpc_security_group_ids = ["${concat(list(aws_security_group.main_db_access.id), var.security_groups)}"]

  # We're creating a subnet group in the module and passing in the name
  db_subnet_group_name = "${aws_db_subnet_group.main_db_subnet_group.name}"
  parameter_group_name = "${aws_db_parameter_group.main_rds_instance.id}"

  backup_retention_period   = "${var.backup_retention_period}"
  final_snapshot_identifier = "${var.rds_instance_identifier}-final-snapshot"

  backup_window      = "00:00-03:00"
  maintenance_window = "Mon:03:30-Mon:06:30"

  # We want the multi-az setting to be toggleable, but off by default
  multi_az            = "${var.rds_is_multi_az}"
  storage_type        = "${var.rds_storage_type}"
  publicly_accessible = "${var.publicly_accessible}"

  # Upgrades
  allow_major_version_upgrade = "${var.allow_major_version_upgrade}"
  auto_minor_version_upgrade  = "${var.auto_minor_version_upgrade}"

  # Snapshots and backups
  skip_final_snapshot   = "${var.skip_final_snapshot}"
  copy_tags_to_snapshot = "${var.copy_tags_to_snapshot}"

  backup_retention_period = "${var.backup_retention_period}"
  backup_window           = "${var.backup_window}"

  tags = "${merge(var.tags, map("Name", format("%s", var.rds_instance_identifier)))}"
}

resource "aws_db_parameter_group" "main_rds_instance" {
  name   = "${var.rds_instance_identifier}-${replace(var.db_parameter_group, ".", "")}-custom-params"
  family = "${var.db_parameter_group}"

  parameter {
    apply_method = "immediate"
    name         = "work_mem"
    value        = "1572864"
  }

  # Example for MySQL
  # parameter {
  #   name = "character_set_server"
  #   value = "utf8"
  # }


  # parameter {
  #   name = "character_set_client"
  #   value = "utf8"
  # }

  tags = "${merge(var.tags, map("Name", format("%s", var.rds_instance_identifier)))}"
}

resource "aws_db_subnet_group" "main_db_subnet_group" {
  name        = "${var.rds_instance_identifier}-subnetgrp"
  description = "RDS subnet group"
  subnet_ids  = ["${var.subnets}"]

  tags = "${merge(var.tags, map("Name", format("%s", var.rds_instance_identifier)))}"
}

# Security groups
resource "aws_security_group" "main_db_access" {
  name        = "${var.rds_instance_identifier}-access"
  description = "Allow access to the database"
  vpc_id      = "${var.rds_vpc_id}"

  tags = "${merge(var.tags, map("Name", format("%s", var.rds_instance_identifier)))}"
}

resource "aws_security_group_rule" "allow_db_access" {
  type = "ingress"

  from_port   = "${var.database_port}"
  to_port     = "${var.database_port}"
  protocol    = "tcp"
  cidr_blocks = ["${var.private_cidr}"]

  security_group_id = "${aws_security_group.main_db_access.id}"
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type = "egress"

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.main_db_access.id}"
}
