#!/usr/bin/env bash
# SessionStart hook: inject recent memories as startup context
# Reads the project memory directory and injects the 5 most recently modified
# memory files as additional context for the session.

# Find the project memory directory from Claude Code's project path
# Claude Code sets CLAUDE_PROJECT_DIR or we derive from cwd
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Claude Code names the folder after the path with every slash as a dash, KEEPING the leading dash
# (for example /home/user becomes -home-user). Try that first, then the dash-less spelling, then the cwd.
MEMORY_DIR=""
for P in "$PROJECT_DIR" "$(pwd)"; do
    SAFE_PATH=$(echo "$P" | sed 's|/|-|g')
    for C in "$SAFE_PATH" "${SAFE_PATH#-}"; do
        if [ -d "$HOME/.claude/projects/$C/memory" ]; then
            MEMORY_DIR="$HOME/.claude/projects/$C/memory"
            break 2
        fi
    done
done

[ ! -d "$MEMORY_DIR" ] && exit 0

# Find memory files with frontmatter (structured memories, not MEMORY.md)
MEMORY_FILES=$(find "$MEMORY_DIR" -maxdepth 1 -name "*.md" ! -name "MEMORY.md" \
    -newer "$MEMORY_DIR/MEMORY.md" -o -name "*.md" ! -name "MEMORY.md" 2>/dev/null | \
    head -20)

[ -z "$MEMORY_FILES" ] && exit 0

# Sort by modification time, take 5 most recent
RECENT=$(echo "$MEMORY_FILES" | xargs ls -t 2>/dev/null | head -5)

[ -z "$RECENT" ] && exit 0

# Build context injection
CONTEXT="## Saved notes (old, NOT VERIFIED as current: check live state before relying on any of them)\n"
for f in $RECENT; do
    NAME=$(basename "$f" .md)
    # Extract description from frontmatter
    DESC=$(grep -m1 "^description:" "$f" 2>/dev/null | sed 's/^description: *//')
    TYPE=$(grep -m1 -E "^[[:space:]]*type:" "$f" 2>/dev/null | sed -E 's/^[[:space:]]*type: *//')
    SAVED=$(date -r "$f" +%Y-%m-%d 2>/dev/null)
    if [ -n "$DESC" ]; then
        CONTEXT="${CONTEXT}- **${NAME}** (${TYPE}, saved ${SAVED}): ${DESC}\n"
    fi
done

echo -e "$CONTEXT"
