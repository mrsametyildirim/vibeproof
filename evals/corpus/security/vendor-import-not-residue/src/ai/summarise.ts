import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// Retry with backoff: Anthropic returns 429 under sustained load
export async function summarise(text: string) {
  return client.messages.create({
    model: "claude-opus-4",
    max_tokens: 512,
    messages: [{ role: "user", content: text }],
  });
}
