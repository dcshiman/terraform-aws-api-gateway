output "rest_api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "deployment_stage" {
  value = aws_api_gateway_deployment.this.stage_name
}

