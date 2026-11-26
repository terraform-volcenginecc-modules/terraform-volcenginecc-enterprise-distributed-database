locals {
  tags         = [for k, v in var.tags : { key = k, value = v }]
  subnet_cidrs = concat([for t in var.topology : t.node_cidr], [for t in var.topology : t.pod_cidr])
  ranges = {
    for c in distinct(concat(local.subnet_cidrs, [var.vpc_cidr, var.service_cidr])) : c => {
      first = try(sum([for i, octet in split(".", cidrhost(c, 0)) : tonumber(octet) * pow(256, 3 - i)]), -1)
      last  = try(sum([for i, octet in split(".", cidrhost(c, -1)) : tonumber(octet) * pow(256, 3 - i)]), -1)
    }
  }
}

resource "volcenginecc_vpc_vpc" "main" {
  vpc_name     = "${var.name_prefix}-vpc"
  project_name = var.project_name
  cidr_block   = var.vpc_cidr
  tags         = local.tags
  lifecycle {
    precondition {
      condition = alltrue([
        for c in concat(local.subnet_cidrs, [var.vpc_cidr, var.service_cidr]) :
        can(cidrnetmask(c)) && try(cidrhost(c, 0) == split("/", c)[0], false)
      ])
      error_message = "All CIDRs must be canonical IPv4 network addresses."
    }
    precondition {
      condition = alltrue([
        for c in local.subnet_cidrs : local.ranges[c].first >= local.ranges[var.vpc_cidr].first &&
        local.ranges[c].last <= local.ranges[var.vpc_cidr].last
      ])
      error_message = "Every subnet must be fully contained in the VPC."
    }
    precondition {
      condition = alltrue(flatten([
        for i, a in local.subnet_cidrs : [
          for j, b in local.subnet_cidrs : i >= j || local.ranges[a].last < local.ranges[b].first || local.ranges[b].last < local.ranges[a].first
        ]
      ]))
      error_message = "Node and Pod subnet CIDRs must not overlap."
    }
    precondition {
      condition     = local.ranges[var.service_cidr].last < local.ranges[var.vpc_cidr].first || local.ranges[var.vpc_cidr].last < local.ranges[var.service_cidr].first
      error_message = "Service CIDR must not overlap the VPC."
    }
    precondition {
      condition = anytrue([
        local.ranges[var.vpc_cidr].first >= 167772160 && local.ranges[var.vpc_cidr].last <= 184549375,
        local.ranges[var.vpc_cidr].first >= 2886729728 && local.ranges[var.vpc_cidr].last <= 2887778303,
        local.ranges[var.vpc_cidr].first >= 3232235520 && local.ranges[var.vpc_cidr].last <= 3232301055
      ])
      error_message = "VPC CIDR must be contained in an RFC1918 private range."
    }
  }
}

resource "volcenginecc_vpc_subnet" "node" {
  count       = 3
  vpc_id      = volcenginecc_vpc_vpc.main.vpc_id
  subnet_name = "${var.name_prefix}-node-${count.index + 1}"
  cidr_block  = var.topology[count.index].node_cidr
  zone_id     = var.topology[count.index].zone
  tags        = local.tags
}

resource "volcenginecc_vpc_subnet" "pod" {
  count       = 3
  vpc_id      = volcenginecc_vpc_vpc.main.vpc_id
  subnet_name = "${var.name_prefix}-pod-${count.index + 1}"
  cidr_block  = var.topology[count.index].pod_cidr
  zone_id     = var.topology[count.index].zone
  tags        = local.tags
}

resource "volcenginecc_natgateway_ngw" "main" {
  nat_gateway_name = "${var.name_prefix}-nat"
  vpc_id           = volcenginecc_vpc_vpc.main.vpc_id
  subnet_id        = volcenginecc_vpc_subnet.node[0].subnet_id
  spec             = var.nat_spec
  billing_type     = 2
  tags             = local.tags
  project_name     = var.project_name
}

resource "volcenginecc_vpc_eip" "main" {
  name          = "${var.name_prefix}-egress"
  billing_type  = 3
  bandwidth     = var.eip_bandwidth
  isp           = "BGP"
  instance_id   = volcenginecc_natgateway_ngw.main.nat_gateway_id
  instance_type = "Nat"
  tags          = local.tags
  project_name  = var.project_name
}

# 同一 NAT 的修改必须逐个完成；销毁自动反向执行。
# Mutations on the same NAT complete sequentially; destroy follows the reverse graph.
resource "volcenginecc_natgateway_snatentry" "node_1" {
  nat_gateway_id = volcenginecc_natgateway_ngw.main.nat_gateway_id
  subnet_id      = volcenginecc_vpc_subnet.node[0].subnet_id
  eip_id         = volcenginecc_vpc_eip.main.allocation_id
}
resource "volcenginecc_natgateway_snatentry" "node_2" {
  nat_gateway_id = volcenginecc_natgateway_ngw.main.nat_gateway_id
  subnet_id      = volcenginecc_vpc_subnet.node[1].subnet_id
  eip_id         = volcenginecc_vpc_eip.main.allocation_id
  depends_on     = [volcenginecc_natgateway_snatentry.node_1]
}
resource "volcenginecc_natgateway_snatentry" "node_3" {
  nat_gateway_id = volcenginecc_natgateway_ngw.main.nat_gateway_id
  subnet_id      = volcenginecc_vpc_subnet.node[2].subnet_id
  eip_id         = volcenginecc_vpc_eip.main.allocation_id
  depends_on     = [volcenginecc_natgateway_snatentry.node_2]
}
resource "volcenginecc_natgateway_snatentry" "pod_1" {
  nat_gateway_id = volcenginecc_natgateway_ngw.main.nat_gateway_id
  subnet_id      = volcenginecc_vpc_subnet.pod[0].subnet_id
  eip_id         = volcenginecc_vpc_eip.main.allocation_id
  depends_on     = [volcenginecc_natgateway_snatentry.node_3]
}
resource "volcenginecc_natgateway_snatentry" "pod_2" {
  nat_gateway_id = volcenginecc_natgateway_ngw.main.nat_gateway_id
  subnet_id      = volcenginecc_vpc_subnet.pod[1].subnet_id
  eip_id         = volcenginecc_vpc_eip.main.allocation_id
  depends_on     = [volcenginecc_natgateway_snatentry.pod_1]
}
resource "volcenginecc_natgateway_snatentry" "pod_3" {
  nat_gateway_id = volcenginecc_natgateway_ngw.main.nat_gateway_id
  subnet_id      = volcenginecc_vpc_subnet.pod[2].subnet_id
  eip_id         = volcenginecc_vpc_eip.main.allocation_id
  depends_on     = [volcenginecc_natgateway_snatentry.pod_2]
}
