variable "resources" {
  type = any
}

variable "name" {
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

variable "domain" {
  type = string
  default = "mispace.app"
}

variable "subdomain" {
  type = string
  default = null
}

variable "stage" {
  type = string
  default = "default"
}

variable "logs" {
  type = bool
  default = false
}

variable "tags" {
  type = map(any)
  default = {}
}
