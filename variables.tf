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

variable "rotation_enabled" {
  description = "Whether automatic rotation of the secret is enabled. When true a rotation_lambda_arn is required."
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "ARN of an existing Lambda rotation function. Required when rotation_enabled is true (v1.0.0 supports Lambda-based rotation only). The required-when-enabled rule is enforced by a precondition on the rotation resource."
  type        = string
  default     = null
  validation {
    condition     = var.rotation_lambda_arn == null ? true : can(regex("^arn:aws[a-z-]*:lambda:", var.rotation_lambda_arn))
    error_message = "rotation_lambda_arn must be a Lambda ARN (arn:aws:lambda:...)."
  }
}

variable "rotation_rules" {
  description = "Rotation schedule for the secret. Maps directly to the rotation_rules block of aws_secretsmanager_secret_rotation. automatically_after_days and schedule_expression are mutually exclusive."
  type = object({
    automatically_after_days = optional(number)
    schedule_expression      = optional(string)
    duration                 = optional(string)
  })
  default = null
}

variable "create_policy" {
  description = "Whether to attach a resource policy. When null the module infers it from whether read_principals/read_service_principals/policy_override are set. Set true to attach a policy whose policy_override is only known at apply time (for example a document referencing a resource created in the same apply), since count cannot depend on an unknown value."
  type        = bool
  default     = null
}

variable "policy_override" {
  description = "Full JSON resource policy string. When set to a non-empty string this REPLACES the generated secret policy entirely."
  type        = string
  default     = null
}

variable "read_principals" {
  description = "List of IAM ARNs granted secretsmanager:GetSecretValue and secretsmanager:DescribeSecret in the generated resource policy."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.read_principals : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:", arn))])
    error_message = "read_principals must be IAM ARNs (arn:aws:iam::<account-id>:...)."
  }
}

variable "read_service_principals" {
  description = "List of AWS service principals (for example monitoring.rds.amazonaws.com) granted the same read permissions in the generated resource policy. For a Lambda reading the secret, grant its execution role via read_principals instead, as requests use the role rather than the service principal."
  type        = list(string)
  default     = []
}

variable "extra_tags" {
  description = "Additional tags applied to the secret. Core Cloud mandatory tags take precedence if keys overlap."
  type        = map(string)
  default     = {}
}
