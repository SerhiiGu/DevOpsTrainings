node 'swarm-manager' {
  include role::swarm_manager
}

node 'swarm-worker1' {
  include role::swarm_worker
}

node 'swarm-worker2' {
  include role::swarm_worker
}

node 'pxe-server' {
  include role::pxe_server
}

node 'ipxe-server' {
  include role::ipxe_server
}

node 'deb12-repo-buildenv' {
  include role::dpkg_repo_builder_server
}

