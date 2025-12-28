# Mojobot - Copilot Coding Agent Instructions

## Project Overview

Mojobot is an AWS Bedrock AgentCore-based chatbot that responds to queries with the personality of Mojo the cat. The project consists of a Node.js/TypeScript agent application containerized with Docker and deployed to AWS using Terraform.

**Repository Size:** Small (~192KB excluding dependencies)  
**Languages:** TypeScript, Terraform (HCL)  
**Runtime:** Node.js 20.x  
**Deployment:** AWS (ECS via Bedrock AgentCore, ECR for Docker images)

## Repository Structure

```
/
├── .github/
│   └── workflows/
│       └── terraform.yml          # CI/CD pipeline for AWS deployment
├── agent/                          # Node.js TypeScript application
│   ├── src/
│   │   └── index.ts               # Main application entry point (Express + LangChain)
│   ├── Dockerfile                 # Container configuration (CRITICAL: has known build issue)
│   ├── package.json               # Node dependencies and scripts
│   ├── package-lock.json          # Locked dependency versions (commit changes)
│   └── tsconfig.json              # TypeScript compiler configuration
├── terraform/                     # Infrastructure as Code
│   ├── main.tf                    # Main Terraform configuration and outputs
│   └── bedrock_agentcore.tf      # Bedrock AgentCore runtime resources
└── .gitignore                     # Excludes agent/node_modules only
```

## Build & Development Instructions

### Prerequisites
- **Node.js:** v20.19.6 (verify with `node --version`)
- **npm:** 10.8.2 (verify with `npm --version`)
- **Terraform:** 1.14.3 (only for infrastructure changes)
- **Docker:** 28.0.4+ (for local container testing)

### Local Development Workflow

**ALWAYS follow this exact sequence:**

1. **Install Dependencies** (REQUIRED before any other step)
   ```bash
   cd agent
   npm ci
   ```
   - Takes ~2-4 seconds
   - Use `npm ci` (not `npm install`) for consistent, reproducible builds from package-lock.json
   - NEVER commit node_modules directory

2. **Build TypeScript**
   ```bash
   npm run build
   ```
   - Takes <1 second
   - Compiles TypeScript from `src/` to `dist/`
   - Outputs: `dist/index.js` and `dist/index.d.ts`
   - Build artifacts in `dist/` are not committed (only added during Dockerfile build)

3. **Available npm Scripts**
   - `npm run build` - Compile TypeScript (runs `tsc`)
   - `npm run start` - Run compiled code (`node dist/index.js`)
   - `npm run dev` - Development mode with ts-node (`ts-node src/index.ts`)

4. **Testing Builds**
   - No test suite currently exists in the repository
   - Manual testing would require AWS credentials and running agent locally
   - Agent exposes two endpoints:
     - `GET /ping` - Health check (required by AgentCore)
     - `POST /invocations` - Main agent endpoint (required by AgentCore)

### Docker Build

⚠️ **CRITICAL KNOWN ISSUE WITH DOCKERFILE:**

The current `agent/Dockerfile` has a reproducible build failure. When building with Docker, `npm ci` encounters an internal npm error ("Exit handler never called!") that causes the installation to fail silently. This results in missing dependencies and the TypeScript compiler (`tsc`) not being available during the build step.

**Current Dockerfile (BROKEN):**
```dockerfile
FROM node:20-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci                    # ← FAILS silently in Docker environment
COPY tsconfig.json ./
COPY src ./src
RUN npm run build            # ← FAILS: "tsc: not found"
RUN npm prune --production
EXPOSE 8080
CMD ["node", "dist/index.js"]
```

**DO NOT attempt local Docker builds unless fixing this issue.** The CI/CD pipeline uses `docker buildx` with ARM64 architecture which may have different behavior.

**If you need to fix the Dockerfile**, potential solutions to investigate:
- Using full `node:20` image instead of `node:20-slim`
- Using `npm install` instead of `npm ci`
- Adding explicit npm cache clearing or npm version pinning
- Splitting the build into multiple stages

### Clean Build (from scratch)

```bash
cd agent
rm -rf node_modules dist
npm ci
npm run build
```
- Total time: ~3-4 seconds
- Use when switching branches or after pulling major changes

## CI/CD Pipeline

### GitHub Actions Workflow

**File:** `.github/workflows/terraform.yml`  
**Name:** "Deploy Mojobot"

**Triggers:**
- Push to `main` branch (full deployment)
- Pull requests to `main` (plan only)
- Manual workflow dispatch

**For Pull Requests:** Terraform plan is generated but NOT applied

**For Main Branch Pushes:** Full deployment sequence:

1. **Terraform Init** - Initialize Terraform in `terraform/` directory
2. **Terraform Apply (ECR only)** - Create/update ECR repository
   - Target: `aws_ecr_repository.mojobot_agent`
   - Gets ECR URL for Docker push
3. **Docker Build & Push**
   - Builds from `agent/Dockerfile` for `linux/arm64` platform
   - Uses `docker buildx build --platform linux/arm64`
   - Pushes to ECR with `:latest` tag
4. **Terraform Apply (Full)** - Deploy complete infrastructure
   - Creates Bedrock AgentCore runtime with container URI
   - Sets up IAM roles with necessary permissions (ECR, CloudWatch, Bedrock, X-Ray)

