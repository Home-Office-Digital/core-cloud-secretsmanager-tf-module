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
