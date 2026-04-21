"""
Temporary stopgap — remove once sibling kb_stage_from_sql lands in
agent-knowledgebase v0.7.0. Tracking: data-etl-orchestrator ROADMAP.md FIELD-12.

Template script: reads rows from a source SQLite DB via a user-supplied SELECT
query and writes them to a single-table staging DB so that the `row_selector`
argument in `kb_ingest_batch` becomes trivial (SELECT * FROM <table_name>).

This is a TEMPLATE, not a library. Copy and adapt it for your ingestion workflow.
The MCP tool `kb_stage_from_sql` (agent-knowledgebase v0.7.0) will replace this
script with a first-class, server-side implementation.

Usage:
    python build_staging_db_template.py \\
        --source-db /abs/path/to/source.db \\
        --select "SELECT id, title, body FROM articles WHERE published=1" \\
        --target-db /abs/path/to/staging.db \\
        --table-name articles_staging \\
        [--overwrite]

Prints a single JSON summary line on success:
    {"source_db": "...", "target_db": "...", "table": "...", "rows_written": N}
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build a single-table SQLite staging DB from a SELECT query on a source DB. "
            "Temporary stopgap — see module docstring."
        )
    )
    parser.add_argument(
        "--source-db",
        required=True,
        help="Absolute path to the source SQLite database (opened read-only).",
    )
    parser.add_argument(
        "--select",
        required=True,
        dest="select_query",
        help="SELECT query to run against the source DB.",
    )
    parser.add_argument(
        "--target-db",
        required=True,
        help="Absolute path for the new staging SQLite DB. Created fresh each run.",
    )
    parser.add_argument(
        "--table-name",
        required=True,
        help="Name of the single table to create in the staging DB.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        default=False,
        help="If set, delete and recreate the target DB if it already exists.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    source_path = Path(args.source_db)
    target_path = Path(args.target_db)

    # --- Validate source ---
    if not source_path.exists():
        print(
            f"ERROR: source-db does not exist: {source_path}", file=sys.stderr
        )
        sys.exit(1)

    # --- Guard against overwriting target without --overwrite ---
    if target_path.exists():
        if args.overwrite:
            target_path.unlink()
        else:
            print(
                f"ERROR: target-db already exists: {target_path}\n"
                "Pass --overwrite to replace it.",
                file=sys.stderr,
            )
            sys.exit(1)

    # --- Step 1: Connect to source read-only ---
    src_conn = sqlite3.connect(f"file:{source_path}?mode=ro", uri=True)
    try:
        src_cursor = src_conn.cursor()

        # --- Step 2: Run SELECT and capture column names ---
        try:
            src_cursor.execute(args.select_query)
        except sqlite3.Error as exc:
            print(f"ERROR: SELECT query failed: {exc}", file=sys.stderr)
            sys.exit(1)

        columns = [desc[0] for desc in src_cursor.description]
        rows = src_cursor.fetchall()
    finally:
        src_conn.close()

    # --- Step 3: Connect to target (creates new DB) ---
    tgt_conn = sqlite3.connect(str(target_path))
    try:
        # --- Step 4: CREATE TABLE with all columns as TEXT ---
        # All columns are typed TEXT for maximum portability and simplicity.
        # Users can refine column types (INTEGER, REAL, BLOB) to match their schema.
        col_defs = ", ".join(f'"{col}" TEXT' for col in columns)
        tgt_conn.execute(
            f'CREATE TABLE "{args.table_name}" ({col_defs})'
        )

        # --- Step 5: Insert all rows ---
        placeholders = ", ".join("?" * len(columns))
        tgt_conn.executemany(
            f'INSERT INTO "{args.table_name}" VALUES ({placeholders})',
            # Cast every value to str so non-text source types survive the TEXT schema.
            ([str(v) if v is not None else None for v in row] for row in rows),
        )

        # --- Step 6: Commit and close ---
        tgt_conn.commit()
    finally:
        tgt_conn.close()

    # --- Step 7: Print summary ---
    summary = {
        "source_db": str(source_path),
        "target_db": str(target_path),
        "table": args.table_name,
        "rows_written": len(rows),
    }
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
