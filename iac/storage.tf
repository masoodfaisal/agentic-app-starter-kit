# --- EFS for Milvus Persistence ---
resource "aws_efs_file_system" "milvus_data" {
  creation_token = "${var.project_name}-milvus-data"
  encrypted      = true
  throughput_mode  = "elastic"  

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.project_name}-milvus-data"
  }
}

# Create mount targets in your private subnets
resource "aws_efs_mount_target" "milvus_data_1" {
  file_system_id  = aws_efs_file_system.milvus_data.id
  subnet_id       = aws_subnet.private_1.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "milvus_data_2" {
  file_system_id  = aws_efs_file_system.milvus_data.id
  subnet_id       = aws_subnet.private_2.id
  security_groups = [aws_security_group.efs.id]
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Allow NFS traffic from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}