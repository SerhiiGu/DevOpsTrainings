variable "swarm_manager_ip" {
  description = "Target IP for Docker Swarm Manager Server"
  type        = string
}

variable "swarm_worker1_ip" {
  description = "Target IP for Docker Swarm Worker Server"
  type        = string
}


variable "swarm_worker2_ip" {
  description = "Target IP for Docker Swarm Worker Server"
  type        = string
}

variable "ssh_private_key_path" {
  default     = "~/.ssh/id_rsa"
  description = "Path to the SSH private key"
}

variable "ssh_user" {
  default     = "root"
}
