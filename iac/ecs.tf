# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# --- Service Discovery (Cloud Map) ---
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name        = "internal"
  description = "Internal service discovery namespace"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "app" {
  name = "app"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    # failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "agent" {
  name = "agent"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    # failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "mcp" {
  name = "mcp"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    # failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "milvus" {
  name = "milvus"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    # failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "aigateway" {
  name = "aigateway"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    # failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "jaeger" {
  name = "jaeger"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    # failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "otel" {
  name = "otel"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    # failure_threshold = 1
  }
}

# --- IAM Roles ---
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Execution Role Policy for SSM Parameter Access (for secrets injection) ---
resource "aws_iam_role_policy" "ecs_execution_ssm" {
  name = "${var.project_name}-execution-ssm-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "ssm:GetParameter"]
      Resource = aws_ssm_parameter.aigateway_config.arn
    }]
  })
}

# --- CloudWatch Log Groups ---
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}/app"
  retention_in_days = 1

  tags = {
    Name = "${var.project_name}-app-logs"
  }
}

resource "aws_cloudwatch_log_group" "agent" {
  name              = "/ecs/${var.project_name}/agent"
  retention_in_days = 1

  tags = {
    Name = "${var.project_name}-agent-logs"
  }
}

resource "aws_cloudwatch_log_group" "mcp" {
  name              = "/ecs/${var.project_name}/mcp"
  retention_in_days = 1

  tags = {
    Name = "${var.project_name}-mcp-logs"
  }
}

resource "aws_cloudwatch_log_group" "milvus" {
  name              = "/ecs/${var.project_name}/milvus"
  retention_in_days = 1

  tags = {
    Name = "${var.project_name}-milvus-logs"
  }
}

resource "aws_cloudwatch_log_group" "aigateway" {
  name              = "/ecs/${var.project_name}/aigateway"
  retention_in_days = 1

  tags = {
    Name = "${var.project_name}-aigateway-logs"
  }
}

resource "aws_cloudwatch_log_group" "jaeger" {
  name              = "/ecs/${var.project_name}/jaeger"
  retention_in_days = 1

  tags = {
    Name = "${var.project_name}-jaeger-logs"
  }
}

resource "aws_cloudwatch_log_group" "otel" {
  name              = "/ecs/${var.project_name}/otel-collector"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-otel-logs"
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# --- OTEL Collector IAM Policy for CloudWatch/X-Ray ---
resource "aws_iam_role_policy" "ecs_task_otel" {
  name = "${var.project_name}-otel-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- SSM Parameter Store for AI Gateway Config ---
resource "aws_ssm_parameter" "aigateway_config" {
  name  = "/${var.project_name}/aigateway/config"
  type  = "String"
  value = file("${path.module}/../code/ai-gateway/config.yaml")

  tags = {
    Name = "${var.project_name}-aigateway-config"
  }
}

# --- SSM Read Policy for ECS Tasks ---
resource "aws_iam_role_policy" "ecs_task_ssm" {
  name = "${var.project_name}-ssm-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = aws_ssm_parameter.aigateway_config.arn
    }]
  })
}

# --- Task Definitions ---

