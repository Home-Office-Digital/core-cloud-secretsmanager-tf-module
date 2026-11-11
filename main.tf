# CKV2_AWS_57 (rotation) is advisory: rotation is opt-in, so this soft-fail finding persists by design. Clear it via a repo exception in core-cloud-cve-exemptions (exemptions/checkov/repo-exceptions.json), not by forcing rotation here.
resource "aws_secretsmanager_secret" "this" {
  name                    = var.name
  description             = local.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.extra_tags, local.common_tags)
}
