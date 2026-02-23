resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
}

resource "kubernetes_secret" "db_credentials_prod" {
  metadata {
    name      = "db-credentials"
    namespace = "prod"
  }

data = {
    username         = var.db_user_prod
    password         = var.db_password_prod
    postgres-user     = var.db_user_prod
    postgres-password = var.db_password_prod
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.prod]
}

resource "helm_release" "postgres_prod" {
  name       = "postgres"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = "prod"
  version    = var.postgres_chart_version

  values = [
    file("../../helm/values/postgres/values-prod.yaml")
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
    value = var.db_user_prod
  }

  set {
    name  = "auth.database"
    value = "taskdb"
  }

  depends_on = [
    kubernetes_namespace.prod,
    kubernetes_secret.db_credentials_prod
  ]
}

# --- ServiceMonitor for task-service (PROD) ---
resource "kubernetes_manifest" "task_service_servicemonitor_prod" {
  manifest = yamldecode(
    file("${path.module}/../../monitoring/servicemonitors/task-service-prod.yaml")
  )

  depends_on = [
    helm_release.task_service_prod
  ]
}