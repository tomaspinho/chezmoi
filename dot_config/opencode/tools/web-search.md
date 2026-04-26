# Web Search Tool

Custom opencode tool that performs web searches using Ollama Cloud's web search API.

## Setup

1. Create a free Ollama account at https://ollama.com
2. Get your API key at https://ollama.com/settings/keys
3. **Option A (Recommended):** Run `/connect` in opencode and select Ollama Cloud
   ```
   /connect
   ```
   This stores your API key in `~/.local/share/opencode/auth.json`

4. **Option B:** Set the environment variable:
   ```bash
   export OLLAMA_API_KEY=your-api-key-here
   ```

The tool will automatically try to read your API key from the auth file first, then fall back to the environment variable.

## Usage

The LLM can call this tool automatically when it needs current information from the web. You can also prompt it to search for something:

```
Search for the latest news about TypeScript 5.0
```

```
Look up the current weather in New York
```

```
What is Ollama's new engine?
```

## Tool Location

- **Project-specific**: `.opencode/tools/web-search.ts`
- **Global**: `~/.config/opencode/tools/web-search.ts`

## API Reference

The tool makes a POST request to `https://ollama.com/api/web_search` with:
- `query` (required): the search query string
- `max_results` (optional): maximum results to return (default 5, max 10)
- Bearer token authentication using `OLLAMA_API_KEY`

Returns search results containing:
- `title`: the title of the web page
- `url`: the URL of the web page
- `content`: relevant content snippet from the web page

## Example Response

```json
{
  "results": [
    {
      "title": "Ollama",
      "url": "https://ollama.com/",
      "content": "Cloud models are now available..."
    }
  ]
}
```
