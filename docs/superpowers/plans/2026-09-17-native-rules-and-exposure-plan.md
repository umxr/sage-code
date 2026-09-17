# Native Rules and Measured Exposure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish each SAGE-Code heuristic as a rule file in `.claude/rules/sage/` that Claude Code loads itself, and record each rule load so that the meta-evaluator has measured exposure data.

**Architecture:** `.sage/knowledge/*.md` stays the source of truth. A deterministic script, `bin/sage-publish-rules`, writes one rule file per heuristic (with `paths:` frontmatter from a new `Paths` field). A new `InstructionsLoaded` hook appends `rule_loaded` events to the session log. A second deterministic script, `bin/sage-exposure`, aggregates those events into `.sage/meta/exposure.json`, which the meta-evaluator and the curator read.

**Tech Stack:** Bash scripts with Python 3 heredoc bodies (standard library only), bats-core tests, Claude Code plugin files (`hooks.json`, `SKILL.md`, agent markdown).

**Spec:** `docs/superpowers/specs/2026-09-17-native-rules-and-exposure-design.md`

## Execution notes (added after execution, 2026-09-17)

The plan was executed with subagent-driven development. The task reviews found four points that the plan text below does not show. The committed code is correct; the code blocks below are the text as it was at the start.

1. **Task 1, `CLAUDE.md` cleanup (commit `1f669e3`).** The plan code normalized blank lines in the full `CLAUDE.md` file, against the spec ("It changes no other text"). The committed script changes only the removed section and the blank lines directly next to it. One test was added ("removing the managed section changes no other text in CLAUDE.md"). Thus each test total below is 1 too low: the real totals are 102 after Task 1, 111 after Task 2, 115 after Task 3, and 126 after Task 4.
2. **Task 5, `Paths` limit at merge time (commit `8450da3`).** The plan text for the reflector (Step 4, duplicate case) and the curator (Deduplicate) did not repeat the limit of 5 patterns. The committed prompts keep at most 5 patterns, replace patterns with one wider pattern when necessary, never make the scope narrower, and give a merged entry no `Paths` field when one of the merged entries has none. The spec has the same wording now.
3. **Task 6, two stale README sentences (commit `479db9a`).** The plan did not list "How it works" item 1 in the root `README.md` and the "Replays" and "Self-evaluates" bullets in the plugin `README.md`. They are corrected.
4. **Commit messages.** The Task 4 implementer put the `Co-Authored-By` trailer in the subject line; the message was amended before the review (`65f1488`). The Task 6 commits have the trailer `Claude Sonnet 5`, because a Sonnet 5 subagent wrote them.

## Global Constraints

- Branch: `feat/native-rules-and-exposure` (it exists; the spec is committed on it). Do all work on this branch.
- All paths in this plan are relative to the repository root, `/Users/umar/Desktop/Projects/sage-code`. The plugin is in the `sage-code/` subdirectory.
- Python: standard library only. No `pip install`.
- Each hook and script exits with 0 and prints nothing when `.sage/` does not exist. SAGE-Code must not break a session.
- Hook scripts read `session_id` and all event data from the stdin JSON, never from environment variables. The project directory is `${SAGE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}`.
- Scripts in `bin/` have no file extension and the executable bit, so that Claude can run them as bare commands (the plugin `bin/` directory is on the `PATH` of the Bash tool; this was confirmed with `claude --plugin-dir`).
- In bats tests, never assert with `! grep`. bats does not fail a test on a negated command. Use the `refute_grep` helper from Task 1.
- Rule ID format: `<category>-<slug>`. Categories: `pitfalls`→`pitfall`, `strategies`→`strategy`, `preferences`→`preference`, `architecture`→`architecture`, `conventions`→`convention`. Slug: lower case, each run of characters that are not `a-z0-9` becomes one `-`, trimmed, cut to 60 characters.
- Rule files go in `.claude/rules/sage/` only. SAGE-Code owns that directory and no other part of `.claude/`.
- Run the full suite with `bash sage-code/tests/run-all.sh`. At the start of this plan it has 86 passing tests.
- Commit messages use the conventional format of the repository (`feat:`, `fix:`, `docs:`, `chore:`) and end with the line `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Target version: 0.3.0.

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `sage-code/bin/sage-publish-rules` | Create | Knowledge files → rule files; removes the old `CLAUDE.md` section |
| `sage-code/bin/sage-exposure` | Create | Event logs → `.sage/meta/exposure.json` |
| `sage-code/hooks/scripts/on-instructions-loaded.sh` | Create | `InstructionsLoaded` event → `rule_loaded` event |
| `sage-code/hooks/hooks.json` | Modify | Register the new hook |
| `sage-code/hooks/scripts/on-session-start.sh` | Modify | New-session detection by event, not by file size; context only when Claude has a task |
| `sage-code/hooks/scripts/on-session-end.sh` | Modify | `rules_loaded` in the summary |
| `sage-code/templates/config-default.json` | Modify | `publish_min_confidence`; remove 3 dead keys |
| `sage-code/templates/gitignore-template` | Modify | Ignore `meta/exposure.json` |
| `sage-code/agents/*.md`, `sage-code/skills/*/SKILL.md` | Modify | `Paths` field, exposure scoring, publish steps |
| `sage-code/tests/test-sage-publish-rules.bats` | Create | Tests for the publish script |
| `sage-code/tests/test-on-instructions-loaded.bats` | Create | Tests for the new hook |
| `sage-code/tests/test-sage-exposure.bats` | Create | Tests for the exposure script |
| `sage-code/tests/test_helper.bash` | Modify | `refute_grep`, `instructions_loaded_payload` |
| `sage-code/tests/test-on-session-start.bats`, `test-on-session-end.bats` | Modify | New behaviour |
| `README.md`, `sage-code/README.md`, `CHANGELOG.md`, `sage-code/.claude-plugin/plugin.json`, 2026-04-15 spec | Modify | Documentation and version |

---

### Task 1: `sage-publish-rules` script

**Files:**
- Create: `sage-code/bin/sage-publish-rules`
- Create: `sage-code/tests/test-sage-publish-rules.bats`
- Modify: `sage-code/tests/test_helper.bash` (add `refute_grep`)
- Modify: `sage-code/templates/config-default.json`

**Interfaces:**
- Consumes: `.sage/knowledge/{pitfalls,strategies,preferences,architecture,conventions}.md` entries (`### heading` + `- **Field:** value` lines), `.sage/meta/config.json` key `publish_min_confidence`.
- Produces: command `sage-publish-rules [project-dir]`; files `.claude/rules/sage/<rule-id>.md`; the last stdout line is `sage-publish-rules: N published (W written, U unchanged), R removed`. Test helper `refute_grep <pattern> <file>`.

- [ ] **Step 1: Add the `refute_grep` helper**

In `sage-code/tests/test_helper.bash`, insert this block immediately before the line `# ── Hook input builders ────…`:

````bash
# refute_grep <pattern> <file> — fails if a line of the file matches.
# Use this, not `! grep`: bats does not fail a test on a negated command.
refute_grep() {
  if grep -q -- "$1" "$2"; then
    echo "unexpected match for '$1' in $2" >&2
    return 1
  fi
}
````

- [ ] **Step 2: Write the failing tests**

Create `sage-code/tests/test-sage-publish-rules.bats`:

````bash
#!/usr/bin/env bats

load test_helper

PUBLISH=""
RULES_DIR=""

setup() {
  setup_sage_env
  PUBLISH="$SCRIPT_DIR/bin/sage-publish-rules"
  init_sage
  RULES_DIR="$TEST_DIR/.claude/rules/sage"
}

teardown() {
  teardown_sage_env
}

# add_entry <knowledge file name> <heading> <confidence> <rule text> [paths]
add_entry() {
  {
    printf '\n### %s\n' "$2"
    printf -- '- **Confidence:** %s (1 observation)\n' "$3"
    printf -- '- **Scope:** project\n'
    if [ -n "${5:-}" ]; then printf -- '- **Paths:** %s\n' "$5"; fi
    printf -- '- **Rule:** %s\n' "$4"
    printf -- '- **Evidence:** sessions abc123\n'
    printf -- '- **Added:** 2026-09-17\n'
    printf -- '- **Last seen:** 2026-09-17\n'
  } >> "$TEST_DIR/.sage/knowledge/$1.md"
}

@test "publishes one file per entry, named by rule ID" {
  add_entry pitfalls "NEVER use md5 for password hashing" low "Use bcrypt."
  add_entry conventions "ALWAYS use the imperative mood" low "Write 'Add login'."
  run "$PUBLISH" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -f "$RULES_DIR/pitfall-never-use-md5-for-password-hashing.md" ]
  [ -f "$RULES_DIR/convention-always-use-the-imperative-mood.md" ]
  [ "$(ls "$RULES_DIR" | wc -l | tr -d ' ')" -eq 2 ]
}

@test "rule file has the heading and the rule text, and no metadata" {
  add_entry pitfalls "NEVER use md5" medium "Use bcrypt for passwords."
  "$PUBLISH" "$TEST_DIR"
  FILE="$RULES_DIR/pitfall-never-use-md5.md"
  grep -q '^# NEVER use md5$' "$FILE"
  grep -q '^Use bcrypt for passwords\.$' "$FILE"
  refute_grep 'Confidence' "$FILE"
  refute_grep 'Evidence' "$FILE"
  refute_grep 'abc123' "$FILE"
  refute_grep 'Last seen' "$FILE"
}

@test "Paths field becomes paths frontmatter" {
  add_entry pitfalls "NEVER use md5" low "Use bcrypt." 'src/auth/**, `src/**/*.{ts,tsx}`'
  "$PUBLISH" "$TEST_DIR"
  FILE="$RULES_DIR/pitfall-never-use-md5.md"
  [ "$(head -1 "$FILE")" = "---" ]
  grep -q '^  - "src/auth/\*\*"$' "$FILE"
  grep -q '^  - "src/\*\*/\*\.{ts,tsx}"$' "$FILE"
}

@test "entry with no Paths field has no frontmatter" {
  add_entry conventions "ALWAYS use the imperative mood" low "Write 'Add login'."
  "$PUBLISH" "$TEST_DIR"
  FILE="$RULES_DIR/convention-always-use-the-imperative-mood.md"
  [[ "$(head -1 "$FILE")" == "<!-- Generated by sage-code"* ]]
  refute_grep '^paths:' "$FILE"
}

@test "Rule value that continues on an indented line is joined" {
  cat >> "$TEST_DIR/.sage/knowledge/pitfalls.md" <<'MD'

### NEVER use md5
- **Confidence:** low (1 observation)
- **Rule:** Use bcrypt for passwords.
  md5 is not safe.
- **Evidence:** sessions abc123
MD
  "$PUBLISH" "$TEST_DIR"
  grep -q '^Use bcrypt for passwords\. md5 is not safe\.$' "$RULES_DIR/pitfall-never-use-md5.md"
}

