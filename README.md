# FastAPI Items API — CI/CD to Docker Hub + AWS EC2 (Terraform + CloudWatch)

This is a small but realistic project I built (with the help of AI as a coach) to practice the core DevOps/Cloud workflow companies expect from a junior/intern: testing, containerization, CI, artifact publishing, reproducible infrastructure, basic monitoring, and centralized logging.

---

## What I built (high level)

I built a simple FastAPI REST API for managing “items”, then made it production-shaped by adding:

* **Pytest tests** that run automatically
* **Docker** containerization
* **GitHub Actions CI** (tests on every push/PR)
* **Docker image build + push to Docker Hub** (on `main`)
* **Auto-deploy to AWS EC2 via SSH** (on `main`), including a health check
* **Terraform IaC** to provision EC2 + Security Group + keys (no manual AWS Console clicks)
* **CloudWatch CPU alarm** (basic monitoring/observability)
* **CloudWatch Logs shipping** for container logs (no SSH needed to debug)

Goal: a clean **push to main → new version is deployed** loop, with reproducible infra and minimal observability in place.

---

## Tech stack

* Python 3.11+
* FastAPI
* Pytest (+ pytest-random-order)
* Docker
* GitHub Actions
* Docker Hub
* AWS EC2 (Ubuntu)
* Terraform (AWS provider)
* CloudWatch (Alarms + Logs)
* SNS (optional email notifications)

---

## API endpoints

### Health

* `GET /health`

  * **200** → `{"status":"ok"}`

### Items

* `POST /items`

  * Body: `{"name": "Apple", "price": 1.23}`
  * **201** → `{"id":"...","name":"Apple","price":1.23}`
  * **400** on duplicate name (case-insensitive): `{"detail":"Item already exists"}`

* `GET /items/{item_id}`

  * **200** → item JSON
  * **404** if not found: `{"detail":"Not found"}`

* `DELETE /items/{item_id}`

  * **204** if deleted
  * **404** if not found

---

## Repo structure

* `main.py` — FastAPI app (in-memory storage)
* `requirements.txt` — runtime dependencies
* `requirements-dev.txt` — runtime + test dependencies
* `tests/test_api.py` — API tests (FastAPI `TestClient`)
* `Dockerfile` — container build instructions
* `.github/workflows/ci.yml` — GitHub Actions pipeline
* `infra/terraform/` — Infrastructure as Code (Terraform)

  * `main.tf` — EC2 + security group + key pair
  * `userdata.sh` — installs Docker + runs the container on boot
  * `monitoring.tf` — CloudWatch CPU alarm (+ optional SNS email)
  * `logging.tf` — CloudWatch log group
  * `iam.tf` — IAM role + instance profile for CloudWatch Logs
  * `variables.tf`, `providers.tf`, `outputs.tf`, `terraform.tfvars`

---

## How to run locally

### 1) Create a venv and install deps

```bash
python -m venv .venv
source .venv/bin/activate   # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
```

### 2) Start the API

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

Test:

```bash
curl http://localhost:8000/health
```

---

## Tests

Run tests:

```bash
pytest -q
```

Run tests in random order (to ensure no state leaks between tests):

```bash
pytest -q --random-order
```

Why I did this: the API uses **in-memory state** (`items_by_id`), so tests must be independent and not depend on execution order. I added a fixture that clears state before each test to keep CI stable.

---

## Docker

Build:

```bash
docker build -t <dockerhub_user>/<repo_name>:latest .
```

Run locally:

```bash
docker run --rm -p 8000:8000 <dockerhub_user>/<repo_name>:latest
```

---

## CI/CD (GitHub Actions)

### What my pipeline does

* On every **push** and **pull request**:

  * run tests (CI)

* On **push to `main`**:

  * run tests
  * build Docker image
  * push image to Docker Hub
  * deploy to EC2 via SSH
  * run a `/health` check after deployment

### Image tagging

I push two tags:

* `:latest` for convenience
* `:sha-<commit_sha>` for traceability and rollback

---

## Auto-deploy to AWS EC2 (what happens)

On `main` pushes, GitHub Actions SSHes into my EC2 instance and runs roughly:

```bash
docker pull "<image_tag>"
docker rm -f items-api 2>/dev/null || true

docker run -d \
  --name items-api \
  --restart unless-stopped \
  -p 8000:8000 \
  "<image_tag>"
```

### Deploy verification

