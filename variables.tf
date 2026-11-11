variable "name" {
  description = "Friendly name of the Secrets Manager secret. Also used as the secret description when description is null."
  type        = string
}

variable "cc_tags" {
  description = "Core Cloud mandatory tagging object. Each attribute is mapped to its hyphenated tag key and applied to the secret."
  type = object({
    cost_centre      = string
    account_code     = string
    portfolio_id     = string
    project_id       = string
    service_id       = string
    environment_type = string
    owner_business   = string
    budget_holder    = string
  })
  nullable = false
}

variable "description" {
  description = "Human-readable description applied to the secret. When null the module falls back to var.name, so the secret always carries a non-empty description."
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ID, ARN, or alias used to encrypt the secret. When null Secrets Manager uses the account default aws/secretsmanager key. Prefer a customer-managed key ARN from core-cloud-kms-tf-module."
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Number of days Secrets Manager waits before permanently deleting the secret. Use 0 for immediate deletion with no recovery window, otherwise a value between 7 and 30 inclusive."
  type        = number
  default     = 30
  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 (immediate deletion) or between 7 and 30 inclusive."
  }
}

variable "extra_tags" {
  description = "Additional tags applied to the secret. Core Cloud mandatory tags take precedence if keys overlap."
  type        = map(string)
  default     = {}
}
