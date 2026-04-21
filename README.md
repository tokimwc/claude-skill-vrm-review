# claude-skill-vrm-review

Claude Code Skill that delegates **VRM / Live2D character expression reviews** from Claude Opus to **GitHub Copilot CLI + GPT-5.4** via Playwright MCP.

```
User → Claude Code → Playwright MCP → Screenshot
                  → copilot CLI `@screenshot.png` --model gpt-5.4
                  → Markdown report with blendshape names & strength values
```

## Why

Claude Opus 4.6 can read images, but for expression review tasks it tends to return adjective-based feedback ("natural", "balanced", "expressive"). GPT-5.4 via GitHub Copilot CLI tends to return **implementation-ready numeric values** (`happy 0.15`, `head tilt 4°`, `chest twist 3°`) — the kind you can paste straight into `vrm.expressionManager.setValue()`.

This Skill wraps that delegation into a 4-step pipeline so Claude Code doesn't burn its own weekly quota on heavy image tokens.

## Quickstart

```bash
gh skill install tokimwc/claude-skill-vrm-review
```

Or with a specific version:

```bash
gh skill install tokimwc/claude-skill-vrm-review vrm-review@v1.0.0
```

Then in Claude Code:

```
/vrm-review expression http://localhost:5173
```

## Prerequisites

- **Claude Code** (Opus 4.6 or later)
- **GitHub Copilot CLI** v1.0.24+ (`npm i -g @github/copilot`)
- **GitHub Copilot Pro** subscription (for GPT-5.4 access)
- **Playwright MCP** server connected to Claude Code
- A running VRM dev server (e.g. Vite + Three.js + [@pixiv/three-vrm](https://github.com/pixiv/three-vrm))

## Review types

| Type | Focus |
|------|-------|
| `expression` | blendshape combinations, emotion coherence, gaze alignment |
| `pose` | bone rotations, balance, silhouette readability |
| `lipsync` | mouth shape vs vowel, FFT scale, emotion interference |
| `layout` | stream safe zones, 2-character placement, UI visibility |
| `overall` | runs all four and returns a prioritized Top 5 |

See [`templates/prompts.md`](templates/prompts.md) for the full prompt library.

## Files

```
.
└── vrm-review/
    ├── SKILL.md              # Claude Code Skill definition
    ├── scripts/
    │   └── review.sh         # Thin wrapper around `copilot -p`
    └── templates/
        └── prompts.md        # Prompt templates for the 5 review types
```

## Related

- Companion article (Japanese): [_Claude Code から Copilot CLI + GPT-5.4 に画像レビューを委任する — AITuber VRM の表情を自動レビューする Skill_](https://zenn.dev/toki_mwc/articles/claude-code-copilot-gpt54-vrm-review) — published for [GitHub Copilot 活用選手権 2026 Spring](https://zenn.dev/contests/github-2026-spring)
- Inspiration: [soyukke / opencode + GPT-5.4 screenshot review skill](https://zenn.dev/soyukke/articles/opencode-gpt54-screenshot-review-skill)
- GitHub Copilot CLI docs: <https://docs.github.com/en/copilot/github-copilot-in-the-cli>

## License

MIT — see [LICENSE](LICENSE).
