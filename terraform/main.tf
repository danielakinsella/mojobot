terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 6.27"
    }
  }

  required_version = ">= 1.14.3"
}

output "agentcore_runtime_id" {
  description = "AgentCore Runtime ID"
  value       = aws_bedrockagentcore_agent_runtime.mojobot_runtime.agent_runtime_id
}
