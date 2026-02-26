# --- ECS Auto Scaling ---

# ============================================================================
# App Service Auto Scaling
# ============================================================================
resource "aws_appautoscaling_target" "app" {
  max_capacity       = var.app_max_capacity
  min_capacity       = var.app_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "app_cpu" {
  name               = "${var.project_name}-app-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "app_alb_requests" {
  name               = "${var.project_name}-app-alb-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value       = 100.0 # Requests per target per minute
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ============================================================================
# Agent Service Auto Scaling
# ============================================================================
resource "aws_appautoscaling_target" "agent" {
  max_capacity       = var.agent_max_capacity
  min_capacity       = var.agent_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.agent.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "agent_cpu" {
  name               = "${var.project_name}-agent-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.agent.resource_id
  scalable_dimension = aws_appautoscaling_target.agent.scalable_dimension
  service_namespace  = aws_appautoscaling_target.agent.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60.0 # Lower threshold - agent is CPU intensive
    scale_in_cooldown  = 300
    scale_out_cooldown = 30 # Scale out faster for responsiveness
  }
}

resource "aws_appautoscaling_policy" "agent_memory" {
  name               = "${var.project_name}-agent-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.agent.resource_id
  scalable_dimension = aws_appautoscaling_target.agent.scalable_dimension
  service_namespace  = aws_appautoscaling_target.agent.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ============================================================================
# MCP Service Auto Scaling
# ============================================================================
resource "aws_appautoscaling_target" "mcp" {
  max_capacity       = var.mcp_max_capacity
  min_capacity       = var.mcp_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.mcp.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "mcp_cpu" {
  name               = "${var.project_name}-mcp-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.mcp.resource_id
  scalable_dimension = aws_appautoscaling_target.mcp.scalable_dimension
  service_namespace  = aws_appautoscaling_target.mcp.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ============================================================================
# AI Gateway Auto Scaling
# ============================================================================
resource "aws_appautoscaling_target" "aigateway" {
  max_capacity       = var.aigateway_max_capacity
  min_capacity       = var.aigateway_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.aigateway.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "aigateway_cpu" {
  name               = "${var.project_name}-aigateway-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.aigateway.resource_id
  scalable_dimension = aws_appautoscaling_target.aigateway.scalable_dimension
  service_namespace  = aws_appautoscaling_target.aigateway.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ============================================================================
# Scheduled Scaling (Optional - for predictable traffic patterns)
# ============================================================================

# Scale down agent at night (10 PM UTC)
resource "aws_appautoscaling_scheduled_action" "agent_scale_down_night" {
  count              = var.enable_scheduled_scaling ? 1 : 0
  name               = "${var.project_name}-agent-scale-down-night"
  service_namespace  = aws_appautoscaling_target.agent.service_namespace
  resource_id        = aws_appautoscaling_target.agent.resource_id
  scalable_dimension = aws_appautoscaling_target.agent.scalable_dimension
  schedule           = "cron(0 22 * * ? *)" # 10 PM UTC daily

  scalable_target_action {
    min_capacity = 1
    max_capacity = 2
  }
}

# Scale up agent in morning (6 AM UTC)
resource "aws_appautoscaling_scheduled_action" "agent_scale_up_morning" {
  count              = var.enable_scheduled_scaling ? 1 : 0
  name               = "${var.project_name}-agent-scale-up-morning"
  service_namespace  = aws_appautoscaling_target.agent.service_namespace
  resource_id        = aws_appautoscaling_target.agent.resource_id
  scalable_dimension = aws_appautoscaling_target.agent.scalable_dimension
  schedule           = "cron(0 6 * * ? *)" # 6 AM UTC daily

  scalable_target_action {
    min_capacity = var.agent_min_capacity
    max_capacity = var.agent_max_capacity
  }
}
