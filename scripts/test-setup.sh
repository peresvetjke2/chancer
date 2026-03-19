#!/usr/bin/env bash

set -u

PATH="${HOME}/.local/bin:/usr/local/bin:/opt/homebrew/bin:${PATH}"
export PATH

required_failures=0
warnings=0

REQUIRED_SKILLS=(
  "tgcli"
  "playwright-cli"
  "prompt-engeneering"
  "gws-docs"
  "gws-docs-write"
  "gws-drive"
  "gws-sheets"
)

OPTIONAL_CLAUDE_MARKETPLACES=(
  "dapi"
)

OPTIONAL_CLAUDE_PLUGINS=(
  "himalaya@dapi"
  "pr-review-fix-loop@dapi"
  "spec-reviewer@dapi"
  "zellij-workflow@dapi"
)

section() {
  printf '\n== %s ==\n' "$1"
}

ok() {
  printf '[OK] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  required_failures=$((required_failures + 1))
}

warn() {
  printf '[WARN] %s\n' "$1"
  warnings=$((warnings + 1))
}

note() {
  printf '       %s\n' "$1"
}

compact_output() {
  printf '%s' "$1" \
    | tr '\n' ' ' \
    | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//' \
    | cut -c1-220
}

extract_json() {
  printf '%s\n' "$1" | awk '
    BEGIN { start = 0 }
    /^[[:space:]]*[{[]/ { start = 1 }
    start { print }
  '
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

check_command() {
  local severity="$1"
  local label="$2"
  shift 2

  local output
  if output="$("$@" 2>&1)"; then
    ok "$label"
    return 0
  fi

  if [ "$severity" = "required" ]; then
    fail "$label"
  else
    warn "$label"
  fi
  note "$(compact_output "$output")"
  return 1
}

check_json_command() {
  local severity="$1"
  local label="$2"
  local filter="$3"
  shift 3

  local output
  if ! output="$("$@" 2>&1)"; then
    if [ "$severity" = "required" ]; then
      fail "$label"
    else
      warn "$label"
    fi
    note "$(compact_output "$output")"
    return 1
  fi

  if command_exists jq && printf '%s' "$output" | jq -e "$filter" >/dev/null 2>&1; then
    ok "$label"
    return 0
  fi

  if command_exists jq && extract_json "$output" | jq -e "$filter" >/dev/null 2>&1; then
    ok "$label"
    return 0
  fi

  if [ "$severity" = "required" ]; then
    fail "$label"
  else
    warn "$label"
  fi
  note "$(compact_output "$output")"
  return 1
}

check_port_selector() {
  local output

  if ! command_exists port-selector; then
    fail "port-selector installed"
    return 1
  fi

  if output="$(port-selector --name setup-check 2>&1)"; then
    if printf '%s' "$output" | tr -d '[:space:]' | grep -Eq '^[0-9]+$'; then
      ok "port-selector returns a free port"
      port-selector --forget --name setup-check >/dev/null 2>&1 || true
      return 0
    fi
  fi

  fail "port-selector returns a free port"
  note "$(compact_output "$output")"
  port-selector --forget --name setup-check >/dev/null 2>&1 || true
  return 1
}

check_himalaya_accounts() {
  local output

  if ! command_exists himalaya; then
    fail "himalaya installed"
    return 1
  fi

  if ! output="$(himalaya account list --output json 2>&1)"; then
    warn "himalaya mail account configured"
    note "$(compact_output "$output")"
    return 1
  fi

  if command_exists jq && printf '%s' "$output" | jq -e 'length > 0' >/dev/null 2>&1; then
    ok "himalaya mail account configured"
    return 0
  fi

  warn "himalaya mail account configured"
  note "$(compact_output "$output")"
  return 1
}

check_skills() {
  local output
  local skill

  if ! command_exists npx; then
    fail "npx available for skills checks"
    return 1
  fi

  if ! command_exists jq; then
    fail "jq available for skills checks"
    return 1
  fi

  if ! output="$(npx skills ls -g --json 2>&1)"; then
    warn "curated skills can be listed"
    note "$(compact_output "$output")"
    return 1
  fi

  for skill in "${REQUIRED_SKILLS[@]}"; do
    if printf '%s' "$output" | jq -e --arg skill "$skill" 'map(select(.name == $skill)) | length > 0' >/dev/null 2>&1; then
      ok "skill installed: $skill"
    else
      warn "skill installed: $skill"
    fi
  done
}

check_claude_plugins() {
  local marketplaces_output
  local plugins_output
  local name

  if ! command_exists claude; then
    fail "claude installed"
    return 1
  fi

  if ! marketplaces_output="$(claude plugins marketplace list 2>&1)"; then
    warn "Claude plugin marketplaces can be listed"
    note "$(compact_output "$marketplaces_output")"
    return 1
  fi

  for name in "${OPTIONAL_CLAUDE_MARKETPLACES[@]}"; do
    if printf '%s' "$marketplaces_output" | grep -Fq "$name"; then
      ok "Claude marketplace present: $name"
    else
      warn "Claude marketplace present: $name"
    fi
  done

  if ! plugins_output="$(claude plugins list 2>&1)"; then
    warn "Claude plugins can be listed"
    note "$(compact_output "$plugins_output")"
    return 1
  fi

  for name in "${OPTIONAL_CLAUDE_PLUGINS[@]}"; do
    if printf '%s' "$plugins_output" | grep -Fq "$name"; then
      ok "Claude plugin installed: $name"
    else
      warn "Claude plugin installed: $name"
    fi
  done
}

section "Core toolchain (required)"
check_command required "mise installed" mise --version
check_command required "direnv installed" direnv version
check_command required "gh installed" gh --version
check_command required "himalaya installed" himalaya --version
check_command required "gitleaks installed" gitleaks version
check_command required "jq installed" jq --version
check_command required "node installed" node --version
check_command required "npx installed" npx --version
check_port_selector
check_command required "ruby installed" ruby --version
check_command required "tmux installed" tmux -V
check_command required "yarn installed" yarn --version
check_command required "zellij installed" zellij --version

section "Agent CLIs (required)"
check_command required "claude installed" claude --version
check_command required "codex installed" codex --version
check_command required "playwright-cli installed" playwright-cli --version
check_command required "tgcli installed" tgcli --help
check_command required "gws installed" gws --help

section "Account-backed tools"
check_json_command required "claude authenticated" '.loggedIn == true' claude auth status --json
check_command required "codex authenticated" codex login status
check_command required "gh authenticated" gh auth status
check_command optional "tgcli authenticated" tgcli auth status
check_json_command optional "gws authenticated" 'if has("token_valid") then .token_valid == true else true end' gws auth status
check_himalaya_accounts

section "Optional agent extras"
check_skills
check_claude_plugins

printf '\nSummary: %s required failure(s), %s warning(s)\n' "$required_failures" "$warnings"

if [ "$required_failures" -ne 0 ]; then
  exit 1
fi
