resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_secret" "alertmanager_slack" {
  metadata {
    name      = "alertmanager-slack-token"
    namespace = "monitoring"
  }

  data = {
    token = var.slack_webhook_url
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "prometheus_stack" {
  name       = "monitoring-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = var.prometheus_chart_version

  values = [
    file("../../helm/values/monitoring/values.yaml"),
    file("../../helm/values/monitoring/values-dev.yaml")
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_secret.alertmanager_slack
  ]
}