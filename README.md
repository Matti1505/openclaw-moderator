# OpenClaw YouTube Chat Moderator

A simple Python monitor for YouTube live chat messages.

## Current mode

This project currently runs in **monitor-only mode**.

It can:

- Read YouTube live chat messages
- Detect blocked words and phrases
- Print suspicious messages
- Respect the YouTube API polling interval

It does **not**:

- Delete messages
- Time out users
- Ban users
- Use Gemini to judge messages

## Requirements

- Python 3.10 or newer
- A YouTube Data API v3 key
- A valid YouTube live chat ID

## Installation

```bash
git clone https://github.com/YOUR-USERNAME/openclaw-youtube-chat-moderator.git
cd openclaw-youtube-chat-moderator
python -m venv .venv
```

### Linux

```bash
source .venv/bin/activate
pip install -r requirements.txt
```

### Windows PowerShell

```powershell
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Configuration

Copy the example file:

```bash
cp .env.example .env
```

The script reads these environment variables:

```text
YOUTUBE_API_KEY=your_api_key_here
YOUTUBE_LIVE_CHAT_ID=your_live_chat_id_here
```

### Linux

```bash
export YOUTUBE_API_KEY="your_api_key_here"
export YOUTUBE_LIVE_CHAT_ID="your_live_chat_id_here"
python youtube_chat_moderator.py
```

### Windows PowerShell

```powershell
$env:YOUTUBE_API_KEY="your_api_key_here"
$env:YOUTUBE_LIVE_CHAT_ID="your_live_chat_id_here"
python youtube_chat_moderator.py
```

## Security

Never commit your real API key to GitHub.

The `.gitignore` file prevents `.env` files from being uploaded accidentally.

## Important note

Deleting messages, timing out users, and banning users require OAuth 2.0 authentication and the correct YouTube moderator permissions. An API key alone is not enough.
