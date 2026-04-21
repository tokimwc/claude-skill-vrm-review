---
name: vrm-review
description: VRM/Live2D表情をPlaywrightスクショ→Copilot CLI→GPT-5.4で自動レビュー。Claude Opusトークン温存＋具体的な改善提案取得
argument-hint: "[review-type] [url]  例: expression http://localhost:5173"
license: MIT
---

# vrm-review — AITuber表情の自動レビュー

VRMまたはLive2Dキャラクターの表情・ポーズ・リップシンクを、Playwrightで撮影→Copilot CLI経由でGPT-5.4に委譲してレビューする。

**なぜ委譲するか**: Claude Opus 4.6も画像理解は可能だが、(1) Opusトークン消費が重い、(2) 表情の審美的ニュアンスはGPT-5.4の方が具体的な改善提案を返す（「色が強い」ではなく「まぶた角度3度下げ+頬紅-10%」レベル）。

## 入力

ユーザーから以下を受け取る:
- `$ARGUMENTS` 第1引数: レビュー種別 `expression` / `pose` / `lipsync` / `layout` / `overall`
- `$ARGUMENTS` 第2引数: 対象URL（省略時は `http://localhost:5173`）
- `$ARGUMENTS` 第3引数以降: 追加指示（例: `emotion=angry` `pose=rokuro`）

## 前提環境

1. **Copilot CLI v1.0.24+** が PATH に通っている（`copilot --version`）
2. **GitHub Copilot Pro サブスクリプション**（$10/月, premium枠300/月）
3. **Playwright MCP** が Claude Code に接続済み（`mcp__plugin_playwright_playwright__*`）
4. 対象VRMプロジェクトの **dev serverが起動中**（例: `cd <your-vrm-project> && npm run dev` で `:5173` に立つ想定）

## 手順

### Step 1: 対象ページへ移動
Playwright MCP でブラウザを起動し、指定URL（デフォルト `http://localhost:5173`）へ遷移する。
```
mcp__plugin_playwright_playwright__browser_navigate url=<target_url>
```

遷移後は必ず `browser_wait_for` で主要要素が描画されるまで待つ（VRMのロードは3-5秒かかる）。

### Step 2: レビュー種別に応じたセットアップ
| review-type | セットアップ |
|---|---|
| `expression` | `?debug` クエリを付与してデバッグUI表示、`browser_evaluate` で `window.vrm.expressionManager.setValue('angry', 0.8)` 等を叩いて表情を適用 |
| `pose` | `browser_evaluate` で poses.ts の名前付きポーズを適用（例: `window.__setPose('rokuro')`） |
| `lipsync` | `/api/speak` POST でテスト発話をトリガー、発話中にスクショ |
| `layout` | セットアップ不要。配信UI全体をそのまま撮影 |
| `overall` | 全種類を順に実行してレビュー |

### Step 3: スクリーンショット撮影
`browser_take_screenshot` で撮影。保存先は呼び出し元プロジェクトの `test-artifacts/vrm-review-YYYY-MM-DD/`。

```
mcp__plugin_playwright_playwright__browser_take_screenshot
  filename=<review-type>-<timestamp>.png
  fullPage=false
```

**注意**: ビューポートは1280x720（配信アスペクト比と同じ16:9）に統一。`browser_resize` で事前に揃える。

### Step 4: Copilot CLI に委譲
撮影した画像をGPT-5.4に送り、レビューさせる。プロンプトは `templates/prompts.md` から種別に応じたものを読み込む。

```bash
copilot -p "@<screenshot_path> <prompt>" \
  --model gpt-5.4 \
  --allow-all \
  -s
```

**重要**:
- `--model gpt-5.4` を必ず明示（デフォルトモデルだとGPT-5.2の可能性がある）
- `-s`（silent mode）で対話プロンプトを抑制
- `--allow-all` で画像読み込みを自動許可
- **プレミアム枠300/月を消費する**ので、1回1クレジット換算。連発注意

### Step 5: 結果を Markdown レポート化
Copilot CLI のstdout出力をパース。`test-artifacts/vrm-review-YYYY-MM-DD/report.md` に以下のフォーマットで保存:

```markdown
# VRM Review Report — <review-type>

- 実行時刻: YYYY-MM-DD HH:MM JST
- 対象URL: <url>
- モデル: gpt-5.4 (via Copilot CLI)
- プレミアム消費: 1

## スクリーンショット
![screenshot](./<filename>.png)

## GPT-5.4レビュー
<Copilot出力そのまま>

## 推奨アクション（Claudeによる整理）
- [ ] <抽出された改善提案1>
- [ ] <抽出された改善提案2>
```

### Step 6: ユーザーへのサマリー返却
最終メッセージで以下を提示:
1. スクリーンショットのパス（クリッカブルmarkdownリンク）
2. レビュー要点（3行以内）
3. 推奨アクション（Top 3）
4. レポートファイルへのリンク

## 成果物の置き場

- **グローバル**: スクリプトとテンプレはこのSkillディレクトリ（`~/.claude/skills/vrm-review/`）
- **プロジェクト固有**: test-artifacts はユーザーのプロジェクト配下（例: `<your-vrm-project>/test-artifacts/vrm-review-YYYY-MM-DD/`）
- プロジェクト側に `.gitignore` で `test-artifacts/vrm-review-*/` を除外推奨

## 失敗時のフォールバック

1. **Playwright MCP接続失敗** → `mcp__plugin_playwright_playwright__browser_install` を提案、それでも駄目なら手動スクショ（`Snipping Tool`）とファイルパス指定でSkipして Step 4へ
2. **Copilot CLI未インストール** → `winget install GitHub.cli` や `npm i -g @github/copilot` を案内
3. **GPT-5.4 premium枠不足** → `--model gpt-5.3-codex` にフォールバック（品質低下を明示）
4. **dev server未起動** → `npm run dev` を案内、起動待ちなら5秒リトライ

## 関連

- グローバル指示: `~/.copilot/copilot-instructions.md`（ユーザー固有の Copilot CLI デフォルト動作を定義）
- 元ネタ記事: [soyukke「opencode + GPT-5.4 screenshot review skill」](https://zenn.dev/soyukke/articles/opencode-gpt54-screenshot-review-skill)
- GitHub Copilot CLI 公式: <https://docs.github.com/en/copilot/github-copilot-cli>