@test "publish_min_confidence filters entries" {
  add_entry pitfalls "Low rule" low "Low."
  add_entry pitfalls "Medium rule" medium "Medium."
  add_entry pitfalls "High rule" high "High."
  python3 - "$TEST_DIR/.sage/meta/config.json" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
cfg["publish_min_confidence"] = "medium"
json.dump(cfg, open(sys.argv[1], "w"), indent=2)
PY
  "$PUBLISH" "$TEST_DIR"
  [ ! -f "$RULES_DIR/pitfall-low-rule.md" ]
  [ -f "$RULES_DIR/pitfall-medium-rule.md" ]
  [ -f "$RULES_DIR/pitfall-high-rule.md" ]
}

@test "second entry with the same rule ID gets the suffix -2" {
  add_entry pitfalls "NEVER use md5" low "First."
  add_entry pitfalls "Never use MD5!" low "Second."
  "$PUBLISH" "$TEST_DIR"
  grep -q '^First\.$'  "$RULES_DIR/pitfall-never-use-md5.md"
  grep -q '^Second\.$' "$RULES_DIR/pitfall-never-use-md5-2.md"
}

@test "file of a pruned entry is deleted, files outside sage/ are kept" {
  add_entry pitfalls "NEVER use md5" low "Use bcrypt."
  "$PUBLISH" "$TEST_DIR"
  echo "# team rule" > "$TEST_DIR/.claude/rules/team.md"
  # Prune: put the knowledge file back to its empty state
  printf '# Pitfalls\n' > "$TEST_DIR/.sage/knowledge/pitfalls.md"
  run "$PUBLISH" "$TEST_DIR"
  [[ "$output" == *"1 removed"* ]]
  [ ! -f "$RULES_DIR/pitfall-never-use-md5.md" ]
  [ -f "$TEST_DIR/.claude/rules/team.md" ]
}

@test "absolute and parent patterns are dropped" {
  add_entry pitfalls "NEVER use md5" low "Use bcrypt." "/etc/passwd, ../outside/**, src/auth/**"
  "$PUBLISH" "$TEST_DIR"
  FILE="$RULES_DIR/pitfall-never-use-md5.md"
  grep -q '^  - "src/auth/\*\*"$' "$FILE"
  refute_grep 'passwd' "$FILE"
  refute_grep 'outside' "$FILE"
}

@test "entry with no valid pattern is published with no path scope, with a warning" {
  add_entry pitfalls "NEVER use md5" low "Use bcrypt." "/etc/passwd"
  run "$PUBLISH" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning"*"no valid pattern"* ]]
  refute_grep '^paths:' "$RULES_DIR/pitfall-never-use-md5.md"
}

@test "second run with no change writes nothing" {
  add_entry pitfalls "NEVER use md5" low "Use bcrypt."
  "$PUBLISH" "$TEST_DIR"
  FILE="$RULES_DIR/pitfall-never-use-md5.md"
  touch -t 202001010000 "$FILE"
  run "$PUBLISH" "$TEST_DIR"
  [[ "$output" == *"0 written, 1 unchanged"* ]]
  [ "$(date -r "$FILE" +%Y)" = "2020" ]
}

@test "removes the CLAUDE.md managed section when the two markers are there" {
  cat > "$TEST_DIR/CLAUDE.md" <<'MD'
# Project

Keep this.

## Sage Learnings
<!-- Auto-managed by sage-code plugin. Do not edit below this line. -->
- old rule
<!-- End sage-code managed section -->

## After
Keep this too.
MD
  "$PUBLISH" "$TEST_DIR"
  refute_grep 'Sage Learnings' "$TEST_DIR/CLAUDE.md"
  refute_grep 'old rule' "$TEST_DIR/CLAUDE.md"
  grep -q '^Keep this\.$' "$TEST_DIR/CLAUDE.md"
  grep -q '^## After$' "$TEST_DIR/CLAUDE.md"
  grep -q '^Keep this too\.$' "$TEST_DIR/CLAUDE.md"
}

@test "changes nothing in CLAUDE.md when the end marker is absent" {
  printf '# Project\n\n## Sage Learnings\n<!-- Auto-managed by sage-code plugin. Do not edit below this line. -->\n- old rule\n' > "$TEST_DIR/CLAUDE.md"
  cp "$TEST_DIR/CLAUDE.md" "$TEST_DIR/CLAUDE.md.before"
  "$PUBLISH" "$TEST_DIR"
  cmp "$TEST_DIR/CLAUDE.md" "$TEST_DIR/CLAUDE.md.before"
}

@test "exits silently when .sage/ directory is missing" {
  EMPTY_DIR=$(mktemp -d)
  run "$PUBLISH" "$EMPTY_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -d "$EMPTY_DIR/.claude" ]
  rm -rf "$EMPTY_DIR"
}

@test "default config template publishes low confidence entries" {
  add_entry pitfalls "Low rule" low "Low."
  "$PUBLISH" "$TEST_DIR"
  [ -f "$RULES_DIR/pitfall-low-rule.md" ]
  run python3 -c "import json; print(json.load(open('$TEST_DIR/.sage/meta/config.json'))['publish_min_confidence'])"
  [ "$output" = "low" ]
}
````

- [ ] **Step 3: Run the tests to verify that they fail**

Run: `bats sage-code/tests/test-sage-publish-rules.bats`
Expected: all 15 tests FAIL. The first failure says that `…/bin/sage-publish-rules` does not exist (status 127).

- [ ] **Step 4: Write the script**

Create `sage-code/bin/sage-publish-rules`:

````bash
#!/usr/bin/env bash
set -euo pipefail

# Publishes the heuristics in .sage/knowledge/*.md as rule files in
# .claude/rules/sage/, one file per heuristic. Claude Code loads these files
# itself. A rule with a Paths field loads only when Claude reads a matching file.
#
# Usage: sage-publish-rules [project-dir]

PROJECT_DIR="${1:-${SAGE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}}"

# ── Exit silently if .sage/ doesn't exist ─────────────────────────────────
[ -d "$PROJECT_DIR/.sage" ] || exit 0

export _SAGE_PROJECT_DIR="$PROJECT_DIR"

python3 << 'PYEOF'
import glob, json, os, re, sys

project   = os.environ["_SAGE_PROJECT_DIR"]
sage_dir  = os.path.join(project, ".sage")
rules_dir = os.path.join(project, ".claude", "rules", "sage")

CATEGORIES = {
    "pitfalls":     "pitfall",
    "strategies":   "strategy",
    "preferences":  "preference",
    "architecture": "architecture",
    "conventions":  "convention",
}
LEVELS = {"low": 0, "medium": 1, "high": 2}

def warn(message):
    print(f"sage-publish-rules: warning: {message}", file=sys.stderr)

# ── Config ────────────────────────────────────────────────────────────────
min_confidence = "low"
try:
    with open(os.path.join(sage_dir, "meta", "config.json")) as f:
        min_confidence = str(json.load(f).get("publish_min_confidence", "low")).lower()
except (OSError, json.JSONDecodeError):
    pass
if min_confidence not in LEVELS:
    warn(f"unknown publish_min_confidence '{min_confidence}', using 'low'")
    min_confidence = "low"

# ── Parse knowledge entries ───────────────────────────────────────────────
FIELD = re.compile(r"^- \*\*([^*:]+):\*\*\s*(.*)$")

def parse_entries(path):
    """Return a list of {"heading": str, "fields": {lowercase name: value}}."""
    entries, entry, field = [], None, None
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("### "):
                entry = {"heading": line[4:].strip(), "fields": {}}
                entries.append(entry)
                field = None
                continue
            if entry is None:
                continue
            match = FIELD.match(line)
            if match:
                field = match.group(1).strip().lower()
                entry["fields"][field] = match.group(2).strip()
            elif field and line[:1] in (" ", "\t") and line.strip():
                # A value that continues on an indented line
                entry["fields"][field] += " " + line.strip()
            else:
                field = None
    return entries

def slugify(heading):
    slug = re.sub(r"[^a-z0-9]+", "-", heading.lower()).strip("-")
    return slug[:60].rstrip("-") or "rule"

def split_patterns(value):
    """Split on commas, but not on the commas inside {a,b} brace groups."""
    patterns, current, depth = [], "", 0
    for char in value:
        if char == "{":
            depth += 1
        elif char == "}":
            depth = max(0, depth - 1)
        if char == "," and depth == 0:
            patterns.append(current)
            current = ""
        else:
            current += char
    patterns.append(current)
    return [p.strip().strip("`\"'").strip() for p in patterns]

def valid_pattern(pattern):
    if not pattern:
        return False
    if pattern.startswith(("/", "~")) or re.match(r"^[A-Za-z]:", pattern):
        return False
    return ".." not in re.split(r"[\\/]", pattern)

def render(heading, rule, patterns, source):
    parts = []
    if patterns:
        parts.append("---\npaths:\n")
        for pattern in patterns:
            escaped = pattern.replace("\\", "\\\\").replace('"', '\\"')
            parts.append(f'  - "{escaped}"\n')
        parts.append("---\n")
    parts.append(
        f"<!-- Generated by sage-code from .sage/knowledge/{source}. "
        "Do not edit this file. Edit the knowledge entry. -->\n\n"
    )
    parts.append(f"# {heading}\n\n{rule}\n")
    return "".join(parts)

# ── Build the set of rule files ───────────────────────────────────────────
wanted, used_ids = {}, {}
for name, category in CATEGORIES.items():
    path = os.path.join(sage_dir, "knowledge", f"{name}.md")
    if not os.path.isfile(path):
        continue
    for entry in parse_entries(path):
        fields = entry["fields"]
        rule = fields.get("rule", "")
        if not rule:
            warn(f"{name}.md: entry '{entry['heading']}' has no Rule field, skipped")
            continue

        base = f"{category}-{slugify(entry['heading'])}"
        used_ids[base] = used_ids.get(base, 0) + 1
        rule_id = base if used_ids[base] == 1 else f"{base}-{used_ids[base]}"

        words = fields.get("confidence", "low").split()
        confidence = words[0].lower() if words else "low"
        if LEVELS.get(confidence, 0) < LEVELS[min_confidence]:
            continue

        patterns = []
        if "paths" in fields:
            patterns = [p for p in split_patterns(fields["paths"]) if valid_pattern(p)]
            if not patterns:
                warn(f"{rule_id}: no valid pattern in Paths, published with no path scope")

        wanted[f"{rule_id}.md"] = render(entry["heading"], rule, patterns, f"{name}.md")

# ── Write changed files, delete files with no entry ───────────────────────
written = unchanged = removed = 0

