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

run "no_rotation_by_default" {
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
    condition     = length(aws_secretsmanager_secret_rotation.this) == 0
    error_message = "No rotation resource should be created by default."
  }
}

run "rotation_created_when_enabled_with_lambda" {
  command = plan

  variables {
    name                = "example"
    rotation_enabled    = true
    rotation_lambda_arn = "arn:aws:lambda:eu-west-2:123456789012:function:rotate"
    rotation_rules = {
      automatically_after_days = 30
    }
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
    condition     = length(aws_secretsmanager_secret_rotation.this) == 1
    error_message = "A rotation resource should be created when rotation is enabled with a Lambda ARN."
  }

  assert {
    condition     = aws_secretsmanager_secret_rotation.this[0].rotation_lambda_arn == "arn:aws:lambda:eu-west-2:123456789012:function:rotate"
    error_message = "The rotation Lambda ARN should be wired through."
  }
}

run "rotation_without_lambda_is_rejected" {
  command = plan

  variables {
    name                = "example"
    rotation_enabled    = true
    rotation_lambda_arn = null
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

  expect_failures = [aws_secretsmanager_secret_rotation.this]
}

run "rotation_with_seeded_version_plans_clean" {
  command = plan

  variables {
    name                = "example"
    secret_string       = "seed"
    rotation_enabled    = true
    rotation_lambda_arn = "arn:aws:lambda:eu-west-2:123456789012:function:rotate"
    rotation_rules = {
      automatically_after_days = 30
    }
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
    condition     = length(aws_secretsmanager_secret_version.this) == 1
    error_message = "The seeded version resource should be created alongside rotation."
  }

  assert {
    condition     = length(aws_secretsmanager_secret_rotation.this) == 1
    error_message = "The rotation resource should be created alongside a seeded version."
  }
}