**AWS Configuration:**
- Region: `us-east-1`
- Terraform version: `1.14.3`
- Uses OIDC authentication (AWS_ROLE_ARN from secrets)

**Important Notes:**
- For agent code changes: Docker build happens in CI, not locally
- For Terraform changes: Use `terraform plan` in `terraform/` directory first
- Workflow uses `terraform_wrapper: false` for output parsing

## Application Architecture

### Agent Application (agent/src/index.ts)

**Framework:** Express.js with LangChain AWS integration

**Key Components:**
- **Model:** Amazon Bedrock Nova Lite (`amazon.nova-lite-v1:0`)
- **System Prompt:** Defines Mojo's personality (lines 18-23)
- **Required Endpoints:**
  - `GET /ping` → Returns `{ status: "healthy" }` (AgentCore requirement)
  - `POST /invocations` → Accepts `{ input: { prompt: string } }`, returns agent response

**Environment Variables:**
- `PORT` (default: 8080)
- `AWS_REGION` (default: us-east-1)

### Terraform Infrastructure

**Main Resources:**
1. **ECR Repository** (`aws_ecr_repository.mojobot_agent`)
   - Name: `mojobot-agent`
   - Image scanning enabled
   - Mutable tags
   - Force delete enabled

2. **IAM Role** (`aws_iam_role.mojobot_runtime_role`)
   - Assumed by: bedrock-agentcore.amazonaws.com
   - Permissions: ECR pull, CloudWatch logs, Bedrock model invocation, X-Ray tracing

3. **Bedrock AgentCore Runtime** (`aws_bedrockagentcore_agent_runtime.mojobot_runtime`)
   - Created only when `container_image_uri` variable is provided
   - Network mode: PUBLIC
   - Uses container from ECR

**Terraform Variables:**
- `app_name` (default: "mojobot")
- `container_image_uri` (required for runtime creation)
- `aws_region` (default: "us-east-1")

**Terraform Outputs:**
- `ecr_repository_url` - ECR repository URL
- `agentcore_runtime_id` - AgentCore runtime identifier (when created)

## Common Development Scenarios

### Making Agent Code Changes

1. Make changes to `agent/src/index.ts`
2. Test locally: `cd agent && npm ci && npm run build`
3. Commit and push to branch
4. Create PR → CI runs Terraform plan
5. Merge to main → CI builds Docker image and deploys

### Making Infrastructure Changes

1. Edit `terraform/*.tf` files
2. **Locally validate** (if Terraform installed):
   ```bash
   cd terraform
   terraform init
   terraform plan
   ```
3. Commit and push → CI will show plan in PR checks
4. Review plan output carefully before merging

### Adding Dependencies

1. Add to `agent/package.json` dependencies or devDependencies
2. Run `npm install <package>` to update package-lock.json
3. **ALWAYS commit package-lock.json changes**
4. Test build: `npm ci && npm run build`

### Modifying System Prompt

Edit the `systemPrompt` constant in `agent/src/index.ts` (line 18). This defines Mojo's personality and behavior. Be mindful of the character's established traits when modifying.

## Key Files Reference

**agent/package.json** - npm dependencies:
- Runtime: `express`, `@langchain/aws`, `@langchain/core`, `langchain`
- DevDependencies: `typescript`, `ts-node`, `@types/*`

**agent/tsconfig.json** - TypeScript configuration:
- Target: ES2022
- Module: commonjs
- Strict mode enabled
- Output: `./dist`, Source: `./src`

**.gitignore** - Only excludes `agent/node_modules`

## Troubleshooting

### "tsc: not found" during build
- Ensure you ran `npm ci` first
- Check that `node_modules/.bin/tsc` exists
- Try clean build: `rm -rf node_modules dist && npm ci && npm run build`

### Docker build fails
- See "CRITICAL KNOWN ISSUE WITH DOCKERFILE" section above
- Local Docker builds are not reliable - rely on CI/CD pipeline
- CI uses ARM64 platform which may behave differently

### Terraform state issues
- Terraform state is managed remotely (not in repository)
- Contact AWS administrator for state access issues

### Package-lock.json conflicts
- Resolve by running `npm ci` locally then committing the result
- Never manually edit package-lock.json

## Important Conventions

1. **Always run `npm ci` before building** - ensures consistent dependency versions
2. **Commit package-lock.json changes** - critical for reproducible builds
3. **Don't commit node_modules or dist/** - these are build artifacts
4. **Test TypeScript compilation** - run `npm run build` before committing
5. **Respect AgentCore requirements** - `/ping` and `/invocations` endpoints are mandatory
6. **Use Terraform for infrastructure** - don't manually create AWS resources

## Final Notes

- **No linting configured** - code style is not enforced automatically
- **No tests configured** - validate changes manually
- **Small codebase** - only 5 source files (1 TypeScript, 2 Terraform, 2 config files)
- **Active CI/CD** - every push to main triggers full deployment
- **AWS costs apply** - be mindful when testing infrastructure changes

When in doubt about build or deployment processes, trust these instructions and only explore further if information is incomplete or found to be in error.
