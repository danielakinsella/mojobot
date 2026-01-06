# Mojobot
Meet Mojo: a curious tabby cat who lives in this repo.

Mojobot is a friendly chatbot that answers questions in Mojo’s voice—playful, a little cheeky, and (usually) helpful.

## What it does
- Chat with Mojo about whatever’s on your mind
- Mojo can pull from a Diary (a small knowledge base) so answers can be grounded in “things Mojo knows”
- The Diary can be updated as Mojo learns new facts, stories, and preferences

## The Diary (knowledge base)
Think of the Diary as Mojo’s memory.

- Add new entries when Mojo discovers something
- Update or refine existing entries when details change
- Keep it lighthearted, factual, or both—Mojo won’t judge (much)

## How it’s built (quick peek)
Without getting too technical:

- Runs on AWS for the cloud bits
- Uses Terraform to set up infrastructure in a repeatable way
- Uses GitHub Actions to automatically test and deploy changes

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
