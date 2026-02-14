variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "stage_name" {
  description = "Stage name for deployment"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}

variable "enable_data_trace" {
  description = "Enable data trace logging"
  type        = bool
  default     = false
}

variable "throttling_burst_limit" {
  description = "API throttling burst limit"
  type        = number
  default     = 5000
}

variable "throttling_rate_limit" {
  description = "API throttling rate limit (requests per second)"
  type        = number
  default     = 10000
}

variable "deployment_trigger" {
  description = "Value to trigger redeployment when changed"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
