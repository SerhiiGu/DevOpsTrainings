resource "null_resource" "swarm_init" {
  provisioner "local-exec" {
    command = "docker swarm init --advertise-addr ${var.manager_ip}"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

variable "manager_ip" {
  description = "IP for initialization of the Docker Swarm cluster"
  type        = string
}