if wanted:
    os.makedirs(rules_dir, exist_ok=True)
for filename, content in wanted.items():
    path = os.path.join(rules_dir, filename)
    try:
        with open(path) as f:
            if f.read() == content:
                unchanged += 1
                continue
    except OSError:
        pass
    with open(path, "w") as f:
        f.write(content)
    written += 1

for path in glob.glob(os.path.join(rules_dir, "*.md")):
    if os.path.basename(path) not in wanted:
        os.remove(path)
        removed += 1

# ── Remove the managed section that sage-code 0.2.0 wrote into CLAUDE.md ──
MANAGED = re.compile(
    r"^## Sage Learnings[ \t]*\n\s*<!-- Auto-managed by sage-code plugin\.[^\n]*-->"
    r".*?<!-- End sage-code managed section -->[ \t]*\n?",
    re.S | re.M,
)
for candidate in ("CLAUDE.md", os.path.join(".claude", "CLAUDE.md")):
    path = os.path.join(project, candidate)
    try:
        with open(path) as f:
            text = f.read()
    except OSError:
        continue
    cleaned = MANAGED.sub("", text)
    if cleaned != text:
        cleaned = re.sub(r"\n{3,}", "\n\n", cleaned).strip("\n")
        with open(path, "w") as f:
            f.write(cleaned + "\n" if cleaned else "")
        print(f"sage-publish-rules: removed the managed section from {candidate}")

print(
    f"sage-publish-rules: {len(wanted)} published "
    f"({written} written, {unchanged} unchanged), {removed} removed"
)
PYEOF
````

Then make it executable:

```bash
chmod +x sage-code/bin/sage-publish-rules
```

- [ ] **Step 5: Update the config template**

Replace the full content of `sage-code/templates/config-default.json` with:

````json
{
  "version": "1.0.0",
  "min_session_tools_for_reflection": 5,
  "max_knowledge_entries_per_file": 100,
  "publish_min_confidence": "low",
  "meta_eval_interval_days": 1,
  "meta_eval_interval_sessions": 10,
  "prune_min_observations": 10,
  "prune_score_threshold": 0.2,
  "stale_days": 30,
  "new_rule_grace_days": 7,
  "reflector_model": "sonnet",
  "meta_evaluator_model": "sonnet",
  "sessions_since_eval": 0,
  "last_meta_eval": null
}
````

(`publish_min_confidence` is new. `replay_max_heuristics`, `replay_max_tokens`, and `promote_score_threshold` go away: nothing reads them after this plan.)

- [ ] **Step 6: Run the tests to verify that they pass**

Run: `bats sage-code/tests/test-sage-publish-rules.bats`
Expected: `1..15`, all `ok`.

Run: `bash sage-code/tests/run-all.sh`
Expected: `1..101`, all `ok`.

- [ ] **Step 7: Commit**

```bash
git add sage-code/bin/sage-publish-rules sage-code/tests/test-sage-publish-rules.bats sage-code/tests/test_helper.bash sage-code/templates/config-default.json
git commit -m "feat: add sage-publish-rules to publish heuristics as rule files" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: `InstructionsLoaded` hook

**Files:**
- Create: `sage-code/hooks/scripts/on-instructions-loaded.sh`
- Create: `sage-code/tests/test-on-instructions-loaded.bats`
- Modify: `sage-code/tests/test_helper.bash` (add `instructions_loaded_payload`)
- Modify: `sage-code/hooks/hooks.json`

**Interfaces:**
- Consumes: hook stdin JSON with `session_id`, `file_path`, `load_reason` (`session_start`, `path_glob_match`, `nested_traversal`, `include`, `compact`), and optionally `trigger_file_path`. Rule files from Task 1 at `.claude/rules/sage/<rule-id>.md`.
- Produces: one line appended to `.sage/events/session-<session_id>.jsonl`: `{"ts", "type": "rule_loaded", "rule_id", "load_reason", "trigger_file"}`. `trigger_file` is relative to the project, or `""`. The hook **creates** the log if it does not exist. Test helper `instructions_loaded_payload <file_path> [load_reason] [trigger_file_path]`.

- [ ] **Step 1: Add the payload builder**

Append this block to the end of `sage-code/tests/test_helper.bash`:

````bash
# instructions_loaded_payload <file_path> [load_reason] [trigger_file_path]
instructions_loaded_payload() {
  _payload InstructionsLoaded "$(python3 -c '
import json, sys
data = {"file_path": sys.argv[1], "memory_type": "Project", "load_reason": sys.argv[2]}
if sys.argv[3]:
    data["trigger_file_path"] = sys.argv[3]
print(json.dumps(data))' "$1" "${2:-session_start}" "${3:-}")"
}
````

- [ ] **Step 2: Write the failing tests**

Create `sage-code/tests/test-on-instructions-loaded.bats`:

````bash
#!/usr/bin/env bats

load test_helper

HOOK=""
SESSION_ID="rules-test-session"
EVENT_LOG=""
RULE_FILE=""

setup() {
  setup_sage_env
  HOOK="$SCRIPT_DIR/hooks/scripts/on-instructions-loaded.sh"
  init_sage
  EVENT_LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
  mkdir -p "$TEST_DIR/.claude/rules/sage/nested" "$TEST_DIR/src/auth"
  RULE_FILE="$TEST_DIR/.claude/rules/sage/pitfall-never-use-md5.md"
  echo "# NEVER use md5" > "$RULE_FILE"
  touch "$TEST_DIR/src/auth/login.ts"
}

teardown() {
  teardown_sage_env
}

# Helper: get a field of the last event in the log
_last_event_field() {
  python3 -c "import json; d=json.loads(open('$EVENT_LOG').readlines()[-1]); print(d.get('$1',''))"
}

@test "sage rule load is recorded as rule_loaded with the rule ID" {
  instructions_loaded_payload "$RULE_FILE" session_start | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ "$(_last_event_field type)" = "rule_loaded" ]
  [ "$(_last_event_field rule_id)" = "pitfall-never-use-md5" ]
  [ "$(_last_event_field load_reason)" = "session_start" ]
  [ "$(_last_event_field trigger_file)" = "" ]
}

@test "path match load records the trigger file relative to the project" {
  instructions_loaded_payload "$RULE_FILE" path_glob_match "$TEST_DIR/src/auth/login.ts" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ "$(_last_event_field load_reason)" = "path_glob_match" ]
  [ "$(_last_event_field trigger_file)" = "src/auth/login.ts" ]
}

@test "event log is created when it does not exist" {
  [ ! -f "$EVENT_LOG" ]
  instructions_loaded_payload "$RULE_FILE" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ -f "$EVENT_LOG" ]
  [ "$(wc -l < "$EVENT_LOG" | tr -d ' ')" -eq 1 ]
}

@test "CLAUDE.md load is ignored" {
  echo "# Project" > "$TEST_DIR/CLAUDE.md"
  instructions_loaded_payload "$TEST_DIR/CLAUDE.md" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ ! -f "$EVENT_LOG" ]
}

@test "rule file outside sage/ is ignored" {
  echo "# team" > "$TEST_DIR/.claude/rules/team.md"
  instructions_loaded_payload "$TEST_DIR/.claude/rules/team.md" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ ! -f "$EVENT_LOG" ]
}

@test "file in a subdirectory of sage/ is ignored" {
  echo "# nested" > "$TEST_DIR/.claude/rules/sage/nested/x.md"
  instructions_loaded_payload "$TEST_DIR/.claude/rules/sage/nested/x.md" | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ ! -f "$EVENT_LOG" ]
}

@test "load after compaction is ignored" {
  instructions_loaded_payload "$RULE_FILE" compact | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
  [ ! -f "$EVENT_LOG" ]
}

@test "hook exits silently when .sage/ directory is missing" {
  EMPTY_DIR=$(mktemp -d)
  PAYLOAD=$(instructions_loaded_payload "$EMPTY_DIR/.claude/rules/sage/a.md")
  run bash -c "echo '$PAYLOAD' | SAGE_PROJECT_DIR='$EMPTY_DIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -d "$EMPTY_DIR/.sage" ]
  rm -rf "$EMPTY_DIR"
}

@test "hooks.json registers the InstructionsLoaded hook without the compact reason" {
  run python3 -c "
import json
entry = json.load(open('$SCRIPT_DIR/hooks/hooks.json'))['hooks']['InstructionsLoaded'][0]
assert 'compact' not in entry['matcher'].split('|')
assert 'path_glob_match' in entry['matcher'].split('|')
assert entry['hooks'][0]['args'][0].endswith('/hooks/scripts/on-instructions-loaded.sh')
"
  [ "$status" -eq 0 ]
}
````

- [ ] **Step 3: Run the tests to verify that they fail**

Run: `bats sage-code/tests/test-on-instructions-loaded.bats`
Expected: FAIL. The first tests fail because `on-instructions-loaded.sh` does not exist; the last test fails with `KeyError: 'InstructionsLoaded'`.

- [ ] **Step 4: Write the hook script**

Create `sage-code/hooks/scripts/on-instructions-loaded.sh`:

````bash
#!/usr/bin/env bash
set -euo pipefail

# InstructionsLoaded hook.
# Claude Code sends the event as JSON on stdin each time it loads a CLAUDE.md
# or .claude/rules/*.md file. This hook records the loads of the rule files
# that sage-publish-rules wrote, so that the meta-evaluator knows which rules
# were in context in which session.

# ── Environment ────────────────────────────────────────────────────────────
SAGE_PROJECT_DIR="${SAGE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
SAGE_DIR="$SAGE_PROJECT_DIR/.sage"

# ── Exit silently if .sage/events/ doesn't exist ──────────────────────────
[ -d "$SAGE_DIR/events" ] || exit 0

# ── Read stdin and pass via env to avoid heredoc quoting issues ────────────
export _HOOK_INPUT
_HOOK_INPUT=$(cat)
export _HOOK_SAGE_DIR="$SAGE_DIR"
export _HOOK_PROJECT_DIR="$SAGE_PROJECT_DIR"

python3 << 'PYEOF'
import json, re, sys, os
from datetime import datetime, timezone

raw      = os.environ.get("_HOOK_INPUT", "")
sage_dir = os.environ.get("_HOOK_SAGE_DIR", "")
project  = os.path.realpath(os.environ.get("_HOOK_PROJECT_DIR", ""))

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

# Only the *.md files directly in .claude/rules/sage/ are sage rules
file_path = os.path.realpath(str(data.get("file_path") or ""))
rules_dir = os.path.join(project, ".claude", "rules", "sage")
if os.path.dirname(file_path) != rules_dir or not file_path.endswith(".md"):
    sys.exit(0)

# After compaction Claude Code loads the files again; do not count a rule two times
load_reason = data.get("load_reason", "")
if load_reason == "compact":
    sys.exit(0)

# Session ID comes from the hook input; keep it safe for use in a file name
session_id = re.sub(r"[^A-Za-z0-9._-]", "_", str(data.get("session_id") or "unknown"))
event_log  = os.path.join(sage_dir, "events", f"session-{session_id}.jsonl")

# The trigger file is relative to the project when it is in the project
trigger = str(data.get("trigger_file_path") or "")
if trigger:
    real = os.path.realpath(trigger)
    if real.startswith(project + os.sep):
        trigger = os.path.relpath(real, project)

event = {
    "ts":           datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "type":         "rule_loaded",
    "rule_id":      os.path.basename(file_path)[:-len(".md")],
    "load_reason":  load_reason,
    "trigger_file": trigger,
}

# Rules with no path scope load while the SessionStart hook still runs, so
# the log may not exist yet. Opening for append creates it.
with open(event_log, "a") as f:
    f.write(json.dumps(event) + "\n")
PYEOF
````

Then make it executable:

```bash
chmod +x sage-code/hooks/scripts/on-instructions-loaded.sh
```

- [ ] **Step 5: Register the hook**

Apply this change to `sage-code/hooks/hooks.json` (a new `InstructionsLoaded` entry after `SessionStart`). The matcher runs against `load_reason`; it leaves out `compact`. Claude Code runs this event asynchronously, so the entry has no `async` field.

````diff
--- a/sage-code/hooks/hooks.json
+++ b/sage-code/hooks/hooks.json
@@ -13,6 +13,18 @@
         ]
       }
     ],
+    "InstructionsLoaded": [
+      {
+        "matcher": "session_start|path_glob_match|nested_traversal|include",
+        "hooks": [
+          {
+            "type": "command",
+            "command": "bash",
+            "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/on-instructions-loaded.sh"]
+          }
+        ]
+      }
+    ],
     "PostToolUse": [
       {
         "hooks": [
````

- [ ] **Step 6: Run the tests to verify that they pass**

Run: `bats sage-code/tests/test-on-instructions-loaded.bats`
Expected: `1..9`, all `ok`.

Run: `claude plugin validate ./sage-code --strict`
Expected: `✔ Validation passed`

- [ ] **Step 7: Commit**

```bash
git add sage-code/hooks/scripts/on-instructions-loaded.sh sage-code/hooks/hooks.json sage-code/tests/test-on-instructions-loaded.bats sage-code/tests/test_helper.bash
git commit -m "feat: record rule loads with an InstructionsLoaded hook" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: SessionStart and SessionEnd changes

