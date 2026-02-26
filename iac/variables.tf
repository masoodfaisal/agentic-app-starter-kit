variable "aws_region" {
  description = "AWS Region"
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name prefix"
  default     = "agentic-app"
}

variable "app_image" {
  description = "Docker image for Application"
  default     = "public.ecr.aws/p7b6k2h9/mod-app:app-starter-0.0.1" # Placeholder
}

variable "agent_image" {
  description = "Docker image for Agent"
  default     = "public.ecr.aws/p7b6k2h9/mod-app:agent-starter-0.0.1" # Placeholder
}

variable "mcp_image" {
  description = "Docker image for MCP Server"
  default     = "public.ecr.aws/p7b6k2h9/mod-app:mcp-starter-0.0.1" # Placeholder
}

variable "milvus_image" {
  description = "Docker image for Milvus Server"
  default     = "public.ecr.aws/p7b6k2h9/mod-app:milvus-starter-0.0.1" # Placeholder
}

variable "aigateway_image" {
  description = "Docker image for AI Gateway"
  default     = "public.ecr.aws/p7b6k2h9/mod-app:aigateway-starter-0.0.1" # Placeholder
}
    
variable "allowed_ip" {
  description = "Your IP address for ALB access (CIDR notation)"
  type        = string
  default     = "15.248.5.29/32"  # e.g., "15.248.5.29/32"
}    


# --- Auto Scaling Variables ---

variable "app_min_capacity" {
  description = "Minimum number of app tasks"
  type        = number
  default     = 1
}

variable "app_max_capacity" {
  description = "Maximum number of app tasks"
  type        = number
  default     = 4
}

variable "agent_min_capacity" {
  description = "Minimum number of agent tasks"
  type        = number
  default     = 1
}

variable "agent_max_capacity" {
  description = "Maximum number of agent tasks"
  type        = number
  default     = 6
}

variable "mcp_min_capacity" {
  description = "Minimum number of MCP tasks"
  type        = number
  default     = 1
}

variable "mcp_max_capacity" {
  description = "Maximum number of MCP tasks"
  type        = number
  default     = 4
}

variable "aigateway_min_capacity" {
  description = "Minimum number of AI Gateway tasks"
  type        = number
  default     = 1
}

variable "aigateway_max_capacity" {
  description = "Maximum number of AI Gateway tasks"
  type        = number
  default     = 4
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling for off-peak hours"
  type        = bool
  default     = false
}