On the EC2 instance, I can verify the running image is the commit-tagged version:

```bash
sudo docker inspect items-api --format '{{.Config.Image}}'
# example: <dockerhub_user>/fastapi-ci-demo:sha-<commit_sha>
```

---

## Infrastructure as Code (Terraform)

Instead of manually creating EC2 resources in the AWS console, the server is provisioned with Terraform.

### What Terraform creates

* EC2 instance (Ubuntu 22.04)
* Security Group (SSH + API)
* SSH key pair
* `user_data` bootstrap script:

  * installs Docker
  * adds the GitHub Actions deploy key to `authorized_keys`
  * runs the container

### Run Terraform

From repo root:

```bash
cd infra/terraform
terraform fmt -recursive
terraform init
terraform plan
terraform apply
```

Terraform outputs (useful for CI/CD secrets):

* `public_ip`
* `public_dns`
* `instance_id`

---

## Monitoring: CloudWatch CPU alarm

I added a CloudWatch alarm for basic observability.

* Metric: `AWS/EC2 -> CPUUtilization`
* Alarm triggers when CPU > 50% for ~2 minutes

Optional: the alarm can send email notifications through SNS (requires confirmation email).

To test the alarm:

```bash
sudo apt-get update
sudo apt-get install -y stress-ng
stress-ng --cpu 2 --timeout 240s
```

---

## Centralized logging: CloudWatch Logs (no SSH needed)

Instead of requiring SSH + `docker logs`, container logs are shipped automatically to CloudWatch.

Approach (simple, beginner-friendly on EC2):

* Docker uses the `awslogs` logging driver
* EC2 gets an IAM role/instance profile allowing it to write logs
* Logs are stored in CloudWatch Log Group: `/items-api`

### How the container is started (with CloudWatch logging)

The `docker run` uses:

```bash
--log-driver awslogs
--log-opt awslogs-region=eu-west-3
--log-opt awslogs-group=/items-api
--log-opt awslogs-stream="$(hostname)-items-api"
```

### Verify in AWS

CloudWatch → Logs → Log groups → `/items-api` → open the latest stream.

---

## AWS networking

My EC2 Security Group allows:

* inbound **TCP 8000** for the API
* inbound **TCP 22** for SSH

For a real setup, SSH should be restricted to a known IP range and/or replaced with a more secure approach (SSM, bastion, etc.). For learning + GitHub Actions SSH deploy, SSH may be temporarily open (`0.0.0.0/0`).

---

## GitHub Secrets I used

Repo → **Settings → Secrets and variables → Actions**

Docker Hub:

* `DOCKERHUB_USERNAME`
* `DOCKERHUB_TOKEN` (access token, not password)

EC2 deploy:

* `EC2_HOST` (public IP/DNS)
* `EC2_USER` (`ubuntu`)
* `EC2_SSH_KEY_B64` (base64-encoded private key for the deploy user)

I used a dedicated deploy key rather than my personal SSH key, which is closer to how teams handle automated deployments.

---

## Rollback (manual)

If I need to roll back, I can redeploy a previous commit-tagged image:

```bash
docker pull <dockerhub_user>/<repo_name>:sha-<older_commit_sha>
docker rm -f items-api
docker run -d --name items-api --restart unless-stopped -p 8000:8000 <dockerhub_user>/<repo_name>:sha-<older_commit_sha>
```

---

## Azure equivalent (concept mapping)

I practiced on AWS, but the same mental model maps to Azure:

* AWS EC2 + Security Group → **Azure VM + NSG**
* Docker Hub → **Azure Container Registry (ACR)**
* GitHub Actions deploy via SSH → same approach works for Azure VM

Observability equivalents:

* AWS CloudWatch metrics/alarms → **Azure Monitor Metrics + Alert Rules**
* AWS CloudWatch Logs → **Log Analytics workspace**
* EC2 IAM role → **Managed Identity / RBAC**
* VM log shipping typically uses **Azure Monitor Agent + Data Collection Rules**

---

## What this project shows (why I built it)

This project proves I can:

* build and test a small API
* containerize it
* set up CI in GitHub Actions
* publish Docker images securely using secrets
* auto-deploy to a cloud VM and validate health
* provision infrastructure reproducibly with Terraform
* add basic monitoring (CloudWatch alarm)
* ship logs centrally to CloudWatch (no SSH required)
* understand traceable versions and basic rollback

Next step: Terraform **remote state** (S3 + DynamoDB lock).
