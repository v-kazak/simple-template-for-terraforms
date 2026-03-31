output "load_balancer_public_ip" {
  description = "Публичный IP-адрес сетевого балансировщика"
  value       = tolist(tolist(yandex_lb_network_load_balancer.my_nlb.listener)[0].external_address_spec)[0].address
}

output "external_ips" {
  description = "Публичные IP-адреса виртуальных машин"
  value       = [for instance in yandex_compute_instance.default : instance.network_interface[0].nat_ip_address]
}