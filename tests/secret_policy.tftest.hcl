provider "aws" {
  region                      = "eu-west-2"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
  }
}

override_data {
  target = data.aws_partition.current
  values = {
    partition = "aws"
  }
}

# NOTE: the generated policy document (data.aws_iam_policy_document.secret.json)
# scopes every statement to resources = [aws_secretsmanager_secret.this.arn].
# A Secrets Manager ARN ends in a hyphen plus six random characters that AWS
# assigns at create time, so the ARN — and therefore the whole rendered policy
# JSON — is unknown at plan. These offline plan-time tests therefore assert only
# what is knowable at plan: conditional creation of the policy resource,
# block_public_policy, and the policy_override replacement semantics (the
# override string is a known input). The exact-JSON scoping assertions
# (aws:PrincipalAccount per-principal-set, aws:SourceAccount for service
# principals, and the generated-document equality for the null/empty override
# fallback) are relocated to the integration test root
# (module-testing/secretsmanager) as an apply-time / documented check, because
# they can only be evaluated once the ARN is known. See the task verification.md
# for the exact list of relocated assertions.

run "no_policy_when_no_principals" {
  command = plan

  variables {
    name = "example"
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret_policy.this) == 0
    error_message = "No secret policy should be created when there are no principals and no override."
  }
}

run "policy_created_for_read_principals" {
  command = plan

  variables {
    name            = "example"
    read_principals = ["arn:aws:iam::123456789012:role/reader"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret_policy.this) == 1
    error_message = "A secret policy should be created when read_principals are supplied."
  }

  assert {
    condition     = aws_secretsmanager_secret_policy.this[0].block_public_policy == true
    error_message = "The secret policy should set block_public_policy to true."
  }
}

run "policy_created_for_service_principals" {
  command = plan

  variables {
    name                    = "example"
    read_service_principals = ["lambda.amazonaws.com"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret_policy.this) == 1
    error_message = "A secret policy should be created when read_service_principals are supplied."
  }

  assert {
    condition     = aws_secretsmanager_secret_policy.this[0].block_public_policy == true
    error_message = "The secret policy should set block_public_policy to true."
  }
}

run "cross_account_read_principal_is_accepted" {
  command = plan

  variables {
    name = "example"
    # A reader in a different account (111111111111) than the secret owner
    # (123456789012). Both are AWS documentation placeholder account IDs that the
    # org gitleaks global config allowlists. The module must accept a
    # cross-account read principal and still create the policy resource. The
    # exact aws:PrincipalAccount scoping to the remote account (not the owner) is
    # verified against the rendered policy JSON in the integration test root,
    # because that JSON is unknown at plan (ARN-dependent); see verification.md.
    read_principals = ["arn:aws:iam::111111111111:role/remote-reader"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret_policy.this) == 1
    error_message = "A cross-account read principal should still produce a policy resource."
  }
}

run "policy_override_null_uses_generated" {
  command = plan

  variables {
    name            = "example"
    read_principals = ["arn:aws:iam::123456789012:role/reader"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  # With no override the policy falls back to the generated document. The
  # generated document is unknown at plan (ARN-dependent), so the exact-JSON
  # equality is relocated to the integration root; here we assert the policy
  # resource is created from the generated path (no override supplied).
  assert {
    condition     = length(aws_secretsmanager_secret_policy.this) == 1
    error_message = "With read_principals and no override, the generated policy should still produce a policy resource."
  }
}

run "policy_override_empty_uses_generated" {
  command = plan

  variables {
    name            = "example"
    policy_override = ""
    read_principals = ["arn:aws:iam::123456789012:role/reader"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  # An empty-string override is treated as "no override" and must fall back to
  # the generated document. The fallback target is unknown at plan (ARN), so the
  # exact equality is relocated to the integration root; here we assert the
  # fallback still yields a policy resource (an empty policy would be wrong).
  assert {
    condition     = length(aws_secretsmanager_secret_policy.this) == 1
    error_message = "An empty policy_override should fall back to the generated policy and still produce a policy resource."
  }
}

run "policy_override_nonempty_replaces_generated" {
  command = plan

  variables {
    name = "example"
    # A deliberately restrictive override. If the module ignored the override or
    # merged it with the generated grants, this assertion would fail. The
    # override string is a known input, so this path IS assertable at plan.
    policy_override = "{\"Version\":\"2012-10-17\",\"Id\":\"custom-override\",\"Statement\":[{\"Sid\":\"RootOnly\",\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"arn:aws:iam::123456789012:root\"},\"Action\":\"secretsmanager:GetSecretValue\",\"Resource\":\"*\"}]}"
    # Grants that must NOT appear in the effective policy when overridden.
    read_principals = ["arn:aws:iam::123456789012:role/reader"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = jsonencode(jsondecode(aws_secretsmanager_secret_policy.this[0].policy)) == jsonencode(jsondecode(var.policy_override))
    error_message = "A non-empty policy_override should replace the generated policy entirely."
  }

  assert {
    condition     = !strcontains(aws_secretsmanager_secret_policy.this[0].policy, "AllowAccountRead")
    error_message = "An overridden policy must not include the generated read grant."
  }
}
