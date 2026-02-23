resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
}

resource "kubernetes_secret" "db_credentials_dev" {
  metadata {
    name      = "db-credentials"
    namespace = "dev"
  }

  data = {
    username         = var.db_user_dev
    password         = var.db_password_dev
    postgres-user     = var.db_user_dev
    postgres-password = var.db_password_dev
  }


  type = "Opaque"

  depends_on = [kubernetes_namespace.dev]
}

resource "helm_release" "postgres_dev" {
  name       = "postgres"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = "dev"
  version    = var.postgres_chart_version

  values = [
    file("../../helm/values/postgres/values-dev.yaml")
  ]

  set {
    name  = "image.repository"
    value = "bitnamilegacy/postgresql"
  }

  set {
    name  = "image.tag"
    value = var.postgres_image_tag
  }

  set {
    name  = "auth.existingSecret"
    value = "db-credentials"
  }

  set {
    name  = "auth.username"
    value = var.db_user_dev
  }

  set {
    name  = "auth.database"
    value = "taskdb"
  }

  depends_on = [
    kubernetes_namespace.dev,
    kubernetes_secret.db_credentials_dev
  ]
}

# ServiceMonitor (DEV) - raw manifest applied via Terraform

resource "kubernetes_manifest" "task_service_servicemonitor_dev" {
  manifest = yamldecode(
   file("${path.module}/../../monitoring/servicemonitors/task-service-dev.yaml")
  )

  depends_on = [
    kubernetes_namespace.dev
  ]
}