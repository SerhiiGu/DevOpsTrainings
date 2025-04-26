resource "docker_network" "global_net" {
  name   = "global_net"
  driver = "overlay"
  attachable = true
}

