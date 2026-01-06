# Mojobot

A chatbot application powered by LangChain and Amazon Bedrock

## Architecture

## Requirements

1. Node.js 20+
2. AWS account with Bedrock access
3. Knowledge Base configured (see terraform)

## Setup

1. Clone the repository
2. Install dependencies: `npm install`
3. Configure environment variables
4. Run locally: `npm run dev`

## Deployment

Deployment is handled via GitHub Actions and Terraform

## Usage

## Technical tools used

- Node.js 20
- TypeScript
- Express
- LangChain
- @langchain/aws
- @aws-sdk/client-bedrock-agent-runtime
- Amazon Bedrock (Nova Lite model)
- Amazon Bedrock Knowledge Bases (S3 Vectors, Titan Embed Text v2)
- Amazon Bedrock AgentCore
- Amazon S3
- AWS Lambda
- Amazon ECR
- AWS IAM
- Amazon CloudWatch Logs
- AWS X-Ray
- Terraform
- GitHub Actions
- Docker
- Docker Buildx
- aws-actions/configure-aws-credentials
- aws-actions/amazon-ecr-login
- hashicorp/setup-terraform
- actions/checkout
