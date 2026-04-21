#!/usr/bin/env bash
# vrm-review/scripts/review.sh
# Copilot CLI + GPT-5.4 で画像レビューを実行する薄いラッパー
#
# 使い方:
#   ./review.sh <screenshot_path> <review_type> [extra_instructions]
#
# 例:
#   ./review.sh ./expression-001.png expression
#   ./review.sh ./pose-001.png pose "rokuroポーズで腕が胴体に埋もれている問題を重点的に"
#
# 前提:
#   - Copilot CLI v1.0.24+ が PATH にある
#   - GitHub Copilot Pro サブスクリプション (premium枠300/月)
#   - 画像ファイルは絶対パス or 相対パスで指定

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"
PROMPTS_FILE="$TEMPLATES_DIR/prompts.md"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <screenshot_path> <review_type> [extra_instructions]" >&2
  echo "  review_type: expression | pose | lipsync | layout | overall" >&2
  exit 1
fi

SCREENSHOT="$1"
REVIEW_TYPE="$2"
EXTRA="${3:-}"

if [ ! -f "$SCREENSHOT" ]; then
  echo "Error: screenshot file not found: $SCREENSHOT" >&2
  exit 2
fi

if ! command -v copilot >/dev/null 2>&1; then
  echo "Error: copilot CLI not found in PATH" >&2
  echo "Install: npm i -g @github/copilot" >&2
  exit 3
fi

# prompts.md から該当セクションを抽出（## <review_type> の次のコードブロック）
# Windows/WSL 両対応のため awk で実装
PROMPT=$(awk -v section="## $REVIEW_TYPE" '
  $0 == section { in_section = 1; next }
  in_section && /^##[^#]/ { exit }
  in_section && /^```/ { in_block = !in_block; next }
  in_section && in_block { print }
' "$PROMPTS_FILE")

if [ -z "$PROMPT" ]; then
  echo "Error: review type '$REVIEW_TYPE' not found in $PROMPTS_FILE" >&2
  exit 4
fi

# 共通前提を抽出
COMMON_PREFIX=$(awk '
  /^## 共通前提/ { in_section = 1; next }
  in_section && /^---/ { exit }
  in_section && /^```/ { in_block = !in_block; next }
  in_section && in_block { print }
' "$PROMPTS_FILE")

FULL_PROMPT="$COMMON_PREFIX

$PROMPT"

if [ -n "$EXTRA" ]; then
  FULL_PROMPT="$FULL_PROMPT

追加指示: $EXTRA"
fi

echo "=== vrm-review ==="
echo "Screenshot: $SCREENSHOT"
echo "Review type: $REVIEW_TYPE"
echo "Model: gpt-5.4"
echo "Premium credit: 1"
echo "==================="

# Copilot CLI 呼び出し
# -p: one-shot prompt
# --model: GPT-5.4 指定（デフォルトだと 5.2 の可能性）
# --allow-all: 画像読み込みを自動許可
# -s: silent（対話プロンプト抑制）
copilot -p "@${SCREENSHOT} ${FULL_PROMPT}" \
  --model gpt-5.4 \
  --allow-all \
  -s
