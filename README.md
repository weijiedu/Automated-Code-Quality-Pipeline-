**Team:** Weijie Du, Xin (Vicky) Shu

**Code Walkthrough Video:** https://drive.google.com/file/d/1d6zBtVjQLKoBElFzyVHEOvV8E3jAZ5lC/view?usp=sharing

**Functional application demo:** https://youtu.be/eqFCYjZVNIE

---

## Overview

This project provisions a CI/CD pipeline on GKE that checks out the [Mayavi](https://github.com/xinshu-cmu-S25/mayavi) repository, runs SonarQube static analysis, and — if no blockers are found — submits a Hadoop Streaming MapReduce job on Dataproc to count lines per file. A Flask-based results dashboard is also deployed on GKE for browsing the output.

Infrastructure is managed entirely through Terraform. Jenkins and SonarQube run as pods on a GKE cluster. The Dataproc cluster (1 master + 3 workers) runs Hadoop jobs in `us-west1`.

## Assumptions

- You have a GCP project with billing enabled and the following APIs turned on: Compute Engine, Dataproc, GKE, Cloud Storage, IAM.
- `gcloud`, `terraform`, and `kubectl` are installed locally and on your PATH.
- You are authenticated with GCP (`gcloud auth login` and `gcloud auth application-default login`).
- A GitHub Personal Access Token is available with `repo` and `admin:repo_hook` scopes.
- The SonarQube token is created manually after initial deploy (see step 5 below).

## Repository Structure

```
.
├── Jenkinsfile                  # Declarative pipeline (checkout → SonarQube → Hadoop)
├── terraform/
│   ├── main.tf                  # Root module — wires ci and hadoop modules
│   ├── variables.tf             # Input variables
│   ├── terraform.tfvars.example # Copy this to terraform.tfvars and fill in values
│   ├── gcs.tf                   # GCS bucket for staging
│   ├── github.tf                # GitHub webhook for Jenkins
│   ├── k8s_apps.tf              # kubectl apply for Jenkins, SonarQube, results-ui
│   ├── ci/                      # GKE cluster module
│   └── hadoop/                  # Dataproc cluster module
├── k8s/
│   ├── jenkins-deployment.yaml
│   ├── sonarqube-deployment.yaml
│   └── results-ui.yaml          # Deployment + Service for the results dashboard
├── results-ui/
│   └── app.py                   # Flask app — reads Hadoop output from GCS
├── scripts/
│   └── create-pipeline.groovy   # Seed job for Jenkins pipeline creation
└── mayavi_linecount_all.txt     # Sample line-count output from a previous run
```

## Steps to Run

### 1. Clone the repo

```bash
git clone <this-repo-url>
cd course-project-option-i-weijied-cmu-S25
```

### 2. Configure Terraform variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and fill in your values:

| Variable | Description |
|---|---|
| `project_id` | Your GCP project ID |
| `region` | GCP region (default `us-west1`) |
| `zone` | GCP zone (default `us-west1-a`) |
| `github_token` | GitHub PAT with `repo` + `admin:repo_hook` |
| `github_repo_owner` | GitHub username or org |
| `github_username` | GitHub username |
| `jenkins_admin_password` | Password for Jenkins admin |
| `sonar_token` | Placeholder for now — see step 5 |

### 3. Provision infrastructure

```bash
cd terraform
terraform init
terraform apply
```

This creates:
- A GKE cluster with Jenkins and SonarQube pods
- A Dataproc cluster (1 master, 3 workers)
- A GCS bucket for staging MapReduce I/O
- A GitHub webhook pointing at Jenkins
- The results-ui deployment on GKE

### 4. Connect to the GKE cluster

```bash
gcloud container clusters get-credentials <cluster-name> --region us-west1 --project <your-project-id>
```

### 5. Setup Jenkins

Get the Jenkins service external IP:

```bash
kubectl get svc jenkins-service
```

Wait for the `EXTERNAL-IP` to be assigned (may take a few minutes). Once available, access Jenkins at `http://<EXTERNAL-IP>`.

1. Log in with username `admin` and the password you set in `terraform.tfvars` (`jenkins_admin_password`)
2. Verify that the following plugins are installed
   - Pipeline (workflow-aggregator)
   - Git plugin
   - GitHub plugin
   - SonarQube Scanner
3. Configure SonarQube server:
   - Go to **Manage Jenkins → Configure System**
   - Scroll to **SonarQube servers** section
   - Click **Add SonarQube**
   - Name: `sonarqube-server`
   - Server URL: `http://sonarqube-service.default.svc.cluster.local:9000`
   - Server authentication token: Select `sonar-token` from credentials
   - Click **Save**
4. Configure SonarQube Scanner:
   - Go to **Manage Jenkins → Global Tool Configuration**
   - Scroll to **SonarQube Scanner** section
   - Click **Add SonarQube Scanner**
   - Name: `sonar-scanner`
   - Check **Install automatically**
   - Select the latest version
   - Click **Save**

### 6. Create the SonarQube token

Get the SonarQube service external IP:

```bash
kubectl get svc sonarqube-service
```

Once the `EXTERNAL-IP` is assigned, access SonarQube at `http://<EXTERNAL-IP>:9000`:

1. Log in with default credentials: username `admin`, password `admin` (you will be prompted to change the password on first login)
2. Go to **My Account → Security → Generate Token**
3. Name: `jenkins` (or any name you prefer)
4. Click **Generate** and copy the token
5. Update `terraform/terraform.tfvars` with the generated token as `sonar_token`
6. Run `terraform apply` again so Jenkins picks up the credential:
   ```bash
   cd terraform
   terraform apply
   ```

### 7. Trigger the pipeline

Push a commit to the Mayavi repo (or trigger a build manually in Jenkins). The pipeline will:

1. Check out the Mayavi repo
2. Run SonarQube analysis and wait for it to finish
3. Check for BLOCKER-level issues
4. If clean, upload the repo to GCS and submit a Hadoop Streaming job on Dataproc
5. Print line-count results in the Jenkins console

### 8. View results

**Option A — Results UI (web dashboard):**

```bash
kubectl create configmap results-ui-code --from-file=app.py=results-ui/app.py --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/results-ui.yaml
kubectl port-forward svc/results-ui-service 8080:80
```

Open http://localhost:8080. The dashboard reads Hadoop output from GCS and shows a searchable, sortable table with summary stats.

**Option B — gsutil:**

```bash
gsutil cat gs://<PROJECT_ID>-hadoop-staging/mayavi_output/part-*
```

**Option C — Jenkins console output:**

The pipeline prints the results at the end of the "Run Hadoop Job" stage.

