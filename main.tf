data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Builds the resource policy granting read to the given principals/service principals, scoped to this secret's ARN.
data "aws_iam_policy_document" "secret" {
  dynamic "statement" {
    for_each = length(var.read_principals) > 0 ? [1] : []
    content {
      sid    = "AllowAccountRead"
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      resources = [aws_secretsmanager_secret.this.arn]

      principals {
        type        = "AWS"
        identifiers = var.read_principals
      }

      # Scopes the grant to the supplied principals' own accounts.
      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalAccount"
        values   = local.read_principal_accounts
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.read_service_principals) > 0 ? [1] : []
    content {
      sid    = "AllowServiceRead"
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      resources = [aws_secretsmanager_secret.this.arn]

      principals {
        type        = "Service"
        identifiers = var.read_service_principals
      }

      # Scopes the service grant to the owning account.
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }
    }
  }
}

# CKV2_AWS_57 (rotation) is advisory: rotation is opt-in, so this soft-fail finding persists by design. Clear it via a repo exception in core-cloud-cve-exemptions (exemptions/checkov/repo-exceptions.json), not by forcing rotation here.
resource "aws_secretsmanager_secret" "this" {
  name                    = var.name
  description             = local.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.extra_tags, local.common_tags)

  lifecycle {
    # Reject setting both secret_string and secret_binary.
    precondition {
      condition     = !(var.secret_string != null && var.secret_binary != null)
      error_message = "secret_string and secret_binary are mutually exclusive; set at most one."
    }
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  # Create the version from a plan-known flag so an apply-time value still plans.
  count = local.create_initial_version ? 1 : 0

  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_string
  secret_binary = var.secret_binary

  lifecycle {
    # Seed once, then let rotation own the value and staging labels.
    ignore_changes = [secret_string, secret_binary, version_stages]

    # Require a payload when a version is created.
    precondition {
      condition     = var.secret_string != null || var.secret_binary != null
      error_message = "An initial secret version was requested but no value was supplied; set secret_string or secret_binary (or leave create_initial_version unset / false)."
    }
  }
}

# Attaches the resource policy only when principals or an override are supplied.
resource "aws_secretsmanager_secret_policy" "this" {
  count = (length(var.read_principals) > 0 || length(var.read_service_principals) > 0 || (var.policy_override != null && var.policy_override != "")) ? 1 : 0

  secret_arn          = aws_secretsmanager_secret.this.arn
  policy              = local.effective_policy
  block_public_policy = true
}

# Configures Lambda-based rotation when enabled.
resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.rotation_enabled ? 1 : 0

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = var.rotation_lambda_arn

  dynamic "rotation_rules" {
    for_each = var.rotation_rules != null ? [var.rotation_rules] : []
    content {
      automatically_after_days = rotation_rules.value.automatically_after_days
      schedule_expression      = rotation_rules.value.schedule_expression
      duration                 = rotation_rules.value.duration
    }
  }

  lifecycle {
    # Require a Lambda ARN when rotation is enabled.
    precondition {
      condition     = !var.rotation_enabled || var.rotation_lambda_arn != null
      error_message = "rotation_lambda_arn is required when rotation_enabled is true (v1.0.0 supports Lambda-based rotation only)."
    }
  }
}
