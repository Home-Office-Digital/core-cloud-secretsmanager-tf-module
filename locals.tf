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

  # Resolves whether to create the initial version (explicit flag, else inferred from the value).
  create_initial_version = var.create_initial_version != null ? var.create_initial_version : (var.secret_string != null || var.secret_binary != null)
}
