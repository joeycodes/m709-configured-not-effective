variable "subscription_id" {
  type        = string
  description = "Azure subscription the observability layer deploys into."

  # Not a secret: a subscription ID grants nothing on its own. Kept in
  # version control so a clean clone deploys to the right place with no
  # local setup.
  default = "23f19e67-5d24-4e37-9258-707daef49af0"
}

variable "location" {
  type        = string
  description = "The location for the observability layer must be the same as the lab. Flow logs require the storage account and VNet to be in the same region."
  default     = "canadaeast"
}

variable "project" {
  type        = string
  description = "Project name, applied as a tag to every resource."
  default     = "configured-not-effective"
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain logs."
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "must be between 30 and 730 days."
  }
  default = 90
}

variable "daily_quota_gb" {
  type        = number
  description = "Daily quota for log ingestion, in GB."
  validation {
    condition     = var.daily_quota_gb > 0 && var.daily_quota_gb <= 5
    error_message = "must be greater than 0 and at most 5 GB."
  }
  default = 1
}