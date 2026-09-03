# ============================================================
# 02-infrastructure/main.tf
# VPC, NAT, Kubernetes-кластер, Node Group (preemptible), Registry
# ============================================================

# --- Сеть ---

resource "yandex_vpc_network" "net" {
  name = var.network_name
}

# --- Подсети ---

resource "yandex_vpc_subnet" "subnet_a" {
  name           = "${var.network_name}-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["192.168.10.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "subnet_b" {
  name           = "${var.network_name}-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "subnet_d" {
  name           = "${var.network_name}-subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["192.168.30.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

# --- NAT-шлюз ---

resource "yandex_vpc_gateway" "nat" {
  name = "${var.network_name}-nat"

  shared_egress_gateway {}
}

# --- Таблица маршрутизации ---

resource "yandex_vpc_route_table" "rt" {
  name       = "${var.network_name}-rt"
  network_id = yandex_vpc_network.net.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

# --- Security Group для Kubernetes ---

resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "${var.cluster_name}-sg"
  network_id  = yandex_vpc_network.net.id
  description = "Security group for Kubernetes cluster"

  ingress {
    protocol          = "TCP"
    description       = "Allow loadbalancer healthchecks"
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol          = "ANY"
    description       = "Allow internal traffic within SG"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTPS"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow Kubernetes API"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }
}

# --- Сервисный аккаунт для Kubernetes ---

resource "yandex_iam_service_account" "k8s_sa" {
  name        = var.k8s_sa_name
  description = "Service account for Kubernetes cluster"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_sa_roles" {
  for_each = toset([
    "editor",
    "container-registry.images.puller",
    "vpc.user",
  ])

  folder_id = var.yc_folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

# --- Kubernetes-кластер ---

resource "yandex_kubernetes_cluster" "k8s" {
  name       = var.cluster_name
  network_id = yandex_vpc_network.net.id

  master {
    version   = var.k8s_version
    public_ip = true

    master_logging {
      enabled = false
    }

    master_location {
      zone      = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnet_a.id
    }

    master_location {
      zone      = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.subnet_b.id
    }

    master_location {
      zone      = "ru-central1-d"
      subnet_id = yandex_vpc_subnet.subnet_d.id
    }

    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id

  cluster_ipv4_range = var.cluster_ipv4_range
  service_ipv4_range = "172.17.0.0/16"
}

# --- Node Group (прерываемые ВМ — максимальная экономия) ---

resource "yandex_kubernetes_node_group" "nodes" {
  cluster_id = yandex_kubernetes_cluster.k8s.id
  name       = "${var.cluster_name}-ng"
  version    = var.k8s_version

  instance_template {
    platform_id = var.node_platform_id

    resources {
      cores  = var.node_cores
      memory = var.node_memory
    }

    boot_disk {
      type = var.node_disk_type
      size = var.node_disk_size
    }

    container_runtime {
      type = "containerd"
    }

    scheduling_policy {
      preemptible = true
    }

    metadata = {
      user-data = "#cloud-config\npackages: [fail2ban]\n"
    }
  }

  scale_policy {
    fixed_scale {
      size = var.node_count
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
    location {
      zone = "ru-central1-b"
    }
    location {
      zone = "ru-central1-d"
    }
  }
}

# --- Container Registry ---

resource "yandex_container_registry" "registry" {
  name      = var.registry_name
  folder_id = var.yc_folder_id
}

# --- Outputs ---

output "cluster_id" {
  value = yandex_kubernetes_cluster.k8s.id
}

output "cluster_external_v4_endpoint" {
  value = yandex_kubernetes_cluster.k8s.master[0].public_ip
}

output "registry_id" {
  value = yandex_container_registry.registry.id
}

output "network_id" {
  value = yandex_vpc_network.net.id
}

output "subnet_a_id" {
  value = yandex_vpc_subnet.subnet_a.id
}

output "subnet_b_id" {
  value = yandex_vpc_subnet.subnet_b.id
}

output "subnet_d_id" {
  value = yandex_vpc_subnet.subnet_d.id
}
