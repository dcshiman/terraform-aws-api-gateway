locals {
  resource_methods = flatten([
    for key, resource in var.resources : [
      for method_key, method in lookup(resource, "methods", []) : merge(method, {
        resource_key = key
        method_key = "${key}[${method_key}]"
        http_method = method_key
      })
    ]
  ])

  intergrations = {
    for method in local.resource_methods: method["method_key"] => method if contains(["AWS_PROXY", "AWS"], lookup(lookup(method, "integration", {}), "type", ""))
  }

  non_proxy_intergrations = {
    for method in local.resource_methods: method["method_key"] => method if method["http_method"] != "{proxy+}"
  }
}

resource "aws_api_gateway_resource" "this" {
  for_each = var.resources

  rest_api_id = var.rest_api_id
  parent_id   = var.resources_parents[each.key].parent_id
  path_part   = each.value["path"]
}

resource "aws_api_gateway_method" "this" {
  for_each = {
    for method in local.resource_methods: method["method_key"] => method
  }

  rest_api_id = var.rest_api_id
  resource_id   = aws_api_gateway_resource.this[each.value["resource_key"]].id
  http_method   = each.value["http_method"]
  authorization = lookup(each.value, "authorization", "NONE") == "NONE" ? "NONE" : var.authorizers[each.value["authorization"]]["type"]
  authorizer_id = lookup(each.value, "authorization", "") == "" ? null : var.authorizers[each.value["authorization"]]["id"]
  request_parameters = lookup(each.value, "request_parameters", {})

  depends_on = [
    var.dependency
  ]
}

resource "aws_api_gateway_method_response" "intergration_response_200" {
  for_each = local.non_proxy_intergrations

  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.this[each.value["resource_key"]].id
  http_method = aws_api_gateway_method.this[each.key].http_method
  status_code = "200"

  depends_on = [
    aws_api_gateway_resource.this
  ]
}

resource "aws_api_gateway_integration_response" "intergration_response_200_json" {
  for_each = local.non_proxy_intergrations

  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.this[each.value["resource_key"]].id
  http_method = aws_api_gateway_method.this[each.key].http_method
  status_code = aws_api_gateway_method_response.intergration_response_200[each.key].status_code

  depends_on = [
    aws_api_gateway_method_response.intergration_response_200
  ]

  # Transforms the backend JSON response to XML
  response_templates = {
    "application/json" = <<EOF
EOF
  }
}


//
//# Intergrations
resource "aws_api_gateway_integration" "integration" {
//  count = length(local.integrations)
  for_each = {
    for method in local.resource_methods: method["method_key"] => method if lookup(method, "integration", "") != ""
  }

  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.this[each.value["resource_key"]].id
  http_method             = each.value["http_method"]

  // AWS PROXY only supports POST method
  integration_http_method = contains(["AWS_PROXY", "AWS"], each.value["integration"]["type"]) ? "POST" : lookup(each.value["integration"], "integration_http_method", "ANY")
  type                    = each.value["integration"]["type"]

  // Lookup lambda function data if intergration type is AWS_PROXY, else use uri
  uri                     =  contains(["AWS_PROXY", "AWS"], each.value["integration"]["type"]) ? data.aws_lambda_function.functions[each.key].invoke_arn : lookup(each.value["integration"], "uri", "")

  request_parameters = lookup(each.value["integration"], "request_parameters", {})

  depends_on = [
    var.dependency
  ]
}

data "aws_lambda_function" "functions" {
  for_each = local.intergrations

  function_name = each.value["integration"]["function_name"]

  depends_on = [
    var.dependency
  ]
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "random_id" "lambda_intergration_permissions" {
  for_each = local.intergrations

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    intergration_id = aws_api_gateway_integration.integration[each.key].id
  }

  byte_length = 8
}

resource "aws_lambda_permission" "apigw_lambda" {
  for_each = local.intergrations

  statement_id  = random_id.lambda_intergration_permissions[each.key].keepers.intergration_id
  action        = "lambda:InvokeFunction"
  function_name = each.value["integration"]["function_name"]
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.rest_api_id}/*/${each.value["http_method"] == "ANY" ? "*" : each.value["http_method"]}${aws_api_gateway_resource.this[each.value["resource_key"]].path}"
}


output "resources" {
  value = {
    for resource in flatten([
      for pareant_resource_key, resource in var.resources : [
        for resource_key, child_resource in lookup(resource, "resources", {}) : merge(child_resource, {
          parent_id = aws_api_gateway_resource.this[pareant_resource_key].id
          child_resource_key = "${pareant_resource_key}/${resource_key}"
        })
      ]
    ]) : resource["child_resource_key"] => resource
  }
}
