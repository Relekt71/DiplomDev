variable "yc_cloud_id" {
  type        = string
  description = "Yandex Cloud ID"
}

variable "yc_folder_id" {
  type        = string
  description = "Yandex Folder ID"
}

variable "yc_default_zone" {
  type        = string
  description = "Зона доступности по умолчанию"
  default     = "ru-central1-a"
}

variable "network_name" {
  type        = string
  description = "Имя VPC сети"
  default     = "diplom-net"
}

variable "subnets" {
  type = map(object({
    name = string
    zone = string
    cidr = string
  }))
  description = "Подсети в разных зонах доступности"
  default = {
    zone_a = { name = "diplom-subnet-a", zone = "ru-central1-a", cidr = "10.10.10.0/24" }
    zone_b = { name = "diplom-subnet-b", zone = "ru-central1-b", cidr = "10.10.20.0/24" }
    zone_c = { name = "diplom-subnet-c", zone = "ru-central1-c", cidr = "10.10.30.0/24" }
  }
}

variable "cluster_name" {
  type        = string
  description = "Имя Kubernetes-кластера"
  default     = "diplom-k8s"
}

variable "k8s_version" {
  type        = string
  description = "Версия Kubernetes"
  default     = "1.30"
}

variable "k8s_sa_name" {
  type        = string
  description = "Имя сервисного аккаунта для k8s"
  default     = "k8s-diplom-sa"
}

variable "cluster_ipv4_range" {
  type        = string
  description = "CIDR для подов кластера"
  default     = "172.16.0.0/16"
}

variable "node_platform_id" {
  type        = string
  description = "Платформа для node group"
  default     = "standard-v2"
}

variable "node_cores" {
  type        = number
  description = "Количество ядер для node"
  default     = 2
}

variable "node_memory" {
  type        = number
  description = "Память (ГБ) для node"
  default     = 4
}

variable "node_disk_type" {
  type        = string
  description = "Тип диска для node"
  default     = "network-hdd"
}

variable "node_disk_size" {
  type        = number
  description = "Размер диска (ГБ) для node"
  default     = 50
}

variable "node_count" {
  type        = number
  description = "Количество нод в группе"
  default     = 2
}

variable "registry_name" {
  type        = string
  description = "Имя Container Registry"
  default     = "diplom-registry"
}
