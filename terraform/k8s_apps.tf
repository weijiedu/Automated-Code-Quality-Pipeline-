resource "null_resource" "deploy_jenkins" {
  depends_on = [module.ci, module.hadoop, google_storage_bucket.hadoop_staging, kubernetes_secret.jenkins_secrets]

  triggers = {
    cluster_name         = module.ci.cluster_name
    cluster_region       = module.ci.cluster_location
    manifest_hash        = filesha256("${path.module}/../k8s/jenkins-deployment.yaml")
    project_id           = var.project_id
    gcs_bucket           = google_storage_bucket.hadoop_staging.name
    hadoop_cluster       = module.hadoop.cluster_name
    hadoop_region        = module.hadoop.cluster_region
    jenkins_admin_pass   = var.jenkins_admin_password
    sonar_token_hash     = sha256(var.sonar_token)
    github_token_hash    = sha256(var.github_token)
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${module.ci.cluster_name} --region ${module.ci.cluster_location} --project ${var.project_id}
      kubectl create configmap jenkins-hadoop-config \
        --from-literal=GCP_PROJECT_ID=${var.project_id} \
        --from-literal=GCS_BUCKET=${google_storage_bucket.hadoop_staging.name} \
        --from-literal=HADOOP_CLUSTER=${module.hadoop.cluster_name} \
        --from-literal=HADOOP_REGION=${module.hadoop.cluster_region} \
        --dry-run=client -o yaml | kubectl apply -f -
      kubectl apply -f ${path.module}/../k8s/jenkins-deployment.yaml
    EOT
  }
}

resource "null_resource" "deploy_results_ui" {
  depends_on = [module.ci, null_resource.deploy_jenkins]

  triggers = {
    cluster_name   = module.ci.cluster_name
    cluster_region = module.ci.cluster_location
    manifest_hash  = filesha256("${path.module}/../k8s/results-ui.yaml")
    app_hash       = filesha256("${path.module}/../results-ui/app.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${module.ci.cluster_name} --region ${module.ci.cluster_location} --project ${var.project_id}
      kubectl create configmap results-ui-code \
        --from-file=app.py=${path.module}/../results-ui/app.py \
        --dry-run=client -o yaml | kubectl apply -f -
      kubectl apply -f ${path.module}/../k8s/results-ui.yaml
    EOT
  }
}

resource "null_resource" "deploy_sonarqube" {
  depends_on = [module.ci, null_resource.deploy_jenkins]

  triggers = {
    cluster_name   = module.ci.cluster_name
    cluster_region = module.ci.cluster_location
    manifest_hash  = filesha256("${path.module}/../k8s/sonarqube-deployment.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${module.ci.cluster_name} --region ${module.ci.cluster_location} --project ${var.project_id}
      kubectl apply -f ${path.module}/../k8s/sonarqube-deployment.yaml
    EOT
  }
}
