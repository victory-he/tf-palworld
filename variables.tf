variable "DEDICATED_SERVER_NAME" {
  type        = string
  description = "This is the ID found in GameUserSettings.ini"
}
variable "MAX_PLAYERS" {
  type = string
}

variable "SERVER_NAME" {
  type = string
}

variable "SERVER_DESCRIPTION" {
  type = string
}

variable "SERVER_PASSWORD" {
  type = string
}
variable "ADMIN_PASSWORD" {
  type = string
}

variable "S3_URI" {
  type = string
}

variable "S3_REGION" {
  type = string
}

variable "instance_profile_arn" {
  type = string
}

variable "instance_tag" {
  type    = string
  default = "palworld-tf"
}

variable "key_name" {
  type = string
}

variable "instance_type" {
  type = string
}
