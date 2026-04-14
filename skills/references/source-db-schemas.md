# Source DB Schemas

Ground truth on the source-MCP cache schemas the orchestrator reads. Used by Stage-3 batch construction to ensure `table`, `row_selector`, and dedup keys are correct.

---

## youtube-mcp

**Default path:** `W:\youtube_mcp_db\youtube-data.db`
**Env override:** `YOUTUBE_MCP_DB_PATH`

```sql
CREATE TABLE videos (
    video_id        TEXT PRIMARY KEY,
    title           TEXT,
    channel_id      TEXT,
    channel_title   TEXT,
    description     TEXT,
    published_at    TEXT,
    duration        TEXT,
    category_id     TEXT,
    default_language TEXT,
    thumbnail_url   TEXT,
    view_count      INTEGER,
    like_count      INTEGER,
    comment_count   INTEGER,
    tags_json       TEXT,
    source          TEXT,   -- 'search' | 'get_video_details' | 'playlist_items' | 'channel'
    saved_at        TEXT
);

CREATE TABLE transcripts (
    video_id         TEXT,
    language         TEXT,
    is_auto_generated INTEGER,
    full_text        TEXT,
    segments_json    TEXT,
    saved_at         TEXT,
    PRIMARY KEY (video_id, language)
);

CREATE TABLE playlists (
    playlist_id  TEXT PRIMARY KEY,
    title        TEXT,
    description  TEXT,
    published_at TEXT,
    item_count   INTEGER,
    saved_at     TEXT
);

CREATE TABLE playlist_items (
    playlist_item_id TEXT PRIMARY KEY,
    playlist_id      TEXT,
    video_id         TEXT,
    position         INTEGER,
    title            TEXT,
    channel_title    TEXT,
    video_published_at TEXT,
    saved_at         TEXT
);
```

The `source` column in `videos` records which tool populated the row. Valid values: `search`, `get_video_details`, `playlist_items`, `channel`.

### Dedup keys
- Videos: `video_id` (11-char YouTube ID)
- Transcripts: `(video_id, language)` — composite, supports multi-language ingestion

### Common `WHERE`-clause patterns
- By ID list: `video_id IN ('abc123', 'def456', ...)`
- By source tag: `source = 'playlist_items'`
- By date range: `published_at >= '2024-01-01'`
- By channel: `channel_id = 'UCxxxxxxxx'`
- Transcripts by ID: `video_id IN (...) AND language = 'en'`

---

## x-api-mcp

**Default path:** `~/.x-api-mcp/x-data.db`
**Env override:** `X_API_DB_PATH`

```sql
CREATE TABLE tweets (
    id                     TEXT PRIMARY KEY,
    text                   TEXT,
    note_tweet_text        TEXT,
    author_id              TEXT,
    conversation_id        TEXT,
    created_at             TEXT,
    retweet_count          INTEGER,
    reply_count            INTEGER,
    like_count             INTEGER,
    quote_count            INTEGER,
    impression_count       INTEGER,
    bookmark_count         INTEGER,
    entities_json          TEXT,
    referenced_tweets_json TEXT,
    saved_at               TEXT,
    source                 TEXT,   -- 'bookmarks' | 'search' | 'get_tweet' | 'user_tweets' | 'thread'
    title                  TEXT,
    summary                TEXT,
    tags_json              TEXT,
    category               TEXT,
    projects_json          TEXT,
    is_article             INTEGER
);

CREATE TABLE articles (
    id              TEXT PRIMARY KEY,
    tweet_id        TEXT,
    author_id       TEXT,
    author_username TEXT,
    content         TEXT,
    source          TEXT,   -- 'api' (note_tweet) | 'crawl' (server auto-crawled)
    url             TEXT,
    saved_at        TEXT
);

CREATE TABLE users (
    id                TEXT PRIMARY KEY,
    name              TEXT,
    username          TEXT,
    description       TEXT,
    followers_count   INTEGER,
    following_count   INTEGER,
    tweet_count       INTEGER,
    profile_image_url TEXT,
    verified          INTEGER,
    created_at        TEXT,
    url               TEXT,
    location          TEXT,
    saved_at          TEXT
);

CREATE TABLE media (
    media_key         TEXT PRIMARY KEY,
    tweet_id          TEXT,
    type              TEXT,
    url               TEXT,
    preview_image_url TEXT,
    alt_text          TEXT
);
```

The `source` column in `tweets` records which fetch tool populated the row. Valid values: `bookmarks`, `search`, `get_tweet`, `user_tweets`, `thread`.

The `source` column in `articles` is `api` for note_tweet content (full text already in the X API response) or `crawl` for content the server fetched via its internal Playwright crawler.

### Dedup keys
- Tweets: `tweet_id` (`id` column)
- Articles: `article_id` (`id` column). For note_tweet-sourced articles, `id == tweet_id`. For crawler-sourced articles, `id` is a server-generated UUID.
- Thread identity: `conversation_id` (shared across all tweets in a thread); individual tweet identity: `tweet_id`.

### Common `WHERE`-clause patterns
- By ID list: `id IN ('123456789', ...)`
- By source tag: `source = 'bookmarks'`
- By author: `author_id = '12345'`
- By date range: `created_at >= '2024-01-01T00:00:00Z'`
- Articles by tweet: `tweet_id IN (...)`
- Thread: `conversation_id = '<root_tweet_id>'`

---

## crawler-mcp

**Stateless — no DB.** All crawler-mcp outputs are returned in-memory and are not persisted. The orchestrator does not ingest directly from crawler-mcp. Web content scraped by x-api-mcp's internal Playwright crawler is stored in the `articles` table above. Standalone web targets would require a separate flow outside this plugin.
