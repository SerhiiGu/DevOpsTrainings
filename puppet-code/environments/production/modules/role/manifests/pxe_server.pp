class role::pxe_server {
  include base_server
  include puppet_related
  include profile::pxe_server
}

