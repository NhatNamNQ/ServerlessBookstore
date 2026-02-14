variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "enable_versioning" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = true
}

variable "enable_cors" {
  description = "Enable CORS configuration"
  type        = bool
  default     = false
}

variable "cors_allowed_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "List of allowed methods for CORS"
  type        = list(string)
  default     = ["GET", "PUT", "POST", "DELETE"]
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "List of headers to expose in CORS"
  type        = list(string)
  default     = []
}

variable "cors_max_age_seconds" {
  description = "Max age for CORS preflight requests"
  type        = number
  default     = 3000
}

variable "enable_static_website_hosting" {
  description = "Enable static website hosting on the bucket"
  type        = bool
  default     = false
}

variable "index_document" {
  description = "Name of the index document for static website hosting"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Name of the error document for static website hosting"
  type        = string
  default     = "error.html"
}

variable "enable_public_access" {
  description = "Enable public access to bucket for static website hosting"
  type        = bool
  default     = false
}

variable "bucket_policy_statement" {
  description = "Custom bucket policy statement (optional)"
  type        = any
  default     = null
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}

