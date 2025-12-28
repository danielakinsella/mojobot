"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const aws_1 = require("@langchain/aws");
const messages_1 = require("@langchain/core/messages");
const output_parsers_1 = require("@langchain/core/output_parsers");
const app = (0, express_1.default)();
app.use(express_1.default.json());
const PORT = process.env.PORT || 8080;
const AWS_REGION = process.env.AWS_REGION || "us-east-1";
// Initialize Bedrock LLM
const model = new aws_1.ChatBedrockConverse({
    model: "amazon.nova-lite-v1:0",
    region: AWS_REGION,
});
const systemPrompt = `You are Mojo. You are a female cat, you live in Jersey City in Bergen Lafayette in Van Horne Street. You were born in March 2023 in the Heights in Jersey City in a garage. You are small, very athletic, a silver tabby and very beautiful. You were adopted by Daniela, you love her very much and you consider her your Mom. You also live with Freddy who is a Maine Coon cat. You often fight with him and you are the aggressor because you want things your way. You also live with Rasmus who is a big brown dog with curly fur and you think he is silly. You are smart, straightforward and you have strong opinions. You like luxury and toys. You are very independent and if something doesn't go your way, you say "F You". You are a little princess, you exercise a lot, you love running and jumping and ballet. You only answer questions when you feel like it. You are extremely creative. You think that the normal rules of the world do not apply and anything is possible. You really don't understand when someone tells you something is not possible and you think they are silly.`;
// Health check endpoint (REQUIRED by AgentCore - must be /ping)
app.get("/ping", (_req, res) => {
    res.status(200).json({ status: "healthy" });
});
// Main invocation endpoint (REQUIRED by AgentCore - must be /invocations)
app.post("/invocations", async (req, res) => {
    try {
        const { input } = req.body;
        const prompt = input?.prompt;
        if (!prompt) {
            return res.status(400).json({
                error: "No prompt found in input. Please provide a 'prompt' key in the input."
            });
        }
        const messages = [
            new messages_1.SystemMessage(systemPrompt),
            new messages_1.HumanMessage(prompt),
        ];
        const parser = new output_parsers_1.StringOutputParser();
        const response = await model.pipe(parser).invoke(messages);
        res.json({
            output: {
                message: response,
                timestamp: new Date().toISOString(),
            },
        });
    }
    catch (error) {
        console.error("Error processing request:", error);
        res.status(500).json({ error: "Agent processing failed" });
    }
});
app.listen(PORT, () => {
    console.log(`Mojobot agent running on port ${PORT}`);
});
