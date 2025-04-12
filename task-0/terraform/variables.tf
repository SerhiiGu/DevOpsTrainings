variable "manager" {
  type = object({
    ip       = string
    user     = string
    ssh_key  = string
  })
}

variable "worker" {
  type = object({
    ip       = string
    user     = string
    ssh_key  = string
  })
}
