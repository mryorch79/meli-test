variable "vpc_cidr" {
    type = string
    default = "10.0.0.0/16"
}

variable "stage" {
    type = string
}

variable "pub_subnets" {
    type = list(string)
    default = [ "10.0.1.0/24" ]
}

variable "azs" {
    type = list(string)
    default = [ "us-east-1a" ]
}

variable "ami_id" {
    type = string
}

variable "instance_type" {
    type = string
}