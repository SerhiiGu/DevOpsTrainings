variable "puppet_server_ip" {
  description = "Target IP for Puppet Server installation"
  type        = string
}

variable "ssh_private_key_path" {
  default     = "/root/.ssh/id_rsa"
  description = "Path to the SSH private key"
}

variable "ssh_user" {
  default     = "root"
}

