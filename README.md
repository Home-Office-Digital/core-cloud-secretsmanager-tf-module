# core-cloud-secretsmanager-tf-module

A Core Cloud Terraform child module that creates a single AWS Secrets Manager
secret with customer-managed KMS encryption, an optional initial secret version,
an optional generated resource policy for cross-account/cross-service read
access, and optional automatic rotation via a Lambda rotation function. The
module exposes the secret ARN/ID/name and the seeded version ID; it never emits
secret material as an output. Note that an initial value supplied via
`secret_string`/`secret_binary` is written to Terraform state, so protect the
state backend accordingly.

## Overview

The module always creates a single `aws_secretsmanager_secret`. It conditionally
creates an `aws_secretsmanager_secret_version` (when an initial value is
supplied), an `aws_secretsmanager_secret_policy` (when read principals/service
principals or a `policy_override` are supplied), and an
`aws_secretsmanager_secret_rotation` (when `rotation_enabled` is true).

The resource policy is generated from an `aws_iam_policy_document` that grants
the supplied `read_principals` and `read_service_principals` read access
(`secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret`), each
statement scoped to a concrete secret ARN with an account-scoping condition. A
full JSON policy string can be supplied via `policy_override` to replace the
generated policy entirely.

The module is deliberately thin: it owns one logical secret and the
configuration around it (encryption, policy, rotation). It does not manage the
rotation Lambda function itself — the caller supplies an existing Lambda ARN.

> **Secrets Manager vs SSM Parameter Store** — Use this module (Secrets
> Manager) for true secrets that benefit from managed lifecycle: credentials,
> API keys, and database passwords that need **automatic rotation**, a
> **resource policy** for cross-account/cross-service sharing, or native
> integration with RDS/Redshift rotation. Prefer **SSM Parameter Store**
> (`SecureString`) for plain configuration and low-sensitivity values where you
> want lower cost and no rotation: feature flags, endpoints, and non-rotating
> config. Rule of thumb: if it rotates, is shared across accounts, or is a
> credential, it belongs in Secrets Manager; if it is configuration you read at
> boot and rarely change, it belongs in Parameter Store.

### Notes

- `kms_key_id` should normally be a customer-managed key ARN from
  `core-cloud-kms-tf-module`. When null, Secrets Manager uses the account
  default `aws/secretsmanager` key.
- Secret material is never exposed as an output. Callers read the value at
  runtime via the AWS API using the ARN, not through Terraform state.
- `secret_id` and `secret_arn` are equal for Secrets Manager (the id *is* the
  ARN). Both are provided only so callers can wire whichever argument a
  downstream resource expects.
- Rotation in v1.0.0 is **Lambda-based only**. Managed rotation (no customer
  Lambda) is out of scope, and `rotation_lambda_arn` is required whenever
  `rotation_enabled = true`.
- When an initial `secret_string`/`secret_binary` is set, the module seeds only
  the first version and then ignores later changes to those inputs
  (`ignore_changes`), so a value that rotation or an out-of-band
  `PutSecretValue` later writes is never reverted. Re-seeding after creation is
  done out of band, not by editing the variable.
- `rotation_rules` attributes `automatically_after_days` and
  `schedule_expression` are mutually exclusive.
- `policy_override` replaces the generated policy entirely; supplied
  `read_principals`/`read_service_principals` are then ignored.

## Requirements

| Name      | Version   |
|-----------|-----------|
| terraform | >= 1.7.5  |
| aws       | ~> 6.66   |

## Usage

Pin `?ref=` to a released tag. The full feature set documented here (secret,
resource policy and rotation) is available from `1.0.0`; check the repository's
tags for the latest release before pinning.

