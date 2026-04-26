import { tool } from "@opencode-ai/plugin"
import { readFileSync } from "fs"
import { homedir } from "os"
import { join } from "path"

export default tool({
  description: "Search the web using Ollama Cloud for current information, news, and real-time data to reduce hallucinations and improve accuracy",
  args: {
    query: tool.schema.string().describe("The search query to look up on the web"),
    max_results: tool.schema.number().optional().describe("Maximum results to return (default 5, max 10)"),
  },
  async execute(args, context) {
    let apiKey = process.env.OLLAMA_API_KEY
    
    if (!apiKey) {
      try {
        const authPath = join(homedir(), ".local/share/opencode/auth.json")
        const authData = JSON.parse(readFileSync(authPath, "utf-8"))
        
        if (authData.ollama && authData.ollama.api) {
          apiKey = authData.ollama.api
        } else if (authData["ollama-cloud"] && authData["ollama-cloud"].key) {
          apiKey = authData["ollama-cloud"].key
        } else if (authData.ollama_cloud && authData.ollama_cloud.key) {
          apiKey = authData.ollama_cloud.key
        }
      } catch (error) {
        throw new Error(
          "Could not read Ollama Cloud API key from auth.json. " +
          "Either set OLLAMA_API_KEY environment variable or configure Ollama Cloud via /connect command. " +
          "Get API key at https://ollama.com/settings/keys. " +
          "Error: " + error
        )
      }
    }

    if (!apiKey) {
      throw new Error(
        "Ollama Cloud API key not found. " +
        "Run '/connect' and select Ollama Cloud, or set OLLAMA_API_KEY environment variable. " +
        "Get API key at https://ollama.com/settings/keys"
      )
    }

    const url = "https://ollama.com/api/web_search"
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        query: args.query,
        max_results: args.max_results || 5,
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Web search failed: ${response.status} ${errorText}`)
    }

    const data = await response.json()
    return JSON.stringify(data, null, 2)
  },
})