Rules with no path scope load while the SessionStart hook still runs. In a real session the `rule_loaded` event was in the log **before** the `session_start` event. The SessionStart hook must therefore not use "the log is empty" to find a new session.

**Files:**
- Modify: `sage-code/hooks/scripts/on-session-start.sh`
- Modify: `sage-code/hooks/scripts/on-session-end.sh`
- Modify: `sage-code/tests/test-on-session-start.bats`
- Modify: `sage-code/tests/test-on-session-end.bats`

**Interfaces:**
- Consumes: `rule_loaded` events from Task 2; config keys `sessions_since_eval` and `meta_eval_interval_sessions`.
- Produces: `session_start` is written once per session even when the log already has other events. `additionalContext` appears only when a reflection is pending (the marker of the current session does not count) or when `sessions_since_eval >= meta_eval_interval_sessions`. The `session_end` summary has the integer `rules_loaded`.

- [ ] **Step 1: Change the tests**

Apply this change to `sage-code/tests/test-on-session-start.bats`. It replaces the test "returns additionalContext when heuristics exist" (published rules need no notice now) with 4 new tests:

````diff
--- a/sage-code/tests/test-on-session-start.bats
+++ b/sage-code/tests/test-on-session-start.bats
@@ -64,15 +64,53 @@ print(out['additionalContext'])
   [[ "$CONTEXT" == *"sage-code:sage-replay"* ]]
 }
 