```hcl
module "secret" {
  source = "git::https://github.com/Home-Office-Digital/core-cloud-secretsmanager-tf-module.git?ref=1.0.0"

  name        = "my-service/db-password"
  description = "Database password for my-service"

  # Optional: encrypt with a customer-managed key (ARN from core-cloud-kms-tf-module)
  # kms_key_id = module.kms.key_arn

  # Optional: seed an initial value (ignored on later applies)
  # secret_string = jsonencode({ username = "svc", password = "change-me" })

  # Optional: grant read access to specific IAM principals. For a Lambda to read
  # the secret, grant its execution role here (requests use the role, not the
  # lambda.amazonaws.com service principal).
  # read_principals = ["arn:aws:iam::123456789012:role/my-service-lambda-role"]

  # read_service_principals grants the service principal itself, which suits
  # service-to-service integrations (for example RDS rotation), not a Lambda
  # function reading the secret from its own code.
  # read_service_principals = ["monitoring.rds.amazonaws.com"]

  # Optional: enable Lambda-based rotation
  # rotation_enabled    = true
  # rotation_lambda_arn = "arn:aws:lambda:eu-west-2:123456789012:function:rotate"
  # rotation_rules = {
  #   automatically_after_days = 30
  # }

  cc_tags = {
    cost_centre      = "CC001"
    account_code     = "AC001"
    portfolio_id     = "PF001"
    project_id       = "PR001"
    service_id       = "SV001"
    environment_type = "production"
    owner_business   = "my-business-owner"
    budget_holder    = "my-budget-holder"
  }
}
```

## Providers

| Name | Version |
|------|---------|
| aws  | ~> 6.66 |

## Resources

| Name | Type |
|------|------|
| `aws_secretsmanager_secret.this` | resource |
| `aws_secretsmanager_secret_version.this` | resource |
| `aws_secretsmanager_secret_policy.this` | resource |
| `aws_secretsmanager_secret_rotation.this` | resource |
| `aws_caller_identity.current` | data source |
| `aws_partition.current` | data source |
| `aws_iam_policy_document.secret` | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `name` | Friendly name of the Secrets Manager secret. Also used as the secret description when `description` is null. | `string` | n/a | yes |
| `cc_tags` | Core Cloud mandatory tagging object. Each attribute is mapped to its hyphenated tag key and applied to the secret. | `object({ cost_centre = string, account_code = string, portfolio_id = string, project_id = string, service_id = string, environment_type = string, owner_business = string, budget_holder = string })` | n/a | yes |
| `description` | Human-readable description applied to the secret. When `null` the module falls back to `name`. | `string` | `null` | no |
| `kms_key_id` | KMS key ID, ARN, or alias used to encrypt the secret. When `null` the account default `aws/secretsmanager` key is used. | `string` | `null` | no |
| `recovery_window_in_days` | Days Secrets Manager waits before permanently deleting the secret. `0` for immediate deletion, otherwise `7`–`30` inclusive. | `number` | `30` | no |
| `secret_string` | Initial plaintext value for the first secret version. Mutually exclusive with `secret_binary`. | `string` | `null` | no |
| `secret_binary` | Initial base64-encoded binary value for the first secret version. Mutually exclusive with `secret_string`. | `string` | `null` | no |
| `rotation_enabled` | Whether automatic rotation of the secret is enabled. Requires `rotation_lambda_arn`. | `bool` | `false` | no |
| `rotation_lambda_arn` | ARN of an existing Lambda rotation function. Required when `rotation_enabled` is `true`. | `string` | `null` | no |
| `rotation_rules` | Rotation schedule (`automatically_after_days`, `schedule_expression`, `duration`). `automatically_after_days` and `schedule_expression` are mutually exclusive. | `object({ automatically_after_days = optional(number), schedule_expression = optional(string), duration = optional(string) })` | `null` | no |
| `policy_override` | Full JSON resource policy string. When set to a non-empty string this replaces the generated policy entirely. | `string` | `null` | no |
| `read_principals` | List of IAM ARNs granted `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` in the generated policy. | `list(string)` | `[]` | no |
| `read_service_principals` | List of AWS service principals (for example `["monitoring.rds.amazonaws.com"]`) granted the same read permissions in the generated policy. For a Lambda reading the secret, grant its execution role via `read_principals` instead, as requests use the role rather than the service principal. | `list(string)` | `[]` | no |
| `extra_tags` | Additional tags applied to the secret. Core Cloud mandatory tags take precedence if keys overlap. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `secret_arn` | The ARN of the Secrets Manager secret. |
| `secret_id` | The ID of the secret (byte-identical to the ARN). |
| `secret_name` | The friendly name of the secret. |
| `version_id` | The version ID of the seeded initial version, or `null` when no initial value was supplied. |
