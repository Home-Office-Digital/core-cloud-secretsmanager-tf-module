output "secret_arn" {
  description = "The ARN of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_id" {
  description = "The ID of the Secrets Manager secret. For Secrets Manager this is byte-identical to the ARN."
  value       = aws_secretsmanager_secret.this.id
}

output "secret_name" {
  description = "The friendly name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.name
}

output "version_id" {
  description = "The version ID of the seeded initial secret version, or null when no initial value was supplied."
  value       = try(aws_secretsmanager_secret_version.this[0].version_id, null)
}
