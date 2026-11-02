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



run "recovery_window_default_is_30" {
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
    condition     = aws_secretsmanager_secret.this.recovery_window_in_days == 30
    error_message = "recovery_window_in_days should default to 30."
  }
}

run "recovery_window_zero_is_allowed" {
  command = plan

  variables {
    name                    = "example"
    recovery_window_in_days = 0
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
    condition     = aws_secretsmanager_secret.this.recovery_window_in_days == 0
    error_message = "recovery_window_in_days of 0 should be accepted for immediate deletion."
  }
}

run "recovery_window_invalid_is_rejected" {
  command = plan

  variables {
    name                    = "example"
    recovery_window_in_days = 3
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

  expect_failures = [var.recovery_window_in_days]
}

run "kms_key_id_is_wired" {
  command = plan

  variables {
    name       = "example"
    kms_key_id = "arn:aws:kms:eu-west-2:123456789012:key/11111111-2222-3333-4444-555555555555"
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
    condition     = aws_secretsmanager_secret.this.kms_key_id == "arn:aws:kms:eu-west-2:123456789012:key/11111111-2222-3333-4444-555555555555"
    error_message = "kms_key_id should be wired through to the secret."
  }
}

