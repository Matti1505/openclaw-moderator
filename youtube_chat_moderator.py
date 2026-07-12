"""
OpenClaw YouTube Chat Moderator
GitHub-ready monitor-only example for the YouTube Data API v3.

Features:
- Reads messages from a YouTube live chat
- Detects blocked terms
- Prints suspicious messages
- Uses environment variables for secrets
- Does not delete messages or ban users

Required environment variables:
- YOUTUBE_API_KEY
- YOUTUBE_LIVE_CHAT_ID
"""

from __future__ import annotations

import os
import sys
import time
from typing import Any

import googleapiclient.discovery
import googleapiclient.errors


API_SERVICE_NAME = "youtube"
API_VERSION = "v3"

DEFAULT_POLL_INTERVAL = 10
MAX_RESULTS = 200

BLOCKED_TERMS = [
    "phishing",
    "free money",
    "scam",
    "crypto-gift",
]


def build_youtube_client() -> Any:
    """Create and return a YouTube Data API client."""
    developer_key = os.environ.get("YOUTUBE_API_KEY")

    if not developer_key:
        raise RuntimeError(
            "Missing YOUTUBE_API_KEY environment variable. "
            "Never commit a real API key to GitHub."
        )

    return googleapiclient.discovery.build(
        API_SERVICE_NAME,
        API_VERSION,
        developerKey=developer_key,
        cache_discovery=False,
    )


def get_live_chat_messages(
    youtube: Any,
    live_chat_id: str,
    page_token: str | None = None,
) -> dict[str, Any]:
    """
    Fetch recent messages from a YouTube live chat.

    Returns the complete API response so the caller can use:
    - items
    - nextPageToken
    - pollingIntervalMillis
    """
    request = youtube.liveChatMessages().list(
        liveChatId=live_chat_id,
        part="snippet,authorDetails",
        maxResults=MAX_RESULTS,
        pageToken=page_token,
    )
    return request.execute()


def check_messages(messages: list[dict[str, Any]]) -> None:
    """Print messages that match one or more blocked terms."""
    for message in messages:
        snippet = message.get("snippet", {})
        author_details = message.get("authorDetails", {})

        original_text = snippet.get("displayMessage", "")
        normalized_text = original_text.lower()

        author = author_details.get("displayName", "Unknown user")
        message_id = message.get("id", "Unknown message ID")

        matched_terms = [
            term for term in BLOCKED_TERMS if term in normalized_text
        ]

        if matched_terms:
            print("=" * 60)
            print("[FLAGGED MESSAGE]")
            print(f"Author: {author}")
            print(f"Message: {original_text}")
            print(f"Message ID: {message_id}")
            print(f"Matched terms: {', '.join(matched_terms)}")
            print("=" * 60)


def run_monitor() -> int:
    """Continuously monitor a YouTube live chat."""
    live_chat_id = os.environ.get("YOUTUBE_LIVE_CHAT_ID")

    if not live_chat_id:
        print(
            "Missing YOUTUBE_LIVE_CHAT_ID environment variable.",
            file=sys.stderr,
        )
        return 1

    try:
        youtube = build_youtube_client()
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1

    print("OpenClaw YouTube Chat Moderator")
    print("Mode: monitor only")
    print("No messages will be deleted.")
    print("No users will be timed out or banned.")
    print("Press Ctrl+C to stop.\n")

    page_token: str | None = None
    poll_interval = DEFAULT_POLL_INTERVAL

    try:
        while True:
            try:
                response = get_live_chat_messages(
                    youtube=youtube,
                    live_chat_id=live_chat_id,
                    page_token=page_token,
                )

                messages = response.get("items", [])
                page_token = response.get("nextPageToken")

                polling_interval_ms = response.get("pollingIntervalMillis")
                if polling_interval_ms:
                    poll_interval = max(
                        polling_interval_ms / 1000,
                        1,
                    )

                if messages:
                    print(f"Received {len(messages)} message(s).")
                    check_messages(messages)

                time.sleep(poll_interval)

            except googleapiclient.errors.HttpError as error:
                status = getattr(error.resp, "status", "unknown")
                print(
                    f"YouTube API error ({status}): {error}",
                    file=sys.stderr,
                )

                if status in (403, 429):
                    print(
                        "The API quota may be exhausted or the request "
                        "may be rate-limited. Monitoring stopped.",
                        file=sys.stderr,
                    )
                    return 2

                time.sleep(30)

    except KeyboardInterrupt:
        print("\nMonitoring stopped by user.")
        return 0


if __name__ == "__main__":
    raise SystemExit(run_monitor())
