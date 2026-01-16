# FastAPI Items API — CI/CD to Docker Hub + AWS EC2 (Auto-Deploy)

This is a small but realistic project I built (with the help of AI as a coach) to practice the core DevOps/Cloud workflow companies expect from a junior/intern: testing, containerization, CI, artifact publishing, and automatic deployment to a cloud VM.

---

## What I built (high level)

I built a simple FastAPI REST API for managing “items”, then made it production-shaped by adding:

* **Pytest tests** that run automatically
* **Docker** containerization
* **GitHub Actions CI** (tests on every push/PR)
* **Docker image build + push to Docker Hub** (on `main`)
* **Auto-deploy to AWS EC2 via SSH** (on `main`), including a health check

Goal: a clean “push to main → new version is deployed” loop.

---

## Tech stack

* Python 3.11+
* FastAPI
* Pytest (+ pytest-random-order)
* Docker
* GitHub Actions
* Docker Hub
* AWS EC2 (Ubuntu)

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
  * deploy to my EC2 instance (SSH)
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

This gives me a stable container name, automatic restarts after reboots, and a predictable exposed port.

### AWS networking

My EC2 Security Group allows:

* inbound **TCP 8000** for the API
* inbound **TCP 22** for SSH (ideally restricted to my IPs)

---

## GitHub Secrets I used

Repo → **Settings → Secrets and variables → Actions**

Docker Hub:

* `DOCKERHUB_USERNAME`
* `DOCKERHUB_TOKEN` (access token, not password)

EC2 deploy:

* `EC2_HOST` (public IP/DNS)
* `EC2_USER` (usually `ubuntu`)
* `EC2_SSH_KEY` (a dedicated deploy private key)

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

I practiced on AWS, but the same design maps to Azure:

* AWS EC2 + Security Group → **Azure VM + NSG**
* Docker Hub → **Azure Container Registry (ACR)**
* GitHub Actions deploy via SSH → same approach works for Azure VM
* Observability later:

  * AWS: CloudWatch
  * Azure: Azure Monitor + Application Insights

---

## What this project shows (why I built it)

This project proves I can:

* build and test a small API
* containerize it
* set up CI in GitHub Actions
* publish Docker images securely using secrets
* auto-deploy to a cloud VM and validate health
* understand traceable versions and basic rollback

Next steps I plan to add: Terraform (IaC) for provisioning the EC2 + security group, and basic monitoring/logging (CloudWatch / Azure Monitor).
