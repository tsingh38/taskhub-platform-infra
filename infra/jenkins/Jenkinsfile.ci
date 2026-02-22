pipeline {
  agent any

  options {
    disableConcurrentBuilds()
  }

  environment {
    REGISTRY = "tsingh38"
    IMAGE_NAME = "taskhub"
    DOCKERHUB_CREDENTIALS = "dockerhub-tsingh38-taskhub"
    TRIVY_CACHE_DIR = "/var/lib/jenkins/.cache/trivy"
  }

  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Validate Branch (develop only)') {
      steps {
        script {
          def branch = (env.BRANCH_NAME ?: env.GIT_BRANCH ?: '')
          if (!(branch == 'develop' || branch == 'origin/develop')) {
            error("taskhub-ci-dev runs only for develop. Current branch=${branch}")
          }
          echo "Branch OK: ${branch}"
        }
      }
    }

    stage('Resolve Changeset') {
      steps {
        script {
          boolean appChanged = false
          boolean infraChanged = false
          boolean otherChanged = false

          // For very first build
          if (currentBuild.changeSets == null || currentBuild.changeSets.isEmpty()) {
            env.APP_CHANGED = "true"
            env.INFRA_CHANGED = "false"
            env.INFRA_ONLY = "false"
            echo "No changelog found. Defaulting to APP_CHANGED=true (run full CI)."
            return
          }

          for (cs in currentBuild.changeSets) {
            for (entry in cs.items) {
              for (file in entry.affectedFiles) {
                def p = file.path

                // App code
                if (p.startsWith("services/task-service/")) {
                  appChanged = true
                }
                // Infra / Helm / manifests
                else if (p.startsWith("infra/") || p.startsWith("charts/") || p.startsWith("k8s/")) {
                  infraChanged = true
                }
                // Anything else
                else {
                  otherChanged = true
                }
              }
            }
          }

          env.APP_CHANGED = appChanged.toString()
          env.INFRA_CHANGED = infraChanged.toString()
          env.INFRA_ONLY = (infraChanged && !appChanged).toString()

          echo "APP_CHANGED=${env.APP_CHANGED}, INFRA_CHANGED=${env.INFRA_CHANGED}, OTHER_CHANGED=${otherChanged}, INFRA_ONLY=${env.INFRA_ONLY}"
        }
      }
    }

    stage('Resolve Version') {
      when { expression { return env.INFRA_ONLY != "true" } }
      steps {
        dir('services/task-service') {
          script {
            def version = sh(
              script: "./gradlew properties -q | grep '^version:' | awk '{print \$2}'",
              returnStdout: true
            ).trim()
            env.APP_VERSION = version
            echo "APP_VERSION=${env.APP_VERSION}"
          }
        }
      }
    }

    stage('Compute Image Tag') {
      when { expression { return env.INFRA_ONLY != "true" } }
      steps {
        script {
          env.IMAGE_TAG = "${env.APP_VERSION}-${env.BUILD_NUMBER}"
          env.IMAGE = "${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
          echo "IMAGE_TAG=${env.IMAGE_TAG}"
          echo "IMAGE=${env.IMAGE}"
        }
      }
    }

    stage('Build & Test') {
      when { expression { return env.INFRA_ONLY != "true" } }
      steps {
        dir('services/task-service') {
          sh '''
            set -eu
            chmod +x gradlew
            ./gradlew clean test
          '''
        }
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'services/task-service/build/test-results/test/*.xml'
          archiveArtifacts artifacts: 'services/task-service/build/reports/tests/test/**', allowEmptyArchive: true
        }
      }
    }

    stage('Docker Build & Push') {
      when { expression { return env.INFRA_ONLY != "true" } }
      steps {
        dir('services/task-service') {
          withCredentials([usernamePassword(
            credentialsId: DOCKERHUB_CREDENTIALS,
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
          )]) {
            sh '''
              set -eu
              echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
              docker build -t "$IMAGE" .
              docker push "$IMAGE"
              echo "Built and pushed: $IMAGE"
            '''
          }
        }
      }
    }

    stage('Trivy Scan (HIGH/CRITICAL gate)') {
      when { expression { return env.INFRA_ONLY != "true" } }
      steps {
        withCredentials([usernamePassword(
          credentialsId: DOCKERHUB_CREDENTIALS,
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            set -eu
            mkdir -p "$TRIVY_CACHE_DIR"
            docker run --rm \
              -v "$TRIVY_CACHE_DIR:/root/.cache/" \
              -v "$WORKSPACE:/work" \
              aquasec/trivy:latest \
              image \
              --timeout 5m \
              --no-progress \
              --severity HIGH,CRITICAL \
              --exit-code 1 \
              --format json \
              -o /work/trivy-report.json \
              --username "$DOCKER_USER" \
              --password "$DOCKER_PASS" \
              "$IMAGE"
          '''
        }
      }
      post {
        always {
          archiveArtifacts artifacts: 'trivy-report.json', fingerprint: true, onlyIfSuccessful: false
        }
      }
    }

    stage('Trigger DEV Deploy') {
      steps {
        script {
          // If infra-only, deploy should keep current image
          def tagToDeploy = (env.INFRA_ONLY == "true") ? "KEEP_CURRENT" : env.IMAGE_TAG

          echo "Triggering taskhub-deploy-dev with IMAGE_TAG=${tagToDeploy}"

          build job: 'taskhub-deploy-dev',
            parameters: [
              string(name: 'IMAGE_TAG', value: tagToDeploy)
            ],
            wait: true
        }
      }
    }
  }

  post {
    success { echo "taskhub-ci-dev SUCCESS (INFRA_ONLY=${env.INFRA_ONLY})" }
    failure { echo "taskhub-ci-dev FAILED" }
  }
}