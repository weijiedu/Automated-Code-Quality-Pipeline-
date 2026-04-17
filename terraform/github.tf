# Create Kubernetes secret for Jenkins configuration
# Must be created BEFORE Jenkins deployment
resource "kubernetes_secret" "jenkins_secrets" {
  depends_on = [module.ci]

  metadata {
    name      = "jenkins-secrets"
    namespace = "default"
  }

  data = {
    admin-password     = var.jenkins_admin_password
    sonar-token        = var.sonar_token
    github-username    = var.github_username
    github-token       = var.github_token
    github-repo-owner  = var.github_repo_owner
  }

  type = "Opaque"
}

# Data source to get Jenkins LoadBalancer IP
data "kubernetes_service" "jenkins" {
  depends_on = [null_resource.deploy_jenkins]

  metadata {
    name      = "jenkins-service"
    namespace = "default"
  }
}

# Create GitHub webhook for mayavi repository
resource "github_repository_webhook" "mayavi_jenkins" {
  repository = "mayavi"

  configuration {
    url          = "http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.ip}/github-webhook/"
    content_type = "json"
    insecure_ssl = false
  }

  active = true

  events = ["push", "pull_request"]
}

# Update ConfigMap with Jenkins URL
resource "null_resource" "update_jenkins_url" {
  depends_on = [
    data.kubernetes_service.jenkins,
    null_resource.deploy_jenkins
  ]

  triggers = {
    jenkins_ip = data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${module.ci.cluster_name} --region ${module.ci.cluster_location} --project ${var.project_id}
      kubectl create configmap jenkins-hadoop-config \
        --from-literal=GCP_PROJECT_ID=${var.project_id} \
        --from-literal=GCS_BUCKET=${google_storage_bucket.hadoop_staging.name} \
        --from-literal=HADOOP_CLUSTER=${module.hadoop.cluster_name} \
        --from-literal=HADOOP_REGION=${module.hadoop.cluster_region} \
        --from-literal=JENKINS_URL=http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.ip} \
        --dry-run=client -o yaml | kubectl apply -f -

      # Restart Jenkins to pick up the new configuration
      kubectl rollout restart deployment/jenkins
    EOT
  }
}

# Auto-create pipeline job using Groovy script
resource "null_resource" "create_pipeline_job" {
  depends_on = [
    null_resource.update_jenkins_url,
    kubernetes_secret.jenkins_secrets
  ]

  triggers = {
    jenkins_ip     = data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.ip
    script_hash    = filesha256("${path.module}/../scripts/create-pipeline.groovy")
    github_owner   = var.github_repo_owner
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Jenkins to be fully ready
      echo "Waiting for Jenkins to be ready..."
      sleep 120

      # Get Jenkins URL and credentials
      JENKINS_URL="http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.ip}"
      JENKINS_USER="admin"
      JENKINS_PASS="${var.jenkins_admin_password}"

      # Wait for Jenkins to respond
      for i in $(seq 1 30); do
        if curl -s -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/api/json" > /dev/null 2>&1; then
          echo "Jenkins is ready!"
          break
        fi
        echo "Waiting for Jenkins... ($i/30)"
        sleep 10
      done

      # Execute Groovy script to create pipeline
      curl -s -u "$JENKINS_USER:$JENKINS_PASS" \
        -d "script=$(cat ${path.module}/../scripts/create-pipeline.groovy)" \
        "$JENKINS_URL/scriptText"

      echo "Pipeline creation script executed"
    EOT
  }
}
