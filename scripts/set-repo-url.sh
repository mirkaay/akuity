#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 https://github.com/<user>/<repo>.git"
  exit 1
fi

REPO_URL="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$REPO_URL" in
  http://*|https://*|git@*) ;;
  *)
    echo "ERROR: repository URL should be an https/http URL or git@ SSH URL."
    exit 1
    ;;
esac

find "$ROOT_DIR/apps" "$ROOT_DIR/bootstrap" "$ROOT_DIR/docs" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.md' \) -print0 \
  | xargs -0 sed -i "s|REPLACE_WITH_YOUR_GIT_REPO_URL|$REPO_URL|g"

echo "Repository URL set to: $REPO_URL"
echo "Review changes, commit, and push before bootstrapping Argo CD."
