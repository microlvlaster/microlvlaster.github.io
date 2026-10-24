#!/usr/bin/env bash
# boot.sh — one-line start for a fresh Omarchy machine.
#
#   curl -fsSL microlvlaster.github.io/boot.sh | bash
#   curl -fsSL .../boot.sh | bash -s -- --dry-run      # pass options to install.sh
#
# What it does:
#   1. installs the GitHub CLI (gh) if it is missing
#   2. logs you in to GitHub (the repo is private)
#   3. clones the repo, or updates it if it is already there
#   4. runs ./install.sh
#
# Settings (environment variables):
#   OI_REPO    GitHub repo to clone      (default: microlvlaster/omarchy-install)
#   OI_DIR     where to put it           (default: ~/Work/omarchy-install)
#   OI_BRANCH  branch to use             (default: main)
#
# The source of this file lives in the repo; the public gist is a copy.
# Update the gist with ./tools/publish-boot.sh after changing it.

# Everything is inside main() so a half-downloaded script never runs.
main() {
  set -euo pipefail

  local repo="${OI_REPO:-microlvlaster/omarchy-install}"
  local dir="${OI_DIR:-$HOME/Work/omarchy-install}"
  local branch="${OI_BRANCH:-main}"

  local blue='' red='' reset=''
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    blue=$'\e[1;34m'; red=$'\e[1;31m'; reset=$'\e[0m'
  fi
  say()  { printf '%s==>%s %s\n' "$blue" "$reset" "$*"; }
  fail() { printf '%sError:%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

  # When run as `curl | bash`, stdin is the script itself. Interactive
  # prompts (sudo, gh login, gum) must read from the terminal instead.
  local tty=/dev/tty
  if ! { true < /dev/tty; } 2>/dev/null; then
    tty=/dev/stdin
  fi

  [[ $EUID -ne 0 ]] || fail "Run as your normal user, not root."
  command -v omarchy >/dev/null || fail "This is meant for an Omarchy system ('omarchy' command not found)."
  command -v git >/dev/null || fail "git is not installed."

  if ! command -v gh >/dev/null; then
    say "Installing GitHub CLI ..."
    omarchy pkg add github-cli < "$tty"
  fi

  if ! gh auth status >/dev/null 2>&1; then
    say "Log in to GitHub — a code will be shown; paste it into the page that opens."
    gh auth login --hostname github.com --git-protocol https --web < "$tty"
  fi
  # Let plain `git pull` / `git push` use the gh login.
  gh auth setup-git >/dev/null 2>&1 || true

  if [[ -d "$dir/.git" ]]; then
    say "Updating $dir ..."
    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
      say "Local changes found — not updating, using the copy as it is."
    else
      git -C "$dir" fetch --quiet origin "$branch"
      git -C "$dir" checkout --quiet "$branch"
      git -C "$dir" merge --ff-only --quiet "origin/$branch" \
        || say "Could not fast-forward — using the copy as it is."
    fi
  elif [[ -e "$dir" ]]; then
    fail "$dir exists but is not a git checkout. Move it away or set OI_DIR."
  else
    say "Cloning $repo into $dir ..."
    mkdir -p "$(dirname "$dir")"
    gh repo clone "$repo" "$dir" -- --branch "$branch" --quiet
  fi

  say "Starting the installer ..."
  cd "$dir"
  exec ./install.sh "$@" < "$tty"
}

main "$@"
