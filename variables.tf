variable "resources" {
  type = any
  description = "Resources for the API gateway, see readme"
}

variable "name" {
  type = string
  description = "Name of the API Gateware"
}

variable "authorizers" {
  type = any

  default = []
  description = "Authorizers, see reademe"
}

variable "stage" {
  type = string
  default = "default"
  description = "Stage of the API Gateway"
}

variable "logs" {
  type = bool
  default = false
  description = "Enable or disable logs"
}

variable "tags" {
  type = map(any)
  default = {}
  description = "Tags to be used for the gateway"
}
