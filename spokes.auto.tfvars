spoke_subnets = {
  primary = {
    private = true
    vpc_id  = "app"
    cidr    = "10.1.1.0/24"
    mgmt    = false
  }
  hosting = {
    private = true
    vpc_id  = "app"
    cidr    = "10.1.2.0/24"
    mgmt    = false
  }
  openvpn = {
    private = true
    vpc_id  = "dmz"
    cidr    = "10.2.1.0/24"
    mgmt    = false
  }
  nginx = {
    private = true
    vpc_id  = "dmz"
    cidr    = "10.2.2.0/24"
    mgmt    = false
  }
  vault = {
    private = true
    vpc_id  = "db"
    cidr    = "10.3.1.0/24"
    mgmt    = false
  }
  mysql = {
    private = true
    vpc_id  = "db"
    cidr    = "10.3.2.0/24"
    mgmt    = false
  }
  mgmt1 = {
    private = false
    vpc_id  = "app"
    cidr    = "10.1.3.0/24"
    mgmt    = true
  }
  mgmt2 = {
    private = false
    vpc_id  = "dmz"
    cidr    = "10.2.3.0/24"
    mgmt    = true
  }
  mgmt3 = {
    private = false
    vpc_id  = "db"
    cidr    = "10.3.3.0/24"
    mgmt    = true
  }
}
