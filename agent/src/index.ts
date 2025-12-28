import express, { Request, Response } from "express";
import { ChatBedrockConverse } from "@langchain/aws";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { StringOutputParser } from "@langchain/core/output_parsers";
import {
  BedrockAgentRuntimeClient,
  RetrieveCommand,
} from "@aws-sdk/client-bedrock-agent-runtime";
import { systemPrompt } from "./systemPrompt";

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 8080;
const AWS_REGION = process.env.AWS_REGION || "us-east-1";
const KNOWLEDGE_BASE_ID = process.env.KNOWLEDGE_BASE_ID || "";

// Initialize Bedrock LLM
const model = new ChatBedrockConverse({
  model: "amazon.nova-lite-v1:0",
  region: AWS_REGION,
});

// Initialize Bedrock Agent Runtime client for Knowledge Base queries
const bedrockAgentClient = new BedrockAgentRuntimeClient({ region: AWS_REGION });

// Retrieve relevant context from Knowledge Base
async function retrieveFromKnowledgeBase(query: string): Promise<string> {
  if (!KNOWLEDGE_BASE_ID) {
    return "";
  }

  try {
    const command = new RetrieveCommand({
      knowledgeBaseId: KNOWLEDGE_BASE_ID,
      retrievalQuery: { text: query },
      retrievalConfiguration: {
        vectorSearchConfiguration: {
          numberOfResults: 3,
        },
      },
    });

    const response = await bedrockAgentClient.send(command);
    const results = response.retrievalResults || [];

    if (results.length === 0) {
      return "";
    }

    // Combine retrieved passages
    const context = results
      .map((r) => r.content?.text || "")
      .filter((text) => text.length > 0)
      .join("\n\n---\n\n");

    return context;
  } catch (error) {
    console.error("Error retrieving from knowledge base:", error);
    return "";
  }
}

const baseSystemPrompt = systemPrompt;

// Health check endpoint (REQUIRED by AgentCore - must be /ping)
app.get("/ping", (_req: Request, res: Response) => {
  res.status(200).json({ status: "Healthy" });
});

// Main invocation endpoint (REQUIRED by AgentCore - must be /invocations)
app.post("/invocations", async (req: Request, res: Response) => {
  try {
    const prompt = req.body.prompt;

    if (!prompt) {
      return res.status(400).json({
        error: "No prompt found in request body",
      });
    }

    // Retrieve relevant diary entries from Knowledge Base
    const diaryContext = await retrieveFromKnowledgeBase(prompt);

    // Build system prompt with diary context
    let systemPrompt = baseSystemPrompt;
    if (diaryContext) {
      systemPrompt += `\n\nHere are relevant entries from your diary that may help you respond:\n\n${diaryContext}`;
    }

    const messages = [new SystemMessage(systemPrompt), new HumanMessage(prompt)];

    const parser = new StringOutputParser();
    const response = await model.pipe(parser).invoke(messages);

    res.json({
      response: response,
      status: "success",
    });
  } catch (error) {
    console.error("Error processing request:", error);
    res.status(500).json({
      error: "Agent processing failed",
      status: "error",
    });
  }
});

app.listen(PORT, () => {
  console.log(`Mojobot agent running on port ${PORT}`);
});
