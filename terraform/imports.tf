# Import blocks for existing resources
# These are declarative and will import resources if they exist but aren't in state
# Once imported, you can remove these blocks

import {
  to = aws_ecr_repository.mojobot_agent
  id = "mojobot-agent"
}

import {
  to = aws_iam_role.mojobot_runtime_role
  id = "mojobot-runtime-role"
}

import {
  to = aws_iam_role.mojobot_kb_role
  id = "mojobot-kb-role"
}
