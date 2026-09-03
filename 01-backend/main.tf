# ============================================================
# 01-backend/main.tf
# Создание сервисного аккаунта, статического ключа и S3-бакета
# для хранения Terraform state основного проекта.
# ============================================================

# --- Сервисный аккаунт для Terraform ---

resource "yandex_iam_service_account" "tf_sa" {
  name        = var.sa_name
  description = "Service account for Terraform operations"
}

# Минимально необходимые роли — без прав суперпользователя
resource "yandex_resourcemanager_folder_iam_member" "tf_sa_roles" {
  for_each = toset([
    "editor",
    "storage.admin",
    "iam.serviceAccounts.user",
    "vpc.user",
    "k8s.clusters.agent",
    "container-registry.images.puller",
    "container-registry.images.pusher",
  ])

  folder_id = var.yc_folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.tf_sa.id}"
}

# Статический ключ доступа для S3
resource "yandex_iam_service_account_static_access_key" "tf_sa_key" {
  service_account_id = yandex_iam_service_account.tf_sa.id
  description        = "Static access key for S3 backend"
}

# --- S3-бакет для хранения state ---

resource "yandex_storage_bucket" "tf_state" {
  bucket    = var.state_bucket_name
  folder_id = var.yc_folder_id
  max_size  = var.state_bucket_max_size

  versioning {
    enabled = true
  }
}