-@test "on-session-start returns additionalContext when heuristics exist" {
+@test "on-session-start is silent when heuristics exist but Claude has no task" {
   init_sage
-  printf '\n### ALWAYS use const\n- **Confidence:** low (1 observation)\n' >> "$TEST_DIR/.sage/knowledge/conventions.md"
+  printf '\n### ALWAYS use const\n- **Confidence:** low (1 observation)\n- **Rule:** Use const.\n' >> "$TEST_DIR/.sage/knowledge/conventions.md"
+  SESSION_ID="test-session-002"
+  OUTPUT=$(session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK")
+  [ -z "$OUTPUT" ]
+}
+
+@test "on-session-start does not count the marker of its own session as pending" {
+  init_sage
+  SESSION_ID="test-session-002"
+  touch "$TEST_DIR/.sage/events/session-${SESSION_ID}.unprocessed"
+  OUTPUT=$(session_start_payload resume | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK")
+  [ -z "$OUTPUT" ]
+}
+
+@test "on-session-start returns additionalContext when meta-evaluation is due" {
+  init_sage
+  python3 - "$TEST_DIR/.sage/meta/config.json" <<'PY2'
+import json, sys
+cfg = json.load(open(sys.argv[1]))
+cfg["sessions_since_eval"] = 9
+cfg["meta_eval_interval_sessions"] = 10
+json.dump(cfg, open(sys.argv[1], "w"), indent=2)
+PY2
   SESSION_ID="test-session-002"
   CONTEXT=$(session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" | python3 -c "
 import sys, json
 print(json.load(sys.stdin)['hookSpecificOutput']['additionalContext'])
 ")
-  [[ "$CONTEXT" == *"1 learned heuristic(s)"* ]]
+  [[ "$CONTEXT" == *"Meta-evaluation is due: 10 sessions"* ]]
+  [[ "$CONTEXT" == *"sage-code:sage-meta"* ]]
+}
+
+@test "on-session-start writes session_start when a rule_loaded event came first" {
+  init_sage
+  SESSION_ID="test-session-005"
+  LOG="$TEST_DIR/.sage/events/session-${SESSION_ID}.jsonl"
+  echo '{"ts":"2026-09-17T10:00:00Z","type":"rule_loaded","rule_id":"pitfall-x","load_reason":"session_start","trigger_file":""}' > "$LOG"
+  session_start_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > /dev/null
+  TYPES=$(python3 -c "
+import json
+print(' '.join(sorted(json.loads(l)['type'] for l in open('$LOG'))))
+")
+  [ "$TYPES" = "rule_loaded session_start" ]
+  COUNT=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.sage/meta/config.json'))['sessions_since_eval'])")
+  [ "$COUNT" -eq 1 ]
 }
 
 @test "on-session-start on resume does not repeat session_start or the session count" {
````

Apply this change to `sage-code/tests/test-on-session-end.bats`:

````diff
--- a/sage-code/tests/test-on-session-end.bats
+++ b/sage-code/tests/test-on-session-end.bats
@@ -140,6 +140,23 @@ else:
   [ "$output" = "ok" ]
 }
 
+@test "on-session-end summary counts the different rules that loaded" {
+  python3 - "$EVENT_LOG" <<'PY2'
+import json, sys
+with open(sys.argv[1], "a") as f:
+    for rule_id in ("pitfall-a", "pitfall-a", "convention-b"):
+        f.write(json.dumps({"ts": "2026-04-15T10:00:30Z", "type": "rule_loaded", "rule_id": rule_id, "load_reason": "session_start", "trigger_file": ""}) + "\n")
+PY2
+  session_end_payload | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
+  run python3 -c "
+import json
+d = json.loads(open('$EVENT_LOG').readlines()[-1])
+print(d['summary']['rules_loaded'])
+"
+  [ "$status" -eq 0 ]
+  [ "$output" = "2" ]
+}
+
 @test "on-session-end records the reason the session ended" {
   session_end_payload clear | SAGE_PROJECT_DIR="$TEST_DIR" bash "$HOOK"
   run python3 -c "
````

- [ ] **Step 2: Run the tests to verify that they fail**

Run: `bats sage-code/tests/test-on-session-start.bats sage-code/tests/test-on-session-end.bats`
Expected: 4 failures — "is silent when heuristics exist but Claude has no task", "returns additionalContext when meta-evaluation is due", "writes session_start when a rule_loaded event came first", and "summary counts the different rules that loaded" (`KeyError: 'rules_loaded'`). ("does not count the marker of its own session" can pass or fail at this point.)

- [ ] **Step 3: Change `on-session-start.sh`**

````diff
--- a/sage-code/hooks/scripts/on-session-start.sh
+++ b/sage-code/hooks/scripts/on-session-start.sh
@@ -70,9 +70,28 @@ except json.JSONDecodeError:
 def lines(value):
     return [l.strip() for l in value.splitlines() if l.strip()]
 
+def has_session_start(path):
+    try:
+        with open(path) as f:
+            for line in f:
+                try:
+                    if json.loads(line).get("type") == "session_start":
+                        return True
+                except json.JSONDecodeError:
+                    pass
+    except OSError:
+        pass
+    return False
+
 # SessionStart also fires on resume and compaction with the same session ID.
 # Only the first firing for a session writes session_start and counts it.
-is_new_session = not os.path.isfile(event_log) or os.path.getsize(event_log) == 0
+# The log can exist before this hook runs: the InstructionsLoaded hook creates
+# it when a rule loads at the start of the session.
+is_new_session = not has_session_start(event_log)
+
+config = os.path.join(sage_dir, "meta", "config.json")
+with open(config) as f:
+    cfg = json.load(f)
 
 if is_new_session:
     event = {
@@ -89,34 +108,39 @@ if is_new_session:
         f.write(json.dumps(event) + "\n")
 
     # ── Increment sessions_since_eval in config.json ──────────────────────
-    config = os.path.join(sage_dir, "meta", "config.json")
-    with open(config) as f:
-        cfg = json.load(f)
     cfg["sessions_since_eval"] = cfg.get("sessions_since_eval", 0) + 1
     with open(config, "w") as f:
         json.dump(cfg, f, indent=2)
 
-# ── Tell Claude what there is to replay ───────────────────────────────────
-pending = len(glob.glob(os.path.join(sage_dir, "events", "*.unprocessed")))
+# ── Tell Claude when there is a task for it ───────────────────────────────
+# Published rules need no notice: Claude Code loads .claude/rules/sage/ itself.
+own_marker = f"session-{session_id}.unprocessed"
+pending = sum(
+    1
+    for path in glob.glob(os.path.join(sage_dir, "events", "*.unprocessed"))
+    if os.path.basename(path) != own_marker
+)
 
-heuristics = 0
-for path in glob.glob(os.path.join(sage_dir, "knowledge", "*.md")):
-    with open(path) as f:
-        heuristics += sum(1 for line in f if line.startswith("### "))
+since_eval = cfg.get("sessions_since_eval", 0)
+interval   = cfg.get("meta_eval_interval_sessions", 10)
+meta_due   = since_eval >= interval
 
-# Nothing learned and nothing pending: stay silent and add no context
-if pending == 0 and heuristics == 0:
+if pending == 0 and not meta_due:
     raise SystemExit(0)
 
 # additionalContext is written as statements of fact, not as commands
-context = (
-    "[sage-code] This project has a SAGE-Code knowledge base in .sage/. "
-    f"It holds {heuristics} learned heuristic(s) in .sage/knowledge/, and "
-    f"{pending} earlier session log(s) in .sage/events/ are not reflected on yet. "
-    f"The event log for this session is .sage/events/session-{session_id}.jsonl. "
-    "The sage-code:sage-replay skill processes the pending reflections and "
-    "loads the heuristics that are relevant to the current git context."
-)
+facts = ["[sage-code] This project has a SAGE-Code knowledge base in .sage/."]
+if pending:
+    facts.append(
+        f"{pending} earlier session log(s) in .sage/events/ are not reflected on yet. "
+        "The sage-code:sage-replay skill processes the pending reflections."
+    )
+if meta_due:
+    facts.append(
+        f"Meta-evaluation is due: {since_eval} sessions since the last one "
+        f"(the interval is {interval}). The sage-code:sage-meta skill runs it."
+    )
+context = " ".join(facts)
 
 print(json.dumps({
     "hookSpecificOutput": {
````

- [ ] **Step 4: Change `on-session-end.sh`**

````diff
--- a/sage-code/hooks/scripts/on-session-end.sh
+++ b/sage-code/hooks/scripts/on-session-end.sh
@@ -61,6 +61,13 @@ files_modified = len({
     if e.get("type") == "tool_outcome" and e.get("file_path", "")
 })
 
+# Count the different sage rules that Claude Code loaded in this session
+rules_loaded = len({
+    e["rule_id"]
+    for e in events
+    if e.get("type") == "rule_loaded" and e.get("rule_id", "")
+})
+
 # Duration: difference between first and last event timestamp
 def parse_ts(ts_str):
     try:
@@ -88,6 +95,7 @@ session_end_event = {
         "corrections":      corrections,
         "positive_signals": positive_signals,
         "files_modified":   files_modified,
+        "rules_loaded":     rules_loaded,
         "duration_s":       duration_s,
     },
 }
````

- [ ] **Step 5: Run the tests to verify that they pass**

Run: `bash sage-code/tests/run-all.sh`
Expected: `1..114`, all `ok`.

- [ ] **Step 6: Commit**

```bash
git add sage-code/hooks/scripts/on-session-start.sh sage-code/hooks/scripts/on-session-end.sh sage-code/tests/test-on-session-start.bats sage-code/tests/test-on-session-end.bats
git commit -m "feat: find a new session by its session_start event and count loaded rules" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: `sage-exposure` script

**Files:**
- Create: `sage-code/bin/sage-exposure`
- Create: `sage-code/tests/test-sage-exposure.bats`
- Modify: `sage-code/templates/gitignore-template`

**Interfaces:**
- Consumes: `.sage/events/session-*.jsonl` with `session_start`, `rule_loaded` (Task 2), `correction` (`excerpt`), and `tool_outcome` (`success`, `command`, `tool`) events.
- Produces: command `sage-exposure [project-dir]`; file `.sage/meta/exposure.json`:
  `{"generated": str, "sessions_total": int, "rules": {<rule_id>: {"sessions_loaded": int, "sessions_not_loaded": int, "first_loaded": str, "last_loaded": str, "always_loaded": bool, "corrections_per_session_loaded": float|null, "corrections_per_session_not_loaded": float|null, "errors_per_session_loaded": float|null, "errors_per_session_not_loaded": float|null, "recent_loaded_sessions": [{"session_id", "trigger_files": [str], "corrections": [str], "failed_commands": [str]}]}}}`.
  A rule that never loaded is not in `rules`. stdout: `sage-exposure: N sessions, M rules -> .sage/meta/exposure.json`.

- [ ] **Step 1: Write the failing tests**

Create `sage-code/tests/test-sage-exposure.bats`:

````bash
#!/usr/bin/env bats

load test_helper

EXPOSURE=""
RULE="pitfall-never-use-md5"

setup() {
  setup_sage_env
  EXPOSURE="$SCRIPT_DIR/bin/sage-exposure"
  init_sage
}

teardown() {
  teardown_sage_env
}

# write_session <session id> <day of month> <event>...
# Each event is one of: start | load:<rule_id>:<load_reason> | correction:<text> | fail:<command>
write_session() {
  python3 - "$TEST_DIR/.sage/events/session-$1.jsonl" "$2" "${@:3}" <<'PY'
import json, sys
path, day, specs = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
with open(path, "w") as f:
    for minute, spec in enumerate(specs):
        kind, _, rest = spec.partition(":")
        event = {"ts": f"2026-09-{day:02d}T09:{minute:02d}:00Z"}
        if kind == "start":
            event.update(type="session_start", session_id="x")
        elif kind == "load":
            rule_id, _, reason = rest.partition(":")
            event.update(type="rule_loaded", rule_id=rule_id, load_reason=reason,
                         trigger_file="src/auth/login.ts" if reason == "path_glob_match" else "")
        elif kind == "correction":
            event.update(type="correction", signal="negative", excerpt=rest)
        elif kind == "fail":
            event.update(type="tool_outcome", tool="Bash", file_path="", command=rest, success=False)
        f.write(json.dumps(event) + "\n")
PY
}

# rule_field <python expression over r, the entry of $RULE, and d, the whole file>
rule_field() {
  python3 -c "
import json
d = json.load(open('$TEST_DIR/.sage/meta/exposure.json'))
r = d['rules'].get('$RULE')
print($1)
"
}

@test "counts loaded and not-loaded sessions" {
  write_session s1 1 start "load:$RULE:path_glob_match"
  write_session s2 2 start
  write_session s3 3 start "load:$RULE:path_glob_match"
  run "$EXPOSURE" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(rule_field "d['sessions_total']")" = "3" ]
  [ "$(rule_field "r['sessions_loaded']")" = "2" ]
  [ "$(rule_field "r['sessions_not_loaded']")" = "1" ]
  [ "$(rule_field "r['first_loaded']")" = "2026-09-01T09:01:00Z" ]
  [ "$(rule_field "r['last_loaded']")" = "2026-09-03T09:01:00Z" ]
}

@test "sessions before the first load are not a control group" {
  write_session s1 1 start "correction:no, before the rule"
  write_session s2 2 start "load:$RULE:path_glob_match"
  "$EXPOSURE" "$TEST_DIR"
  [ "$(rule_field "r['sessions_not_loaded']")" = "0" ]
  [ "$(rule_field "r['corrections_per_session_not_loaded']")" = "None" ]
}

@test "computes corrections and errors per session in the two groups" {
  write_session s1 1 start "load:$RULE:path_glob_match" "fail:npm test"
  write_session s2 2 start "correction:no, a" "correction:no, b"
  write_session s3 3 start "load:$RULE:path_glob_match" "correction:no, c"
  "$EXPOSURE" "$TEST_DIR"
  [ "$(rule_field "r['corrections_per_session_loaded']")" = "0.5" ]
  [ "$(rule_field "r['corrections_per_session_not_loaded']")" = "2.0" ]
  [ "$(rule_field "r['errors_per_session_loaded']")" = "0.5" ]
  [ "$(rule_field "r['errors_per_session_not_loaded']")" = "0.0" ]
}

@test "always_loaded is true only when each load was at session start" {
  write_session s1 1 start "load:$RULE:session_start" "load:convention-x:session_start"
  write_session s2 2 start "load:$RULE:path_glob_match" "load:convention-x:session_start"
  "$EXPOSURE" "$TEST_DIR"
  [ "$(rule_field "r['always_loaded']")" = "False" ]
  [ "$(rule_field "d['rules']['convention-x']['always_loaded']")" = "True" ]
}

@test "recent_loaded_sessions has the evidence, most recent first" {
  write_session s1 1 start "load:$RULE:path_glob_match" "correction:no, old"
  write_session s2 2 start "load:$RULE:path_glob_match" "correction:no, new" "fail:npm test"
  "$EXPOSURE" "$TEST_DIR"
  [ "$(rule_field "r['recent_loaded_sessions'][0]['session_id']")" = "s2" ]
  [ "$(rule_field "r['recent_loaded_sessions'][0]['corrections']")" = "['no, new']" ]
  [ "$(rule_field "r['recent_loaded_sessions'][0]['failed_commands']")" = "['npm test']" ]
  [ "$(rule_field "r['recent_loaded_sessions'][0]['trigger_files']")" = "['src/auth/login.ts']" ]
  [ "$(rule_field "r['recent_loaded_sessions'][1]['session_id']")" = "s1" ]
}

@test "recent_loaded_sessions is capped at 10 sessions and 5 excerpts" {
  for day in 01 02 03 04 05 06 07 08 09 10 11 12; do
    write_session "s$day" "$day" start "load:$RULE:path_glob_match" \
      "correction:no, 1" "correction:no, 2" "correction:no, 3" "correction:no, 4" "correction:no, 5" "correction:no, 6"
  done
  "$EXPOSURE" "$TEST_DIR"
  [ "$(rule_field "r['sessions_loaded']")" = "12" ]
  [ "$(rule_field "len(r['recent_loaded_sessions'])")" = "10" ]
  [ "$(rule_field "r['recent_loaded_sessions'][0]['session_id']")" = "s12" ]
  [ "$(rule_field "len(r['recent_loaded_sessions'][0]['corrections'])")" = "5" ]
}

@test "log with no session_start event is not counted" {
  write_session s1 1 start "load:$RULE:path_glob_match"
  write_session s2 2 "load:$RULE:session_start"
  "$EXPOSURE" "$TEST_DIR"
  [ "$(rule_field "d['sessions_total']")" = "1" ]
  [ "$(rule_field "r['sessions_loaded']")" = "1" ]
}

@test "bad JSON line is skipped" {
  write_session s1 1 start "load:$RULE:path_glob_match"
  echo "not json" >> "$TEST_DIR/.sage/events/session-s1.jsonl"
  run "$EXPOSURE" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(rule_field "r['sessions_loaded']")" = "1" ]
}

@test "no events gives an empty rules object" {
  run "$EXPOSURE" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 sessions, 0 rules"* ]]
  [ "$(rule_field "d['rules']")" = "{}" ]
}

@test "exits silently when .sage/ directory is missing" {
  EMPTY_DIR=$(mktemp -d)
  run "$EXPOSURE" "$EMPTY_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -rf "$EMPTY_DIR"
}

@test "sage-init ignores the derived exposure file in git" {
  grep -q '^meta/exposure.json$' "$TEST_DIR/.sage/.gitignore"
}
````

- [ ] **Step 2: Run the tests to verify that they fail**

Run: `bats sage-code/tests/test-sage-exposure.bats`
Expected: all 11 tests FAIL (the script does not exist; the last test fails because `.sage/.gitignore` has no `meta/exposure.json` line).

- [ ] **Step 3: Write the script**

Create `sage-code/bin/sage-exposure`:

````bash
#!/usr/bin/env bash
set -euo pipefail

# Aggregates rule_loaded events from .sage/events/session-*.jsonl into
# .sage/meta/exposure.json, for the meta-evaluator and the knowledge-curator.
#
# Usage: sage-exposure [project-dir]

PROJECT_DIR="${1:-${SAGE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}}"

# ── Exit silently if .sage/ doesn't exist ─────────────────────────────────
[ -d "$PROJECT_DIR/.sage" ] || exit 0

export _SAGE_PROJECT_DIR="$PROJECT_DIR"

python3 << 'PYEOF'
import glob, json, os
from datetime import datetime, timezone

MAX_RECENT_SESSIONS = 10
MAX_EXCERPTS        = 5

sage_dir = os.path.join(os.environ["_SAGE_PROJECT_DIR"], ".sage")

# ── Read each session log ─────────────────────────────────────────────────
sessions = []
for path in glob.glob(os.path.join(sage_dir, "events", "session-*.jsonl")):
    session = {
        "session_id":  os.path.basename(path)[len("session-"):-len(".jsonl")],
        "start":       None,
        "loads":       {},   # rule_id -> list of rule_loaded events
        "corrections": [],
        "failed":      [],
    }
    with open(path) as f:
        for line in f:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            kind = event.get("type")
            if kind == "session_start":
                session["start"] = event.get("ts", "")
            elif kind == "rule_loaded" and event.get("rule_id"):
                session["loads"].setdefault(event["rule_id"], []).append(event)
            elif kind == "correction":
                session["corrections"].append(event.get("excerpt", ""))
            elif kind == "tool_outcome" and not event.get("success", True):
                session["failed"].append(event.get("command") or event.get("tool", ""))
    # A log with no session_start event is not a complete session
    if session["start"] is not None:
        sessions.append(session)

sessions.sort(key=lambda s: (s["start"], s["session_id"]))

def per_session(group, key):
    if not group:
        return None
    return round(sum(len(s[key]) for s in group) / len(group), 2)

# ── Aggregate for each rule ───────────────────────────────────────────────
rules = {}
for rule_id in sorted({rule_id for s in sessions for rule_id in s["loads"]}):
    first = next(i for i, s in enumerate(sessions) if rule_id in s["loads"])
    # Sessions before the first load are not a control group: the rule did not exist
    loaded     = [s for s in sessions[first:] if rule_id in s["loads"]]
    not_loaded = [s for s in sessions[first:] if rule_id not in s["loads"]]
    events     = [e for s in loaded for e in s["loads"][rule_id]]
    stamps     = sorted(e.get("ts", "") for e in events)

    rules[rule_id] = {
        "sessions_loaded":     len(loaded),
        "sessions_not_loaded": len(not_loaded),
        "first_loaded":        stamps[0],
        "last_loaded":         stamps[-1],
        "always_loaded":       all(e.get("load_reason") == "session_start" for e in events),
        "corrections_per_session_loaded":     per_session(loaded, "corrections"),
        "corrections_per_session_not_loaded": per_session(not_loaded, "corrections"),
        "errors_per_session_loaded":          per_session(loaded, "failed"),
        "errors_per_session_not_loaded":      per_session(not_loaded, "failed"),
        "recent_loaded_sessions": [
            {
                "session_id":      s["session_id"],
                "trigger_files":   sorted({e["trigger_file"] for e in s["loads"][rule_id] if e.get("trigger_file")}),
                "corrections":     s["corrections"][:MAX_EXCERPTS],
                "failed_commands": s["failed"][:MAX_EXCERPTS],
            }
            for s in reversed(loaded[-MAX_RECENT_SESSIONS:])
        ],
    }

exposure = {
    "generated":      datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "sessions_total": len(sessions),
    "rules":          rules,
}

os.makedirs(os.path.join(sage_dir, "meta"), exist_ok=True)
with open(os.path.join(sage_dir, "meta", "exposure.json"), "w") as f:
    json.dump(exposure, f, indent=2)
    f.write("\n")

print(f"sage-exposure: {len(sessions)} sessions, {len(rules)} rules -> .sage/meta/exposure.json")
PYEOF
````

Then make it executable:

```bash
chmod +x sage-code/bin/sage-exposure
```

- [ ] **Step 4: Ignore the derived file in git**

Replace the full content of `sage-code/templates/gitignore-template` with:

````
# Session event logs are personal and ephemeral
events/

# Derived from the event logs by sage-exposure
meta/exposure.json
````

- [ ] **Step 5: Run the tests to verify that they pass**

Run: `bash sage-code/tests/run-all.sh`
Expected: `1..125`, all `ok`.

- [ ] **Step 6: Commit**

```bash
git add sage-code/bin/sage-exposure sage-code/tests/test-sage-exposure.bats sage-code/templates/gitignore-template
git commit -m "feat: add sage-exposure to aggregate rule loads for each rule" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Agent and skill prompts

These files are prompts, so they have no unit tests. The checks are `claude plugin validate` and the real run in Task 6.

**Files:**
- Modify: `sage-code/agents/reflector.md`, `sage-code/agents/knowledge-curator.md`, `sage-code/agents/meta-evaluator.md`
- Modify: `sage-code/skills/sage-replay/SKILL.md`, `sage-code/skills/sage-reflect/SKILL.md`, `sage-code/skills/sage-meta/SKILL.md`, `sage-code/skills/sage-status/SKILL.md`

**Interfaces:**
- Consumes: commands `sage-publish-rules "${CLAUDE_PROJECT_DIR}"` (Task 1) and `sage-exposure "${CLAUDE_PROJECT_DIR}"` (Task 4). Claude Code substitutes the `${CLAUDE_PROJECT_DIR}` placeholder in skill content. `exposure.json` fields from Task 4.
- Produces: knowledge entries with the optional `- **Paths:**` field, which Task 1 reads.

- [ ] **Step 1: Reflector — write the `Paths` field**

````diff
--- a/sage-code/agents/reflector.md
+++ b/sage-code/agents/reflector.md
@@ -49,14 +49,24 @@ Each heuristic MUST have:
 - **Category:** One of: pitfall, strategy, preference, architecture, convention
 - **Confidence:** low (this is first observation)
 - **Scope:** project (if references project specifics) or language/universal
+- **Paths:** (optional) the files where the heuristic applies — see "Choosing Paths"
 - **Evidence:** The session ID being analyzed
 
+#### Choosing Paths
+
+SAGE-Code publishes each heuristic as a rule file. Claude Code loads a rule that has Paths only when Claude reads a file that matches. A rule with no Paths loads in each session and always costs context.
+
+- Look at the `file_path` values of the `tool_outcome` events near the correction or failure. They are absolute. Make them relative to the project root with the `cwd` value of the `session_start` event.
+- Prefer a directory pattern (`src/auth/**`) to a single file. Use an extension pattern (`**/*.test.ts`) when the heuristic is about a kind of file.
+- Use at most 5 patterns, separated by commas. Never use an absolute path or `..`.
+- Leave the Paths field out when the heuristic is not about specific files (a commit message convention, a communication preference).
+
 ### Step 4: MERGE
 Read existing knowledge files in `.sage/knowledge/`.
 
 For each new heuristic:
 1. Search ALL knowledge files for an existing entry that covers the same concept
-2. If **duplicate found**: Edit the existing entry to increment its confidence (low→medium if 2-3 observations, medium→high if 4+), add this session ID to Evidence, update "Last seen" date
+2. If **duplicate found**: Edit the existing entry to increment its confidence (low→medium if 2-3 observations, medium→high if 4+), add this session ID to Evidence, update "Last seen" date. Add new patterns to Paths; never remove a pattern
 3. If **contradictory rule found**: If the existing rule has higher confidence, keep it and add a note. If equal or lower confidence, demote the existing rule and add the new one.
 4. If **novel**: Append to the appropriate knowledge file
 
@@ -67,6 +77,7 @@ Use this exact format for each entry:
 ### HEADING_TEXT
 - **Confidence:** low (1 observation)
 - **Scope:** project
+- **Paths:** src/auth/**, src/middleware/*.ts
 - **Rule:** Detailed explanation of what to do or avoid and why.
 - **Evidence:** sessions SESSION_ID
 - **Added:** YYYY-MM-DD
@@ -79,3 +90,5 @@ Use this exact format for each entry:
 - Prefer fewer, higher-quality heuristics over many weak ones
 - One heuristic per distinct concept
 - Keep Rule text concise (1-3 sentences max)
+- The Rule text is published as it is, with no other field. It must make sense alone
+- Omit the Paths line when the heuristic has no path scope. Do not write an empty Paths field
````

- [ ] **Step 2: Curator — no `CLAUDE.md` edits; stale means no evidence AND no loads**

````diff
--- a/sage-code/agents/knowledge-curator.md
+++ b/sage-code/agents/knowledge-curator.md
@@ -1,6 +1,6 @@
 ---
 name: knowledge-curator
-description: Organizes, deduplicates, and maintains the SAGE-Code knowledge base. Enforces size limits, merges redundant entries, and updates the project README and CLAUDE.md.
+description: Organizes, deduplicates, and maintains the SAGE-Code knowledge base. Enforces size limits, merges redundant entries, prunes stale entries, and updates the .sage README.
 model: sonnet
 tools:
   - Read
@@ -22,6 +22,7 @@ Read all files in `.sage/knowledge/`. Find entries that express the same concept
 - Combine evidence lists
 - Use the highest confidence level
 - Keep the earliest "Added" date and latest "Last seen" date
+- Combine the Paths patterns of the merged entries
 
 ### 2. Consolidate
 Look for entries that are closely related and could be combined into a broader rule. Only consolidate when the combined rule is clearer than the separate ones.
@@ -34,20 +35,18 @@ If any knowledge file exceeds this limit:
 
 ### 4. Prune Stale Entries
 Read `.sage/meta/config.json` for `stale_days` (default: 30).
-Remove entries where "Last seen" is older than stale_days ago.
-Archive them with reason "stale".
+Read `.sage/meta/exposure.json` if it exists. The rule ID of an entry is `{category}-{slugified-heading}`; `rules[<rule ID>].last_loaded` is the last time Claude Code loaded the rule. A rule that is not in the file never loaded.
+
+An entry is stale only when the two conditions are true:
+1. "Last seen" is older than `stale_days` ago, AND
+2. `last_loaded` is older than `stale_days` ago, or the rule never loaded.
+
+A rule that still loads and causes no new corrections is a rule that works. Do not prune it.
+Archive stale entries to `.sage/meta/archive.md` with reason "stale".
 Respect `new_rule_grace_days` — never prune entries added within the grace period.
 
-### 5. Update CLAUDE.md
-Find or create the managed section:
-```
-## Sage Learnings
-<!-- Auto-managed by sage-code plugin. Do not edit below this line. -->
-...
-<!-- End sage-code managed section -->
-```
-Replace contents with all heuristics that have `confidence: high` as a bullet list.
-
-### 6. Update .sage/README.md
+Do not edit `CLAUDE.md` or `.claude/rules/`. The `sage-publish-rules` script makes the rule files from the knowledge files after you finish.
+
+### 5. Update .sage/README.md
 Count total heuristics across all knowledge files by confidence level.
 Update the stats in README.md.
````

- [ ] **Step 3: Meta-evaluator — score with exposure data; remove PROMOTE**

````diff
--- a/sage-code/agents/meta-evaluator.md
+++ b/sage-code/agents/meta-evaluator.md
@@ -1,6 +1,6 @@
 ---
 name: meta-evaluator
-description: Evaluates the effectiveness of SAGE-Code heuristics by correlating them with session outcomes. Promotes, demotes, or prunes rules based on evidence.
+description: Evaluates the effectiveness of SAGE-Code heuristics by correlating them with session outcomes. Demotes or prunes rules based on exposure evidence.
 model: sonnet
 tools:
   - Read
@@ -16,7 +16,7 @@ You evaluate whether SAGE-Code's learned heuristics are actually helping.
 
 ## Input
 - `.sage/knowledge/*.md` — Current heuristic inventory
-- `.sage/events/*.jsonl` — Recent session event logs
+- `.sage/meta/exposure.json` — For each rule: the sessions in which Claude Code loaded it, and what happened in them. The `sage-exposure` script makes this file from the event logs. Do not read the raw event logs
 - `.sage/meta/scores.json` — Previous score history
 - `.sage/meta/config.json` — Scoring thresholds
 
@@ -26,13 +26,21 @@ You evaluate whether SAGE-Code's learned heuristics are actually helping.
 Read all knowledge files. Build a list of all heuristics with their IDs (generated as `{category}-{slugified-heading}`), categories, confidence levels, and evidence.
 
 ### Step 2: Outcome Correlation
-For each heuristic, examine the session event logs listed in its Evidence field.
+For each heuristic, find `rules[<heuristic ID>]` in `exposure.json`.
+
+- **Not in the file:** the rule never loaded. There is no data. Keep the previous score (or 0.6 for a new entry). Do not demote or prune.
+- **`always_loaded: true`:** the rule loads in each session, so there is no control group. Compare the corrections on its topic in the early loaded sessions with the recent ones (`recent_loaded_sessions` is most recent first).
+- **Path-scoped, `sessions_loaded` < 3:** not sufficient data. Keep the previous score. Do not demote or prune.
+- **Path-scoped, `sessions_loaded` >= 3:** compare `corrections_per_session_loaded` with `corrections_per_session_not_loaded`, and the same for errors. Then read the `corrections` and `failed_commands` in `recent_loaded_sessions`.
+
+A correction on the topic of the rule, in a session where the rule was loaded, is strong evidence against the rule: the rule was in context and did not help, or the rule is wrong. A correction on a different topic says nothing about this rule.
+
 Scoring rubric:
-- **1.0** — No related corrections after the rule was created
-- **0.8** — Corrections decreased over time
-- **0.6** — No clear trend (neutral)
-- **0.4** — Corrections continued at similar rate
-- **0.2** — Corrections increased or rule was contradicted
+- **1.0** — Loaded in 3+ sessions, no corrections on its topic in them
+- **0.8** — Corrections on its topic decreased over time
+- **0.6** — No clear trend (neutral), or no data
+- **0.4** — Corrections on its topic continued at similar rate while the rule was loaded
+- **0.2** — Corrections on its topic increased, or the user contradicted the rule
 - **0.0** — Rule was actively harmful
 
 ### Step 3: Update Scores
@@ -42,7 +50,6 @@ For new entries: initial score = current evaluation, observations=1
 Write to `.sage/meta/scores.json`.
 
 ### Step 4: Take Action
-- **PROMOTE** (score > 0.7 AND confidence high): Log in history
 - **DEMOTE** (score < 0.4 AND trend declining AND observations >= 5): Drop confidence one level
 - **PRUNE** (score < 0.2 AND observations >= 10): Remove, archive with reason
 
````

- [ ] **Step 4: `sage-replay` — no scoring phase; publish after reflection**

Replace the full content of `sage-code/skills/sage-replay/SKILL.md` with:

````markdown
---
name: sage-replay
description: Processes pending SAGE-Code reflections from earlier sessions and publishes the learned rules. Runs at session start when the SessionStart context says that session logs are not reflected on yet.
user-invocable: false
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
  - Bash(rm .sage/events/*)
  - Bash(sage-publish-rules *)
---

# SAGE-Code Pending Reflections

Claude Code loads the learned rules itself, from `.claude/rules/sage/`. This skill does not load knowledge. It turns the logs of earlier sessions into knowledge.

## Phase 1: Deferred Reflection

1. Use Glob to find files matching `.sage/events/*.unprocessed`
2. For each (max 3), but never the log of the current session (`session-${CLAUDE_SESSION_ID}`):
   a. Read the corresponding `.jsonl` file
   b. Check if it has ≥5 tool_outcome events AND ≥1 correction/failure/positive_signal
   c. If sufficient: dispatch the `sage-code:reflector` subagent with the event log path
   d. Delete the `.unprocessed` marker after processing (`rm .sage/events/<name>.unprocessed`)

## Phase 2: Publish

If a reflector ran, run this command to make the rule files agree with the knowledge files:

```bash
sage-publish-rules "${CLAUDE_PROJECT_DIR}"
```

Report the summary line that the command prints.

## Phase 3: Meta-Evaluation Check

Read `.sage/meta/config.json`. If `sessions_since_eval` >= `meta_eval_interval_sessions`, output:
"[sage] Meta-evaluation due. Run /sage-code:sage-meta to evaluate heuristic effectiveness."
````

- [ ] **Step 5: `sage-reflect`, `sage-meta`, `sage-status`**

````diff
--- a/sage-code/skills/sage-reflect/SKILL.md
+++ b/sage-code/skills/sage-reflect/SKILL.md
@@ -9,6 +9,7 @@ allowed-tools:
   - Agent
   - Bash(git diff *)
   - Bash(rm .sage/events/*)
+  - Bash(sage-publish-rules *)
 ---
 
 # Manual Reflection Trigger
@@ -19,13 +20,15 @@ Force reflection on the current session's events immediately.
 
 1. Use the event log of the current session: `.sage/events/session-${CLAUDE_SESSION_ID}.jsonl`. If it does not exist, use the most recent log in `.sage/events/`
 2. Dispatch the `sage-code:reflector` subagent with the event log path
-3. Run `git diff -- .sage/knowledge/` to see what changed
-4. Summarize new/updated heuristics
-5. Remove the `.unprocessed` marker of that log if present (`rm .sage/events/<name>.unprocessed`)
+3. Run `sage-publish-rules "${CLAUDE_PROJECT_DIR}"` to make the rule files in `.claude/rules/sage/` agree with the knowledge files
+4. Run `git diff -- .sage/knowledge/` to see what changed
+5. Summarize new/updated heuristics
+6. Remove the `.unprocessed` marker of that log if present (`rm .sage/events/<name>.unprocessed`)
 
 Output:
 ```
 ## Sage Reflection Complete
 **New heuristics:** ...
 **Updated heuristics:** ...
+**Rule files:** {summary line of sage-publish-rules}
 ```
````

````diff
--- a/sage-code/skills/sage-meta/SKILL.md
+++ b/sage-code/skills/sage-meta/SKILL.md
@@ -7,19 +7,23 @@ allowed-tools:
   - Glob
   - Grep
   - Agent
+  - Bash(sage-exposure *)
+  - Bash(sage-publish-rules *)
 ---
 
 # Meta-Evaluation Orchestrator
 
-1. Dispatch the `sage-code:meta-evaluator` subagent
-2. After evaluation, dispatch the `sage-code:knowledge-curator` subagent
-3. Report results:
+1. Run `sage-exposure "${CLAUDE_PROJECT_DIR}"`. It writes `.sage/meta/exposure.json`: for each rule, the sessions in which Claude Code loaded it
+2. Dispatch the `sage-code:meta-evaluator` subagent
+3. After evaluation, dispatch the `sage-code:knowledge-curator` subagent
+4. Run `sage-publish-rules "${CLAUDE_PROJECT_DIR}"`. It deletes the rule files of pruned heuristics and updates the others
+5. Report results:
 
 ```
 ## Sage Meta-Evaluation Complete
 **Evaluated:** N heuristics
-**Promoted:** N (moved to CLAUDE.md)
 **Demoted:** N (confidence lowered)
 **Pruned:** N (removed, archived)
 **Average score:** 0.XX
+**Rule files:** {summary line of sage-publish-rules}
 ```
````

````diff
--- a/sage-code/skills/sage-status/SKILL.md
+++ b/sage-code/skills/sage-status/SKILL.md
@@ -18,7 +18,7 @@ Generate a status report of what SAGE has learned about this project.
 2. Count `.jsonl` files in `.sage/events/`
 3. Read all `.sage/knowledge/` files, extract confidence and category per entry
 4. Read `.sage/meta/scores.json` and `.sage/meta/history.json`
-5. Check CLAUDE.md for managed section entry count
+5. Count the `*.md` files in `.claude/rules/sage/`. A file that starts with `---` has `paths:` frontmatter and is path-scoped; the others load in each session
 
 ## Output
 
@@ -27,7 +27,7 @@ Generate a status report of what SAGE has learned about this project.
 
 Sessions analyzed: {count}
 Heuristics learned: {total} ({high} high, {medium} medium, {low} low)
-Promoted to CLAUDE.md: {count}
+Published rules: {count} ({path-scoped} path-scoped, {always} always loaded)
 Pruned (ineffective): {count in archive}
 Last meta-evaluation: {date or "never"}
 
````

- [ ] **Step 6: Validate**

Run: `claude plugin validate ./sage-code --strict`
Expected: `✔ Validation passed`

Run: `grep -rn "CLAUDE.md\|replay_max\|PROMOTE\|Promoted" sage-code/agents sage-code/skills`
Expected: one match only — the line in `knowledge-curator.md` that says "Do not edit `CLAUDE.md` or `.claude/rules/`".

- [ ] **Step 7: Commit**

```bash
git add sage-code/agents sage-code/skills
git commit -m "feat: teach agents and skills about Paths, exposure, and rule publishing" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Real run, documentation, and version

**Files:**
- Modify: `README.md`, `sage-code/README.md`, `CHANGELOG.md`, `sage-code/.claude-plugin/plugin.json`, `docs/superpowers/specs/2026-04-15-sage-code-design.md`

**Interfaces:**
- Consumes: all earlier tasks.
- Produces: version 0.3.0.

- [ ] **Step 1: Real run in a scratch project**

This step makes 2 short model calls (`--model haiku`). Run it from the repository root:

```bash
PLUGIN="$PWD/sage-code"
E2E=$(mktemp -d) && cd "$E2E" && git init -q && mkdir -p src/auth \
  && echo "export const login = () => 1;" > src/auth/login.ts && git add -A && git commit -q -m init
SAGE_PROJECT_DIR="$E2E" bash "$PLUGIN/bin/sage-init.sh"
cat >> .sage/knowledge/pitfalls.md <<'MD'

### NEVER use md5 for password hashing
- **Confidence:** low (1 observation)
- **Paths:** src/auth/**
- **Rule:** Use bcrypt for password hashing.
MD
cat >> .sage/knowledge/conventions.md <<'MD'

### ALWAYS write commit messages in the imperative mood
- **Confidence:** low (1 observation)
- **Rule:** Write "Add login", not "Added login".
MD
claude --plugin-dir "$PLUGIN" --model haiku -p "Run this exact bash command and print its output verbatim, nothing else: sage-publish-rules \"$E2E\"" --allowedTools "Bash(sage-publish-rules *)" < /dev/null
claude --plugin-dir "$PLUGIN" --model haiku -p "Read src/auth/login.ts and tell me in one sentence what hashing rule applies to this file." --allowedTools "Read" < /dev/null
ls -t .sage/events/*.jsonl | head -1 | xargs cat
bash "$PLUGIN/bin/sage-exposure" "$E2E" && cat .sage/meta/exposure.json
cd - > /dev/null
```

Expected:
1. The first session prints `sage-publish-rules: 2 published (2 written, 0 unchanged), 0 removed` (this proves that `bin/` is on `PATH`).
2. The second session answers with the bcrypt rule.
3. The newest log has a `rule_loaded` event for `convention-always-write-commit-messages-in-the-imperative-mood` with `"load_reason": "session_start"`, a `rule_loaded` event for `pitfall-never-use-md5-for-password-hashing` with `"load_reason": "path_glob_match"` and `"trigger_file": "src/auth/login.ts"`, one `session_start` event, and a `session_end` event with `"rules_loaded": 2`.
4. `exposure.json` has the two rules; the convention has `"always_loaded": true` and the pitfall has `"always_loaded": false`.

If a result is different, stop and find the cause before you continue.

- [ ] **Step 2: Root `README.md`**

Make these replacements.

In the architecture box, replace the Layer 5 and Layer 4 text:

````text
│  Layer 5: META-LEARNING (Self-Evaluation)           │
│  Measures which rules were loaded in which session  │
│  Demotes and prunes rules that do not help          │
├─────────────────────────────────────────────────────┤
│  Layer 4: REPLAY (Native Rules)                     │
│  Publishes each heuristic to .claude/rules/sage/    │
│  Claude Code loads a rule when a matching file is   │
│  read                                               │
````

In "What it does", replace the **Replays** and **Self-evaluates** bullets with:

````markdown
- **Replays** knowledge as native Claude Code rules: each heuristic is a file in `.claude/rules/sage/`, and a rule about `src/auth/` loads only when Claude reads a file in `src/auth/`
- **Self-evaluates** with measured exposure: it records which rules were in context in which session, compares sessions with and without each rule, and prunes the rules that do not help
````

In "How it works", replace items 5 and 6 and add items 7 and 8:

````markdown
5. **sage-replay skill** (next session) sends the reflector to the pending session logs. The reflector gives each heuristic a `Paths` field with the files where it applies
6. **`sage-publish-rules`** (a script, no model call) writes one rule file per heuristic to `.claude/rules/sage/`. Claude Code loads these files itself. SAGE-Code does not edit your `CLAUDE.md`
7. **InstructionsLoaded hook** records each rule that Claude Code loads, with the file that triggered the load
8. **Meta-evaluator** (every 10 sessions) reads the exposure data from `sage-exposure`, scores each rule, and demotes or prunes the rules that do not help
````

In "Project data", replace the first sentence and the tree with:

````markdown
SAGE creates a `.sage/` directory and a `.claude/rules/sage/` directory in your project:

```
.sage/
├── knowledge/        # Learned heuristics with evidence (committed to git)
│   ├── pitfalls.md   # Errors and anti-patterns to avoid
│   ├── strategies.md # Proven effective approaches
│   ├── preferences.md# User style and workflow preferences
│   ├── architecture.md# Project structure knowledge
│   └── conventions.md# Coding conventions
├── events/           # Session logs (gitignored, personal)
├── meta/             # Scores, config, history (committed)
└── README.md         # Auto-generated summary

.claude/rules/sage/   # One rule file per heuristic (committed to git)
└── pitfall-never-use-md5-for-password-hashing.md
```

Do not edit the files in `.claude/rules/sage/`. They are made from `.sage/knowledge/`. Edit the knowledge entry, then run `/sage-code:sage-reflect` or `sage-publish-rules`. Because the rule files are in git, each new rule appears in a diff for review.
````

Replace the "Knowledge lifecycle" diagram and the sentence after it with:

````markdown
```
Captured (1 obs, low) → Reinforced (2-3, medium) → Established (4+, high)
        │                        │                          │
        └────────── published to .claude/rules/sage/ ───────┘
                                 │
                   Demoted (corrections continue while the rule is loaded)
                                 │
                   Pruned (score < 0.2, or no evidence and no load in 30 days)
```

Each heuristic is published from its first observation. Set `publish_min_confidence` to `medium` to publish a heuristic only after a second observation.
````

In the configuration table, remove the rows `replay_max_heuristics` and `promote_score_threshold`, and add this row as the first row:

````markdown
| `publish_min_confidence` | `low` | Lowest confidence that is published as a rule file (`low`, `medium`, or `high`) |
````

Replace the `stale_days` row with:

````markdown
| `stale_days` | 30 | Days with no new evidence and no load before pruning |
````

Change the version badge from `version-0.2.0-blue.svg` to `version-0.3.0-blue.svg`. In "Design docs", add this line after the design spec line:

````markdown
- [Native rules and measured exposure](docs/superpowers/specs/2026-09-17-native-rules-and-exposure-design.md) — Layers 4 and 5 since 0.3.0
````

- [ ] **Step 3: Plugin `sage-code/README.md`**

Replace items 4 and 5 of "How it works" with:

````markdown
4. **Rules** — `sage-publish-rules` writes one file per heuristic to `.claude/rules/sage/`; Claude Code loads a path-scoped rule only when Claude reads a matching file
5. **Meta-evaluator** periodically scores rules with measured exposure (which rules loaded in which session) and prunes ineffective ones
````

In "Project data", add this line after the `meta/` line:

````markdown
- `.claude/rules/sage/` — One rule file per heuristic (committed to git, made from `knowledge/`; do not edit)
````

- [ ] **Step 4: `CHANGELOG.md`**

Insert this block immediately before the line `## [0.2.0] - 2026-09-17`:

````markdown
## [0.3.0] - 2026-09-17

Replay uses native Claude Code rules, and meta-evaluation uses measured exposure.

### Added
- `sage-publish-rules` script: writes one rule file per heuristic to `.claude/rules/sage/`, with `paths:` frontmatter from the new `Paths` field of a knowledge entry
- `InstructionsLoaded` hook: records a `rule_loaded` event each time Claude Code loads a sage rule, with the load reason and the file that triggered the load
- `sage-exposure` script: aggregates rule loads into `.sage/meta/exposure.json` for the meta-evaluator and the curator
- Config key `publish_min_confidence` (default `low`)
- `rules_loaded` in the `session_end` summary

### Changed
- The reflector gives each heuristic a `Paths` field with the files where it applies
- The meta-evaluator compares sessions where a rule was loaded with sessions where it was not
- A rule is stale only when it has no new evidence **and** did not load in `stale_days`. Before, a rule that worked was pruned, because a rule that works causes no new corrections
- The SessionStart hook finds a new session by its `session_start` event, and adds context only when a reflection is pending or meta-evaluation is due
- `sage-replay` no longer scores and prints heuristics; Claude Code loads the rule files itself

### Removed
- The managed "Sage Learnings" section in `CLAUDE.md`. SAGE-Code no longer edits `CLAUDE.md`
- The PROMOTE action of the meta-evaluator
- Config keys `replay_max_heuristics`, `replay_max_tokens`, and `promote_score_threshold`

### Migration
- The first run of `sage-publish-rules` removes the old "Sage Learnings" section from `CLAUDE.md`, if its start and end markers are there
- Commit the new `.claude/rules/sage/` directory
- Add the line `meta/exposure.json` to the `.sage/.gitignore` of a project that was initialized with an earlier version

````

- [ ] **Step 5: Version and the note in the first spec**

In `sage-code/.claude-plugin/plugin.json`, change `"version": "0.2.0"` to `"version": "0.3.0"`.

In `docs/superpowers/specs/2026-04-15-sage-code-design.md`, insert this block after the line `**Author:** Claude + Umar  ` and the blank line that follows it:

````markdown
> **Note (2026-09-17):** Layer 4 (Replay) and Layer 5 (Meta-Learning) changed in 0.3.0. See [Native Rules and Measured Exposure](2026-09-17-native-rules-and-exposure-design.md). The hook details in this document changed in 0.2.0: hooks read JSON from stdin, and `SessionEnd` replaced `Stop`. See `CHANGELOG.md`.

````

- [ ] **Step 6: Final checks**

Run: `bash sage-code/tests/run-all.sh`
Expected: `1..125`, all `ok`.

Run: `claude plugin validate . --strict && claude plugin validate ./sage-code --strict`
Expected: `✔ Validation passed` two times.

Run: `grep -rn "Promoted to CLAUDE.md\|replay_max_heuristics\|promote_score_threshold" README.md sage-code/`
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add README.md sage-code/README.md CHANGELOG.md sage-code/.claude-plugin/plugin.json docs/superpowers/specs/2026-04-15-sage-code-design.md
git commit -m "docs: describe native rules and measured exposure; bump version to 0.3.0" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```
