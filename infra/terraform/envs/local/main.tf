locals {
  kubeconfig_path = pathexpand("~/.kube/${var.cluster_name}")
}

resource "kind_cluster" "this" {
  name            = var.cluster_name
  node_image      = var.node_image != "" ? var.node_image : null
  kubeconfig_path = local.kubeconfig_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      # CNI padrão (kindnet). Trocar por Cilium é um bom exercício opcional na Fase 4.
      pod_subnet     = "10.244.0.0/16"
      service_subnet = "10.96.0.0/12"
    }

    node {
      role = "control-plane"
    }

    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }
  }
}
