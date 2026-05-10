// Lightweight Anthropic API client — replaces @anthropic-ai/sdk (~3 MB).
// Uses native fetch(). Compatible with Cloudflare Workers.

const API_BASE = 'https://api.anthropic.com/v1'
const DEFAULT_VERSION = '2023-06-01'

interface Message {
  role: 'user' | 'assistant'
  content: string
}

interface CreateMessageParams {
  model: string
  max_tokens: number
  messages: Message[]
  system?: string
  temperature?: number
}

interface ContentBlock {
  type: 'text'
  text: string
}

interface MessageResponse {
  id: string
  type: 'message'
  role: 'assistant'
  content: ContentBlock[]
  model: string
  stop_reason: string
  usage: { input_tokens: number; output_tokens: number }
}

export class AnthropicClient {
  private apiKey: string

  constructor(apiKey?: string) {
    this.apiKey = apiKey ?? process.env.ANTHROPIC_API_KEY ?? ''
  }

  messages = {
    create: async (params: CreateMessageParams): Promise<MessageResponse> => {
      const res = await fetch(`${API_BASE}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': DEFAULT_VERSION,
        },
        body: JSON.stringify(params),
      })
      if (!res.ok) {
        const body = await res.text().catch(() => '')
        throw new Error(`Anthropic API error ${res.status}: ${body}`)
      }
      return res.json() as Promise<MessageResponse>
    },
  }
}

// Drop-in replacement for `new Anthropic()`
export default AnthropicClient
