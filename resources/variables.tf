variable "resources" {
  type = any
  default = {}
}

variable "resources_parents" {
  type = any
  default = {}
}


variable "rest_api_id" {
  type = string
}

variable "create" {
  type = bool
  default = true
}

variable "authorizers" {
  type = any
  default = []
}

variable dependency {
  type = any

  default = null
}
