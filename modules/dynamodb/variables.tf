variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "hash_key" {
  description = "Hash key attribute name"
  type        = string
  default     = "id"
}

variable "hash_key_type" {
  description = "Hash key attribute type (S, N, B)"
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "Hash key type must be S (String), N (Number), or B (Binary)"
  }
}

variable "sort_key" {
  description = "Sort key attribute name (optional)"
  type        = string
  default     = "rv_id"
}

variable "sort_key_type" {
  description = "Sort key attribute type (S, N, B) - only if sort_key is set"
  type        = string
  default     = "N"

  validation {
    condition     = contains(["S", "N", "B"], var.sort_key_type)
    error_message = "Sort key type must be S (String), N (Number), or B (Binary)"
  }
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for the table"
  type        = bool
  default     = true
}

variable "enable_ttl" {
  description = "Enable TTL (Time To Live) for the table"
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "Name of the attribute to use for TTL"
  type        = string
  default     = "expiration_time"
}

variable "tags" {
  description = "Tags to apply to the table"
  type        = map(string)
  default     = {}
}

