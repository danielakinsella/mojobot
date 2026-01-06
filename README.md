# Mojobot

Mojobot is an **Amazon Bedrock AgentCore + LangChain** service with supporting Terraform infrastructure for container builds, retrieval-augmented context, and an always-on diary store.

This repository is organized into two main parts:

- `agent/` — the containerized Bedrock AgentCore/LangChain agent service
- `terraform/` — infrastructure to build, deploy, and operate the service (ECR, Knowledge Base, S3 diary bucket, auto-ingestion Lambda, and GitHub Actions workflow)

---

## Architecture overview

### Runtime (Agent service)
- **LangChain agent** implemented in `agent/`.
- Runs as a container image stored in **Amazon ECR**.
- Designed to be used as a Bedrock AgentCore-backed service (AgentCore runtime calls your containerized service).
- Uses a **Bedrock Knowledge Base** for retrieval (RAG) to ground responses.
- Persists “diary” entries and other durable artifacts in an **S3 diary bucket**.

### Retrieval / Knowledge Base
- Terraform provisions a **Bedrock Knowledge Base**.
- A dedicated **S3 bucket** holds documents that are ingested into the Knowledge Base.
- An **auto-ingestion Lambda** is triggered by S3 object events to start (or request) ingestion updates so newly uploaded docs become searchable.

### CI/CD
- A **GitHub Actions workflow** builds the `agent/` container image and pushes it to ECR.
- Terraform can then reference the pinned image tag/digest (depending on how this repo is configured) to deploy the updated service.

---

## Repository layout

```
.
├── agent/                 # LangChain + Bedrock AgentCore service
│   ├── ...
│   ├── Dockerfile
│   └── (python project files)
├── terraform/             # Infrastructure-as-code
│   ├── ...
│   └── (modules, stacks, envs)
└── .github/workflows/     # CI pipelines (build/push image, etc.)
```

---

## Local development (agent/)

### Prerequisites
- Python (version per `agent/` project config)
- Docker
- AWS credentials available locally (for Bedrock / S3 / KB access)

### Setup
From the repo root:

```bash
cd agent

# Create a venv (example)
python -m venv .venv
source .venv/bin/activate

# Install dependencies (choose the correct command for the repo: requirements.txt / poetry / uv)
# Example:
pip install -r requirements.txt
```

### Run locally
How you start the agent depends on the actual web framework used (FastAPI/Flask/etc.). Common patterns:

```bash
# Example for FastAPI
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

If this repo uses a different entrypoint, follow the `agent/` package’s documented start command.

### Build the container locally

```bash
docker build -t mojobot-agent:dev ./agent

docker run --rm -p 8000:8000 \
  -e AWS_REGION="$AWS_REGION" \
  -e BEDROCK_REGION="$BEDROCK_REGION" \
  mojobot-agent:dev
```

---

## Deployment (terraform/)

### Prerequisites
- Terraform (version per `terraform/` configuration)
- AWS account + credentials with permissions to create:
  - ECR repositories
  - S3 buckets + event notifications
  - IAM roles/policies
  - Lambda function
  - Bedrock Knowledge Base resources
- (Optional) GitHub token/permissions if Terraform config manages GitHub Actions secrets

### Typical workflow

1. **Provision infra** (ECR, S3 buckets, KB, Lambda, IAM):

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

2. **Build and push agent image** via GitHub Actions (recommended) or manually.

3. **Deploy/roll forward** by applying Terraform again if the image tag/digest is wired into Terraform variables.

### Notes
- The *Knowledge Base documents bucket* is separate from the *diary bucket*.
- Uploading documents to the KB documents bucket triggers the auto-ingestion Lambda, which kicks off KB ingestion so content becomes available for retrieval.
- If you change ingestion behavior, IAM for the Lambda must include the required Bedrock permissions.

---

## Required environment variables

Environment variables are used both locally (for `agent/`) and in the deployed environment.

### AWS / Bedrock
- `AWS_REGION` — default AWS region for SDK calls.
- `BEDROCK_REGION` — region where Bedrock (and the Knowledge Base) lives (often same as `AWS_REGION`).
- `AWS_PROFILE` — (local dev) profile name, if not using env-based credentials.

### Knowledge Base / Retrieval
- `BEDROCK_KNOWLEDGE_BASE_ID` — Knowledge Base ID used for retrieval.
- `BEDROCK_KNOWLEDGE_BASE_DATA_SOURCE_ID` — (optional) Data Source ID if the agent triggers ingestion.

### Storage (Diary)
- `DIARY_BUCKET_NAME` — S3 bucket name used for diary persistence.
- `DIARY_PREFIX` — (optional) key prefix within the diary bucket.

### App configuration
- `LOG_LEVEL` — e.g. `INFO`, `DEBUG`.
- `PORT` — listen port for the container/service (if honored by the app).

> Note: The exact variable names the service expects may differ depending on the implementation inside `agent/`. If you see mismatches, align this README to the code’s config layer.

---

## GitHub Actions / CI configuration

The workflow typically requires the following GitHub repository secrets/variables:

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (or OIDC federation via `permissions: id-token: write`)
- `AWS_REGION`
- `ECR_REPOSITORY` (or Terraform outputs injected as secrets)

If using OIDC (recommended), configure an IAM role trust for GitHub and store:

- `AWS_ROLE_TO_ASSUME`

---

## Troubleshooting

- **Bedrock access errors**: confirm the region supports Bedrock + Knowledge Bases and that your IAM principal has access.
- **Ingestion not triggering**: confirm S3 event notifications are configured for the KB documents bucket and the Lambda has permissions.
- **Agent container cannot retrieve**: verify `BEDROCK_KNOWLEDGE_BASE_ID` and region variables.

---

## License

See repository license (if present).
