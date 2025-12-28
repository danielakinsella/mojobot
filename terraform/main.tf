terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.27"
    }
  }

  required_version = ">= 1.14.3"

  backend "s3" {
    bucket = "mojobot-terraform-state"
    key    = "mojobot/terraform.tfstate"
    region = "us-east-1"
  }
}

output "agentcore_runtime_id" {
  description = "AgentCore Runtime ID"
  value       = length(aws_bedrockagentcore_agent_runtime.mojobot_runtime) > 0 ? aws_bedrockagentcore_agent_runtime.mojobot_runtime[0].agent_runtime_id : null
}

output "ecr_repository_url" {
  description = "ECR Repository URL for the agent image"
  value       = aws_ecr_repository.mojobot_agent.repository_url
}
