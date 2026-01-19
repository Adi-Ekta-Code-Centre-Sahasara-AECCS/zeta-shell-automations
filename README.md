# Sahasara Tech

A collection of projects including web applications and shell automation tools.

## Projects

### 1. Tesli Code (`tesilcord/`)

A token-based authentication platform with AI-powered support chat.

**Tech Stack:** Next.js 14, TypeScript, Tailwind CSS

**Features:**
- One Token Per User authentication system
- Cobra Agent ID system for support identification
- AI-powered support chat
- JWT-based session management
- Vercel-ready deployment

```bash
cd tesilcord
npm install
npm run dev
```

### 2. AECCS Book Downloader (`major-book-downloader-free/`)

A web application for searching and downloading free books from Open Library and Internet Archive.

**Tech Stack:** Next.js 15, React 18, TypeScript, Tailwind CSS, HeroUI

**Features:**
- Search millions of books from Open Library API
- Direct PDF downloads from Internet Archive
- Dark-themed responsive UI
- Keyboard shortcuts (Cmd+K / Ctrl+K)

```bash
cd major-book-downloader-free
npm install
npm run dev
```

### 3. ZETA Framework (`zeta/`)

A modular shell script execution framework for system automation and utilities.

**Usage:**
```bash
./zeta/zeta.sh -h                           # Show help
./zeta/zeta.sh -l                           # List modules
./zeta/zeta.sh -a                           # List all scripts
./zeta/zeta.sh memory_utils:system_memory   # Run a script
```

**Modules:**

| Module | Scripts | Description |
|--------|---------|-------------|
| `network_utils` | 5 | Network info, DNS lookup, port scanning, tracing |
| `file_processing` | 5 | File search, disk usage, duplicates, batch rename |
| `data_analytics` | 4 | CSV stats, JSON queries, log analysis, text stats |
| `llm_calls` | 4 | Anthropic, OpenAI, Ollama integrations |
| `memory_utils` | 4 | System memory, process memory, cache management |

**Example Commands:**
```bash
./zeta/zeta.sh network_utils:network_info
./zeta/zeta.sh memory_utils:system_memory
./zeta/zeta.sh file_processing:disk_usage /path/to/dir
./zeta/zeta.sh data_analytics:csv_stats data.csv
./zeta/zeta.sh llm_calls:anthropic_chat "Hello, Claude!"
```

## Testing

Run all tests with:

```bash
./test_all.sh
```

This script validates:
- Shell script syntax
- Help flags functionality
- Safe execution of read-only scripts
- Next.js project configuration

## Requirements

**For ZETA scripts:**
- Bash 4.0+
- Standard Unix utilities (awk, grep, sed)
- `bc` for calculations
- `curl` for network operations
- API keys for LLM scripts (set as environment variables)

**For Next.js projects:**
- Node.js 18+
- npm or yarn

## Environment Variables

For LLM integrations:
```bash
export ANTHROPIC_API_KEY="your-key"
export OPENAI_API_KEY="your-key"
```

## License

MIT
