locals {
  level_1_resources = {
    for resource in flatten([
      for resource_key, child_resource in var.resources : merge(child_resource, {
        child_resource_key = "/${resource_key}"
        path = resource_key
      })
    ]) : resource["child_resource_key"] => resource
  }

  level_2_resources = {
    for resource in flatten([
      for pareant_resource_key, resource in local.level_1_resources : [
        for resource_key, child_resource in lookup(resource, "resources", {}) : merge(child_resource, {
          child_resource_key = "${pareant_resource_key}/${resource_key}"
          path = resource_key
        })
      ]
    ]) : resource["child_resource_key"] => resource
  }

  level_3_resources = {
    for resource in flatten([
      for pareant_resource_key, resource in local.level_2_resources : [
        for resource_key, child_resource in lookup(resource, "resources", {}) : merge(child_resource, {
          child_resource_key = "${pareant_resource_key}/${resource_key}"
          path = resource_key
        })
      ]
    ]) : resource["child_resource_key"] => resource
  }

  level_4_resources = {
    for resource in flatten([
      for pareant_resource_key, resource in local.level_3_resources : [
        for resource_key, child_resource in lookup(resource, "resources", {}) : merge(child_resource, {
          child_resource_key = "${pareant_resource_key}/${resource_key}"
          path = resource_key
        })
      ]
    ]) : resource["child_resource_key"] => resource
  }

  level_5_resources = {
    for resource in flatten([
      for pareant_resource_key, resource in local.level_4_resources : [
        for resource_key, child_resource in lookup(resource, "resources", {}) : merge(child_resource, {
          child_resource_key = "${pareant_resource_key}/${resource_key}"
          path = resource_key
        })
      ]
    ]) : resource["child_resource_key"] => resource
  }
}

resource "aws_api_gateway_rest_api" "this" {
  name = var.name

  endpoint_configuration {
    types = [
      "REGIONAL"
    ]
  }

  tags = var.tags
}

# Authorizers
resource "aws_api_gateway_authorizer" "this" {
  for_each = var.authorizers

  name = each.key
  rest_api_id = aws_api_gateway_rest_api.this.id
  type = each.value["type"]

  provider_arns = each.value["type"] != "COGNITO_USER_POOLS" ? [] : data.aws_cognito_user_pools.this[each.key].arns
}

data "aws_cognito_user_pools" "this" {
  for_each = {
    for key, authorizer in var.authorizers : key => authorizer if authorizer["type"] == "COGNITO_USER_POOLS"
  }

  name = each.value["cognito_pool_name"]
}

# Resources
## Level 1
module "resources_level_1" {
  source = "./resources"

  resources_parents = {
      for key, resource in var.resources : "/${key}" => merge(resource, {
        parent_id = aws_api_gateway_rest_api.this.root_resource_id
    })
  }

  resources = local.level_1_resources

  authorizers = {
    for key, authorizer in var.authorizers : key => merge(authorizer, {
      id = aws_api_gateway_authorizer.this[key].id
    })
  }

  rest_api_id = aws_api_gateway_rest_api.this.id

  dependency = aws_api_gateway_authorizer.this
}

## Level 2
module "resources_level_2" {
  source = "./resources"

  resources_parents = module.resources_level_1.resources

  resources = local.level_2_resources

  authorizers = {
    for key, authorizer in var.authorizers : key => merge(authorizer, {
      id = aws_api_gateway_authorizer.this[key].id
    })
  }

  rest_api_id = aws_api_gateway_rest_api.this.id

  dependency = aws_api_gateway_authorizer.this
}

## Level 3
module "resources_level_3" {
  source = "./resources"

  resources_parents = module.resources_level_2.resources

  resources = local.level_3_resources

  authorizers = {
    for key, authorizer in var.authorizers : key => merge(authorizer, {
      id = aws_api_gateway_authorizer.this[key].id
    })
  }

  rest_api_id = aws_api_gateway_rest_api.this.id

  dependency = aws_api_gateway_authorizer.this
}

## Level 4
module "resources_level_4" {
  source = "./resources"

  resources_parents = module.resources_level_3.resources

  resources = local.level_4_resources

  authorizers = {
    for key, authorizer in var.authorizers : key => merge(authorizer, {
      id = aws_api_gateway_authorizer.this[key].id
    })
  }

  rest_api_id = aws_api_gateway_rest_api.this.id

  dependency = aws_api_gateway_authorizer.this
}

## Level 5
module "resources_level_5" {
  source = "./resources"

  resources_parents = module.resources_level_4.resources

  resources = local.level_5_resources

  authorizers = {
    for key, authorizer in var.authorizers : key => merge(authorizer, {
      id = aws_api_gateway_authorizer.this[key].id
    })
  }

  rest_api_id = aws_api_gateway_rest_api.this.id

  dependency = aws_api_gateway_authorizer.this
}

resource "aws_api_gateway_deployment" "this" {
  depends_on  = [
    module.resources_level_5
  ]
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.stage
}

resource "aws_api_gateway_method_settings" "general_settings" {
  count = var.logs == false ? 0 : 1

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_deployment.this.stage_name
  method_path = "*/*"

  settings {
    # Enable CloudWatch logging and metrics
    metrics_enabled        = true
    data_trace_enabled     = true
    logging_level          = "ERROR"

    # Limit the rate of calls to prevent abuse and unwanted charges
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
  }
}


