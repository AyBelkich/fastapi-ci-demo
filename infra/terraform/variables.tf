variable "aws_region" {
  type    = string
  default = "eu-west-3"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "docker_image" {
  type = string
}

# Your personal SSH public key (so YOU can SSH)
variable "admin_ssh_public_key_path" {
  type = string
}

# GitHub Actions deploy public key (so pipeline can SSH)
variable "gha_ssh_public_key_path" {
  type = string
}

# Lock down SSH in real life. Use "x.x.x.x/32".
variable "ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "key_name" {
  type    = string
  default = "items-api-admin"
}
