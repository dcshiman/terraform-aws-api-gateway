# AWS API GATEWAY
This terraform module creates AWS Api gateway resource. The module only supports 5 levels of gateway resources

EG Usage:
```
module "api_gateway" {
  source  = "dcshiman/api-gateway/aws"
  version = "0.0.4"

  name = "foo-api"

  authorizers = {
    cognito-foo = {
      cognito_pool_name = "foo-bar"
      type = "COGNITO_USER_POOLS"
    }
  }

  resources = {
    "api" = {
      resources = {
        "{proxy+}" = {
          methods = {
            "ANY" = {
              authorization = "cognito-foo"                 // the key of the authorizer
              integration = {
                type = "AWS_PROXY"                          // Proxy to lambda function
                function_name = "foo-function"
              }
            }
          }
        }
      }
    }

    "users" = {
      methods = {
        "POST" = {
          integration = {
            integration_http_method = "POST"
            type = "AWS"                                    // Non proxy lambda function
            function_name = "foo-users"
          }
        }
      }
      resources = {
        "sign-up" = {
          methods = {
            "POST" = {
              integration = {
                integration_http_method = "POST"
                type = "AWS"
                function_name = "foo-signup"
              }
            }
          }
        }

        "login" = {
          methods = {
            "POST" = {
              integration = {
                integration_http_method = "POST"
                type = "AWS"
                function_name = "foo-login"
              }
            }
          }
        }
      }
    }

    "{proxy+}" = {
      methods = {
        "ANY" = {
          authorization = "cognito"
          integration = {
            type = "HTTP_PROXY"
            uri = "https://bar.foo.com/{proxy}"
            request_parameters = {
              "integration.request.path.proxy" = "method.request.path.proxy"
              "integration.request.header.x-cognito-sub" = "context.authorizer.claims.sub"
              "integration.request.header.x-cognito-username" = "context.authorizer.claims.cognito:username"
              "integration.request.header.x-cognito-name" = "context.authorizer.claims.cognito:name"
            }
          }
          request_parameters = {
            "method.request.path.proxy" = true
          }
        },
        "OPTIONS" = {
          integration = {
            type = "HTTP_PROXY"
            uri = "https://bar.foo.com/{proxy}"
            request_parameters = {
              "integration.request.path.proxy" = "method.request.path.proxy"
            }
          }
          request_parameters = {
            "method.request.path.proxy" = true
          }
        }
      }
    }
  }

  logs = true
}

# Domain config
data "aws_route53_zone" "zone" {
  name         = "foo.com."
  private_zone = false
}

resource "aws_acm_certificate" "this" {
  domain_name       = "api.foo.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "this_validation" {
  name    = aws_acm_certificate.this.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.this.domain_validation_options[0].resource_record_type
  zone_id = data.aws_route53_zone.zone.zone_id
  records = [aws_acm_certificate.this.domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [
    aws_route53_record.this_validation.fqdn
  ]
}

resource "aws_api_gateway_domain_name" "this" {
  domain_name              = "api.foo.com"
  regional_certificate_arn = aws_acm_certificate_validation.this.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "test" {
  api_id      = module.api_gateway.rest_api_id
  stage_name  = module.api_gateway.deployment_stage
  domain_name = aws_api_gateway_domain_name.this.domain_name
}

resource "aws_route53_record" "this" {
  name = aws_acm_certificate.this.domain_name
  type = "A"
  zone_id = data.aws_route53_zone.zone.zone_id


  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.this.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.this.regional_zone_id
  }
}
```

## The module currently only supports
- Authorizer: Cognito Authorizer
- Integrations: HTTP Proxy
- Integrations: AWS Proxy lambda
- Integrations: AWS lambda
- Stage: one stage 

## TODO
- Authorizer: Lambda Authorizer 
- Integrations: AWS
- Integrations: VPC Link 
