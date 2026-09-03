output "sa_id" {
  value = yandex_iam_service_account.tf_sa.id
}

output "sa_name" {
  value = yandex_iam_service_account.tf_sa.name
}

output "static_key_access_key" {
  value     = yandex_iam_service_account_static_access_key.tf_sa_key.access_key
  sensitive = true
}

output "static_key_secret_key" {
  value     = yandex_iam_service_account_static_access_key.tf_sa_key.secret_key
  sensitive = true
}

output "state_bucket_name" {
  value = yandex_storage_bucket.tf_state.bucket
}