# 1. Application
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture      = "ARM64"
    operating_system_family = "LINUX"
  }
  cpu                      = 2048
  memory                   = 8192
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "tmp-volume"
  }

  container_definitions = jsonencode([{
    name      = "app"
    image     = var.app_image
    essential = true
    readonlyRootFilesystem = true

    # Wait for init container to fix /tmp permissions
    dependsOn = [{
      containerName = "init-fs"
      condition     = "SUCCESS"
    }]

    mountPoints = [
      {
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }
    ]
    portMappings = [{
      containerPort = 8501
      hostPort      = 8501
      protocol      = "tcp"
    }]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8501/_stcore/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
    environment = [
      { name = "AGENT_HOST", value = "http://agent.internal:8000" },
      { name = "CHAT_ENDPOINT", value = "http://agent.internal:8000/chat" },
      { name = "THREAD_ID", value = "default" },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://otel.internal:4318/v1/traces" },
      { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "http/protobuf" },
      { name = "HOME", value = "/tmp" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  },
    {
      # Init Container to fix volume permissions
      name      = "init-fs"
      image     = "public.ecr.aws/docker/library/busybox:latest"
      essential = false
      user      = "root"
      command   = ["sh", "-c", "chmod 1777 /tmp"]
      mountPoints = [{
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }]
    } ])
}

# 2. Agent
resource "aws_ecs_task_definition" "agent" {
  family                   = "${var.project_name}-agent"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture      = "ARM64"
    operating_system_family = "LINUX"
  }
  cpu                      = 2048
  memory                   = 8192
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "tmp-volume"
  }

  container_definitions = jsonencode([{
    name      = "agent"
    image     = var.agent_image
    essential = true
    readonlyRootFilesystem = true

    # Wait for init container to fix /tmp permissions
    dependsOn = [{
      containerName = "init-fs"
      condition     = "SUCCESS"
    }]

    mountPoints = [
      {
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }
    ]
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
    environment = [
      { name = "MILVUS_HOST", value = "milvus.internal" },
      { name = "MILVUS_PORT", value = "19530" },
      { name = "OPENAI_API_KEY", value = "sk-123456" },
      { name = "OPENAI_BASE_URL", value = "http://aigateway.internal:4000" },
      { name = "MODEL_NAME", value = "llama-distributed" },
      { name = "MCP_HOST", value = "mcp.internal" },
      { name = "MCP_PORT", value = "8000" },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://otel.internal:4318/v1/traces" },
      { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "http/protobuf" },
      { name = "HOME", value = "/tmp" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.agent.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  },
    {
      # Init Container to fix volume permissions
      name      = "init-fs"
      image     = "public.ecr.aws/docker/library/busybox:latest"
      essential = false
      user      = "root"
      command   = ["sh", "-c", "chmod 1777 /tmp"]
      mountPoints = [{
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }   
  ])
}

# 3. MCP Server
resource "aws_ecs_task_definition" "mcp" {
  family                   = "${var.project_name}-mcp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture      = "ARM64"
    operating_system_family = "LINUX"
  }
  cpu                      = 2048
  memory                   = 8192
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "tmp-volume"
  }

  container_definitions = jsonencode([{
    name      = "mcp"
    image     = var.mcp_image
    essential = true
    readonlyRootFilesystem = true

    # Wait for init container to fix /tmp permissions
    dependsOn = [{
      containerName = "init-fs"
      condition     = "SUCCESS"
    }]

    mountPoints = [
      {
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }
    ]
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8000/sse || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
    environment = [
      { name = "HOME", value = "/tmp" },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://otel.internal:4318/v1/traces" },
      { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "http/protobuf" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mcp.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  },
    {
      # Init Container to fix volume permissions
      name      = "init-fs"
      image     = "public.ecr.aws/docker/library/busybox:latest"
      essential = false
      user      = "root"
      command   = ["sh", "-c", "chmod 1777 /tmp"]
      mountPoints = [{
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }  
  ])
}

# 4. Milvus Server
resource "aws_ecs_task_definition" "milvus" {
  family                   = "${var.project_name}-milvus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture      = "ARM64"
    operating_system_family = "LINUX"
  }
  cpu                      = 2048
  memory                   = 8192
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  ephemeral_storage {
    size_in_gib = 100  # Up to 200GB available, adjust based on your data needs
  }

  
  volume {
    name = "milvus-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.milvus_data.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([{
    name      = "milvus"
    image     = var.milvus_image
    essential = true
    readonlyRootFilesystem = false    

    mountPoints = [
      {
        sourceVolume  = "milvus-data"
        containerPath = "/var/lib/milvus" # Default Milvus data path
        readOnly      = false
      }
    ]
        
    portMappings = [
      {
        containerPort = 19530
        hostPort      = 19530
        protocol      = "tcp"
      },
      {
        containerPort = 9091
        hostPort      = 9091
        protocol      = "tcp"
      }
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:9091/healthz || exit 1"]
      interval    = 30
      timeout     = 10
      retries     = 3
      startPeriod = 90
    }
    environment = [
      { name = "ETCD_USE_EMBED", value = "true" },
      { name = "COMMON_STORAGETYPE", value = "local" },
      { name = "LOG_LEVEL", value = "warn" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.milvus.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# 5. AI Gateway
resource "aws_ecs_task_definition" "aigateway" {
  family                   = "${var.project_name}-aigateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture      = "ARM64"
    operating_system_family = "LINUX"
  }
  cpu                      = 2048
  memory                   = 8192
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "tmp-volume"
  }

  container_definitions = jsonencode([{
    name      = "aigateway"
    image     = var.aigateway_image
    essential = true
    readonlyRootFilesystem = true

    # Wait for init container to fix /tmp permissions
    dependsOn = [{
      containerName = "init-fs"
      condition     = "SUCCESS"
    }]

    mountPoints = [
      {
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }
    ]
    portMappings = [{
      containerPort = 4000
      hostPort      = 4000
      protocol      = "tcp"
    }]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:4000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    # Write config from SSM env var to file, then start litellm
    entryPoint = ["sh", "-c"]
    command    = ["echo \"$CONFIG_CONTENT\" > /tmp/config.yaml && exec litellm --config /tmp/config.yaml --port 4000 --host 0.0.0.0"]

    # ECS injects SSM parameter value as environment variable at task startup
    secrets = [
      {
        name      = "CONFIG_CONTENT"
        valueFrom = aws_ssm_parameter.aigateway_config.arn
      }
    ]

    environment = [
      { name = "OPENAI_API_KEY", value = "sk-123456" },
      { name = "HOME", value = "/tmp" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.aigateway.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  },
    {
      # Init Container to fix volume permissions
      name      = "init-fs"
      image     = "public.ecr.aws/docker/library/busybox:latest"
      essential = false
      user      = "root"
      command   = ["sh", "-c", "chmod 1777 /tmp"]
      mountPoints = [{
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }]
    }  
  ])
}

# resource "aws_ecs_task_definition" "jaeger" {
#   family                   = "${var.project_name}-jaeger"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   runtime_platform {
#     cpu_architecture      = "ARM64" # Jaeger image is usually x86, check if ARM exists. all-in-one supports multi-arch.
#     operating_system_family = "LINUX"
#   }
#   cpu                      = 256
#   memory                   = 512
#   execution_role_arn       = aws_iam_role.ecs_execution_role.arn
#   task_role_arn            = aws_iam_role.ecs_task_role.arn

#   container_definitions = jsonencode([{
#     name      = "jaeger"
#     image     = "jaegertracing/jaeger:2.2.0"
#     essential = true
#     readonlyRootFilesystem = false # Jaeger writes to tmp
#     portMappings = [
#       {
#         containerPort = 16686
#         hostPort      = 16686
#         protocol      = "tcp"
#       },
#       {
#         containerPort = 4317
#         hostPort      = 4317
#         protocol      = "tcp"
#       },
#       {
#         containerPort = 4318
#         hostPort      = 4318
#         protocol      = "tcp"
#       }
#     ]
#     healthCheck = {
#       command     = ["CMD-SHELL", "curl -f http://localhost:16686/ || exit 1"]
#       interval    = 30
#       timeout     = 5
#       retries     = 3
#       startPeriod = 30
#     }
#     environment = [
#       { name = "COLLECTOR_OTLP_ENABLED", value = "true" },
#       # { name = "HOME", value = "/tmp" }
#     ]
#     logConfiguration = {
#       logDriver = "awslogs"
#       options = {
#         "awslogs-group"         = aws_cloudwatch_log_group.jaeger.name
#         "awslogs-region"        = var.aws_region
#         "awslogs-stream-prefix" = "ecs"
#       }
#     }
#   }])
# }

# 7. ADOT Collector (Centralized OpenTelemetry Collector)
resource "aws_ecs_task_definition" "otel_collector" {
  family                   = "${var.project_name}-otel-collector"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }
  cpu                      = 2048
  memory                   = 8192
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "tmp-volume"
  }

  container_definitions = jsonencode([{
    name      = "otel-collector"
    image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
    essential = true
    readonlyRootFilesystem = true

    mountPoints = [
      {
        sourceVolume  = "tmp-volume"
        containerPath = "/tmp"
        readOnly      = false
      }
    ]

    # linuxParameters = {
    #   tmpfs = [
    #     {
    #       containerPath = "/tmp"
    #       size          = 256
    #       mountOptions  = ["rw", "noexec", "nosuid", "nodev"]
    #     }
    #   ]
    # }

    portMappings = [
      { containerPort = 4317, hostPort = 4317, protocol = "tcp" },  # OTLP gRPC
      { containerPort = 4318, hostPort = 4318, protocol = "tcp" }   # OTLP HTTP
    ]

    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      {
        name = "AOT_CONFIG_CONTENT"
        value = yamlencode({
          receivers = {
            otlp = {
              protocols = {
                grpc = { endpoint = "0.0.0.0:4317" }
                http = { endpoint = "0.0.0.0:4318" }
              }
            }
          }
          processors = {
            batch = {
              timeout       = "5s"
              send_batch_size = 256
            }
          }
          exporters = {
            awsxray = {
              region = var.aws_region
            }
          }
          extensions = {
            health_check = {}
          }
          service = {
            extensions = ["health_check"]
            pipelines = {
              traces = {
                receivers  = ["otlp"]
                processors = ["batch"]
                exporters  = ["awsxray"]
              }
            }
          }
        })
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.otel.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "collector"
      }
    }
  }])
}


# --- ECS Services ---

# 1. Application Service (Public via ALB)
resource "aws_ecs_service" "app" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8501
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app.arn
  }
}

# 2. Agent Service (Private)
resource "aws_ecs_service" "agent" {
  name            = "agent-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.agent.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.agent.arn
  }
}

# 3. MCP Service (Private)
resource "aws_ecs_service" "mcp" {
  name            = "mcp-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mcp.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.mcp.arn
  }
}


# 4. Milvus Service (Private)
resource "aws_ecs_service" "milvus" {
  name            = "milvus-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.milvus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.milvus.arn
  }

  depends_on = [
    aws_efs_mount_target.milvus_data_1,
    aws_efs_mount_target.milvus_data_2
  ]
    
}


# 4. AI Gateway Service (Private)
resource "aws_ecs_service" "aigateway" {
  name            = "aigateway-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.aigateway.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.aigateway.arn
  }
}

# resource "aws_ecs_service" "jaeger" {
#   name            = "jaeger-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.jaeger.arn
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
#     security_groups  = [aws_security_group.ecs_tasks.id]
#     assign_public_ip = false
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.jaeger.arn
#     container_name   = "jaeger"
#     container_port   = 16686
#   }

#   service_registries {
#     registry_arn = aws_service_discovery_service.jaeger.arn
#   }
# }

# OTEL Collector Service (Centralized)
resource "aws_ecs_service" "otel_collector" {
  name            = "otel-collector-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.otel_collector.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.otel.arn
  }
}