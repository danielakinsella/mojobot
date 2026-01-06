# Mojobot

Node/TypeScript Express agent with an Infrastructure-as-Code (Terraform) deployment.

## Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Local development](#local-development)
  - [Install](#install)
  - [Run](#run)
  - [Environment variables](#environment-variables)
  - [Scripts](#scripts)
- [Build & production](#build--production)
- [API](#api)
  - [Health](#health)
- [Terraform deployment](#terraform-deployment)
  - [Initialize](#initialize)
  - [Plan](#plan)
  - [Apply](#apply)
  - [Destroy](#destroy)
  - [Common variables](#common-variables)
- [CI/CD notes](#cicd-notes)
- [Troubleshooting](#troubleshooting)

## Overview

Mojobot is a small Express service written in TypeScript ("the agent"). It is designed to be run locally for development and deployed via Terraform for repeatable infrastructure provisioning.

## Architecture

- **Runtime**: Node.js + Express
- **Language**: TypeScript
- **HTTP**: JSON APIs
- **Infra**: Terraform (see `terraform/`)

> If your repository layout differs (for example, Terraform lives in a different folder), adjust the commands below accordingly.

## Prerequisites

- **Node.js**: LTS recommended (18+)
- **npm**: ships with Node (or use `pnpm`/`yarn` if the repo is configured)
- **Terraform**: 1.5+ recommended
- **Cloud credentials**: whatever provider your Terraform config targets (AWS/Azure/GCP). You must be authenticated before running `terraform plan/apply`.

## Local development

### Install

```bash
npm install
```

### Run

Most TypeScript Express services are run in one of these ways:

```bash
# common dev flow (if configured)
npm run dev

# or compile + run
npm run build
npm start
```

If your repo uses a different script name, see the [Scripts](#scripts) section and `package.json`.

### Environment variables

The exact variables depend on your implementation. These are typical defaults:

| Variable | Default | Description |
|---|---:|---|
| `PORT` | `3000` | HTTP listen port |
| `NODE_ENV` | `development` | Node environment |
| `LOG_LEVEL` | `info` | Application log level |

Create a local env file if your tooling supports it (for example `.env`):

```bash
PORT=3000
NODE_ENV=development
LOG_LEVEL=debug
```

### Scripts

Common scripts you may find in `package.json`:

- `dev`: start in watch mode (e.g. `ts-node-dev`, `tsx`, or `nodemon`)
- `build`: compile TypeScript to `dist/`
- `start`: run compiled output
- `lint`: run ESLint
- `test`: run tests

List all scripts:

```bash
npm run
```

## Build & production

Build the service:

```bash
npm run build
```

Run the compiled server:

```bash
npm start
```

Typical production process managers include Docker, systemd, ECS, or similar—depending on what Terraform provisions.

## API

### Health

Most deployments expose a basic health route. If implemented, it is commonly one of:

- `GET /health`
- `GET /healthz`
- `GET /`

Example:

```bash
curl -s http://localhost:3000/health | jq
```

If your service uses a different base path, inspect `src/routes` or the Express app setup.

## Terraform deployment

Terraform configuration is expected in `terraform/`.

> Ensure you are authenticated to the relevant cloud provider before running the commands.

### Initialize

```bash
cd terraform
terraform init
```

### Plan

```bash
terraform plan \
  -var-file="env/dev.tfvars"
```

### Apply

```bash
terraform apply \
  -var-file="env/dev.tfvars"
```

### Destroy

```bash
terraform destroy \
  -var-file="env/dev.tfvars"
```

### Common variables

Because Terraform modules differ, treat these as examples. Check `variables.tf` and any `*.tfvars` files in `terraform/env/`.

Common variable patterns:

- `project_name`: naming prefix
- `environment`: `dev` / `staging` / `prod`
- `region`: cloud region
- `image_tag` or `app_version`: version to deploy
- `cpu` / `memory`: task sizing (container platforms)
- `domain_name`: DNS name (if provisioning DNS/ingress)

## CI/CD notes

If you use GitHub Actions:

- Build/test on PRs
- On merge to `main`, build an artifact (or container image), then run a Terraform plan/apply in the target environment

Be careful to:

- Store secrets in GitHub Actions secrets/variables
- Use provider-specific auth (OIDC recommended where supported)
- Run `terraform fmt` and `terraform validate` in CI

## Troubleshooting

- **Port already in use**: change `PORT` or stop the conflicting process.
- **TypeScript build errors**: ensure Node version matches `.nvmrc`/engines (if present) and that `npm install` succeeded.
- **Terraform auth failures**: confirm cloud credentials, region, and backend configuration.
- **Terraform state issues**: verify backend (e.g. S3/GCS/AzureRM) and locking configuration.
