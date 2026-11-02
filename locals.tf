locals {
  common_tags = {
    cost-centre      = var.cc_tags.cost_centre
    account-code     = var.cc_tags.account_code
    portfolio-id     = var.cc_tags.portfolio_id
    project-id       = var.cc_tags.project_id
    service-id       = var.cc_tags.service_id
    environment-type = var.cc_tags.environment_type
    owner-business   = var.cc_tags.owner_business
    budget-holder    = var.cc_tags.budget_holder
  }

  # Falls back to the secret name when no description is given.
  description = var.description != null ? var.description : var.name

  # Owning account, used to scope the service-principal condition.
  account_id = data.aws_caller_identity.current.account_id

  # Extracts the account of each read principal for the cross-account scoping condition.
  read_principal_accounts = toset([for arn in var.read_principals : split(":", arn)[4]])

  # Selects the override policy when set, otherwise the generated document.
  effective_policy = var.policy_override != null && var.policy_override != "" ? var.policy_override : data.aws_iam_policy_document.secret.json

  # Resolves whether to attach a policy (explicit flag, else inferred from principals/override).
  create_policy = var.create_policy != null ? var.create_policy : (length(var.read_principals) > 0 || length(var.read_service_principals) > 0 || (var.policy_override != null && var.policy_override != ""))
}
