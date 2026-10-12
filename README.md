# Three-Tier DevSecOps Pipeline on AWS EKS

Deploy a React + Django + PostgreSQL application to **Amazon EKS** with a security-first CI/CD pipeline.
**Jenkins** builds and scans every change (SonarQube, OWASP Dependency-Check, Trivy), pushes images to **Amazon ECR**, and **Argo CD** deploys them GitOps-style. **Prometheus** and **Grafana** handle cluster monitoring, and the Jenkins server itself is provisioned using **Terraform**.

---

## Architecture

```mermaid
flowchart LR
    dev([git push]) --> gh[(GitHub repo)]
    gh --> jenkins[Jenkins on EC2<br/>provisioned by Terraform]
    jenkins -- code quality + quality gate --> sonar[SonarQube]
    jenkins -- dependency + filesystem scans --> scans[OWASP Dependency-Check<br/>Trivy fs]
    jenkins -- build, push, image scan --> ecr[(Amazon ECR)]
    jenkins -- bump image tag in manifests --> gh
    gh --> argocd[Argo CD]
    argocd --> eks
    subgraph eks [Amazon EKS · namespace three-tier]
        alb[ALB Ingress] --> fe[React frontend]
        alb --> be[Django REST API]
        be --> db[(PostgreSQL)]
    end
    monitoring[Prometheus + Grafana] -.-> eks

```

The flow: Every push triggers a Jenkins pipeline per tier. If the image passes security scans, Jenkins pushes it to ECR tagged with the build number, then updates the image tag in kubernetes-manifests/. Argo CD automatically detects the commit and synchronizes the change to the EKS cluster. Git acts as the single source of truth. 

## Tech Stack

| Layer | Tools |
|---|---|
| Application | React 18 (frontend), Django 5 + Django REST Framework (backend), PostgreSQL |
| Infrastructure as Code | Terraform (Jenkins server: VPC, subnet, security group, EC2, IAM role; S3 + DynamoDB remote state) |
| CI | Jenkins, SonarQube, OWASP Dependency-Check, Trivy, Docker |
| Registry | Amazon ECR |
| CD / GitOps | Argo CD |
| Runtime | Amazon EKS, AWS Load Balancer Controller (ALB Ingress) |
| Monitoring | Prometheus, Grafana |
| Repo Security | gitleaks secret scanning on every push and pull request |

## Repository Layout

```text
app-code/
  backend/                  Django REST API (notes app) + Dockerfile
  frontend/notes-frontend/  React app + Dockerfile
jenkins-pipeline/
  jenkinsfile-backend       CI/CD pipeline for the API
  jenkinsfile-frontend      CI/CD pipeline for the web app
jenkins-server-terraform/   Terraform for the Jenkins server + setup scripts
kubernetes-manifests/
  database/                 PostgreSQL Deployment, Service, PV/PVC, Secret
  backend/  frontend/       Deployments + Services
  backend-ingress/ frontend-ingress/   ALB Ingress rules
.github/workflows/secret-scan.yml      gitleaks security workflow
```

## Pipeline Stages

Both `jenkinsfile-backend` and `jenkinsfile-frontend` execute the following stages:
1. **Clean workspace & checkout** code from GitHub.
2. **SonarQube analysis** for static code quality.
3. **Quality gate** evaluation.
4. **OWASP Dependency-Check** for known-vulnerable libraries.
5. **Trivy filesystem scan** for vulnerabilities in the source tree.
6. **Docker build**.
7. **Push to Amazon ECR** tagged with the build number.
8. **Trivy image scan** on the newly pushed container image.
9. **Update deployment manifest** in GitHub so Argo CD can deploy it.

## Setup & Deployment Guide

### 1. Provision the Jenkins Server with Terraform
Configure your remote state bucket and DynamoDB table, then apply the Terraform configuration:
```bash
cd jenkins-server-terraform
terraform init
terraform plan
terraform apply
```

### 2. Configure SonarQube & Jenkins
Access SonarQube at http://<jenkins-server-ip>:9000 to generate a security token and configure webhooks.

Complete the Jenkins setup wizard at http://<jenkins-server-ip>:8080, install required plugins (SonarQube Scanner, OWASP Dependency-Check, Docker Pipeline), and add your credentials.

### 3. Deploy the EKS Cluster and Application
Provision your EKS cluster using eksctl and install the AWS Load Balancer Controller.

Create the three-tier namespace and database secrets on your cluster:

``` Bash
kubectl create namespace three-tier
kubectl create secret generic postgres-sec -n three-tier \
  --from-literal=username=<db-user> --from-literal=password=<strong-password>
```

Update your manifest image URIs and domain placeholders.

### 4. GitOps Deployment via Argo CD
Install Argo CD on your EKS cluster and configure applications to point to your repository's kubernetes-manifests/ folders for automated syncing.

### 5. Cluster Monitoring
Deploy Prometheus and Grafana using Helm to visualize node and pod resource metrics:

``` Bash
helm repo add prometheus-community [https://prometheus-community.github.io/helm-charts](https://prometheus-community.github.io/helm-charts)
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

## Security Practices
- Secrets Management: Credentials and API tokens are managed through Jenkins Credentials and Kubernetes Secrets, keeping sensitive information out of source code.

- Shift-Left Security: SonarQube, OWASP Dependency-Check, and Trivy scan source code and images before deployment.

- GitOps Compliance: Direct kubectl changes from local machines are bypassed; cluster state is entirely controlled through version-controlled commits managed by Argo CD.

### Author
- Narendra Luniwal

- Certification: Red Hat Certified System Administrator (RHCSA)

- GitHub: narendraluniwal
