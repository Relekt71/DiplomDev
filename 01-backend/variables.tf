variable "yc_cloud_id" {
  type        = string
  description = "Yandex Cloud ID (найти: yc config get cloud-id)"
}

variable "yc_folder_id" {
  type        = string
  description = "Yandex Folder ID (найти: yc config get folder-id)"
}

variable "yc_default_zone" {
  type        = string
  description = "Зона доступности по умолчанию"
  default     = "ru-central1-a"
}

variable "sa_name" {
  type        = string
  description = "Имя сервисного аккаунта для Terraform"
  default     = "tf-diplom-sa"
}

variable "state_bucket_name" {
  type        = string
  description = "Имя S3-бакета для хранения Terraform state (глобально уникальное)"
}

variable "state_bucket_max_size" {
  type        = number
  description = "Максимальный размер бакета в байтах"
  default     = 5368709120
}
