output "vpc_id" {
  description = "VPC ID."
  value       = volcenginecc_vpc_vpc.main.vpc_id
}
output "node_subnet_ids" {
  description = "按可用区顺序的节点子网 / Node subnets in AZ order."
  value       = volcenginecc_vpc_subnet.node[*].subnet_id
}
output "pod_subnet_ids" {
  description = "按可用区顺序的 Pod 子网 / Pod subnets in AZ order."
  value       = volcenginecc_vpc_subnet.pod[*].subnet_id
}
output "nat_gateway_id" {
  description = "NAT gateway ID."
  value       = volcenginecc_natgateway_ngw.main.nat_gateway_id
}
output "eip_id" {
  description = "EIP ID."
  value       = volcenginecc_vpc_eip.main.allocation_id
}
output "eip_address" {
  description = "统一公网出口 IP / Shared public egress IP."
  value       = volcenginecc_vpc_eip.main.eip_address
}
output "egress_ready" {
  description = "完整 SNAT 链完成依赖 / Dependency on the completed SNAT chain."
  value = [
    volcenginecc_natgateway_snatentry.node_1.id,
    volcenginecc_natgateway_snatentry.node_2.id,
    volcenginecc_natgateway_snatentry.node_3.id,
    volcenginecc_natgateway_snatentry.pod_1.id,
    volcenginecc_natgateway_snatentry.pod_2.id,
    volcenginecc_natgateway_snatentry.pod_3.id
  ]
}
