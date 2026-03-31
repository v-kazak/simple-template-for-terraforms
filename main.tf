terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token    = var.token
  cloud_id = var.cloud_id
  zone     = var.zone
}

resource "yandex_compute_instance" "default" {
  name        = "${var.name}-${count.index}"
  platform_id = var.platform_type
  zone        = var.zone
  folder_id   = var.folder_id
  count       = var.vps_count


  resources {
    cores         = var.cores_count
    memory        = var.memory_count
    core_fraction = var.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      type     = var.disc_type
      size     = var.disc_size
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.default.id
    nat       = var.nat
  }

  metadata = {
    ssh-keys  = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/install_nginx.sh") # Установка и запуск Nginx при создании ВМ
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

}

resource "yandex_vpc_network" "my_network" {
  name      = "default"
  folder_id = var.folder_id
}

resource "yandex_vpc_subnet" "default" {
  zone           = var.zone
  network_id     = yandex_vpc_network.my_network.id
  v4_cidr_blocks = ["10.25.0.0/24"]
  folder_id      = var.folder_id
}

output "external_ips" {
  description = "Публичный IP-адреса виртуальных машин"
  value       = [for instance in yandex_compute_instance.default : instance.network_interface[0].nat_ip_address]
}

resource "yandex_lb_target_group" "my_blns" {
  name      = "my-target-group"
  region_id = var.blns_zone
  folder_id = var.folder_id

  dynamic "target" {
    for_each = yandex_compute_instance.default
    content {
      subnet_id = yandex_vpc_subnet.default.id
      address   = target.value.network_interface.0.ip_address
    }
  }
}


resource "yandex_lb_network_load_balancer" "my_nlb" {
  name      = "my-network-load-balancer"
  folder_id = var.folder_id

  listener {
    name = "my-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.my_blns.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

output "load_balancer_public_ip" {
  description = "Публичный IP-адрес сетевого балансировщика"
  value       = tolist(tolist(yandex_lb_network_load_balancer.my_nlb.listener)[0].external_address_spec)[0].address
}