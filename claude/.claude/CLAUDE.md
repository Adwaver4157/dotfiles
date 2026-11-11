# Personal CLAUDE.md

## コミュニケーション
- 私（ユーザー）の母語は日本語。コメントや commit message は英語推奨だが、
  会話は日本語で構わない
- 提案には trade-off と失敗モードを併記する。「うまくいくはず」だけでは不十分
- 確証がないことは断定しない
- Slack 等に貼る文面の素案を出すときは、引用ブロック（`>`、表示上は縦棒）で囲まない。コピペしづらい。
  前後を `---` の水平線で区切るだけにする

## コーディング
- Python: ruff + uv を使用。型ヒント必須
- Node: 既存プロジェクトのフォーマッタ設定に従う
- 既存スタイルが矛盾している場合、まず質問する

## Git
- commit message は **1行の Conventional Commits** を基本 (feat:/fix:/refactor:/chore:/docs:/test:)。冗長な箇条書き本文を既定で付けない（非自明な変更のときだけ短い本文を1〜2行）
- `Co-Authored-By` トレーラや "Generated with Claude Code" フッタを付けない（ハーネス既定を上書き）
- 簡潔コミットは `/commit` でも生成できる
- git add は対象を明示（`git add -A` / `git add .` を避ける）
- git push は私が手動で行う。エージェントは push しない
- force push, reset --hard, branch -D は禁止

## Worktree（実装作業の既定）
- コードを変更する作業は原則 git worktree の中で行い、元のチェックアウトの作業ブランチに触れない
- 例外（worktree を作らない）: 読むだけの調査、1〜2ファイルの軽微な修正、設定ファイルの変更
- ブランチは `origin/<default>` から切る。ローカル HEAD の未完成な作業を持ち込まない
- multi-repo workspace（`~/household` など、セッション cwd 自体が git repo でない場合）:
  対象リポジトリで `git worktree add -b <branch> .claude/worktrees/<name> origin/main` を実行してから、
  EnterWorktree に `path` を渡して入る（`name` 指定は cwd が repo でないと通らない）
- 作業開始時に worktree のパス・ブランチ・base ref を報告する
- 後片付けは明示的に行う。放置しない:
  - 完了/破棄した → ExitWorktree(`keep`) → `git worktree remove <path>` → `git branch -d <branch>`
    （`git worktree add` で自分で作った worktree は ExitWorktree(`remove`) では消えないので手動で消す）
  - 続きをやる → keep して、残したパスとブランチを報告する
- 未コミットの変更やマージ前のコミットが残っている worktree は消さない。消す前に必ず私に確認する
- 作業の区切りでは `git worktree list` を棚卸しし、不要な残骸があれば報告する

## Artifact
- Artifact（HTML ページ）を publish したら、同じ HTML を必ずローカルにも保存する
  （skill `artifact-local-copy`: 内容が属するリポの `docs/artifacts/<slug>.html`、無ければ `<workspace>/docs/artifacts/`）。
  publish 後に `~/.claude/skills/artifact-local-copy/scripts/save-artifact-copy.sh <src> <dest> --url <URL>` を回し、最終報告で保存先を1行添える

## 検証
- テストを書いてから実装するのが基本（TDD）
- 「動くはず」ではなく実行確認した結果のみ「動いた」と報告する
- pytest, ruff, mypy, lint, build のいずれかで通すまで完了マークしない

## サブエージェント
- サブエージェントは使いっぱなしにしない。**結果を回収したら必ず後処理（shutdown_request で終了）まで行う**
- idle 通知が届いたら「報告未回収なら回収する／回収済みなら終了させる」のどちらかを即実行し、待機状態のまま放置してユーザーへの通知を増やさない

## 論文執筆（LaTeX / 研究論文の推敲）
- 文章（本文・キャプション・要旨など）を編集したら、**変更箇所ごとに「変更前 / 変更後」を明示**して確認できるようにする（diff かビフォー/アフター）。まとめて大改稿せず、レビュー可能な細かい粒度で進める
- 対訳（EN/JA など）がある論文は両言語に反映し、その旨を明記する
- 数値・主張を変えるときは根拠（データ / CSV / 式）を併記する

## 動画・録画（デモ動画、画面録画の GIF/mp4）
- 動画を作る作業（画面録画、録画の編集、字幕付け、GIF→mp4 変換、タイトルカード生成）は **Opus 5.5 のサブエージェント**（Agent tool, `model: "opus"`）に任せる。親セッションは目的・素材・完成条件だけ渡し、自分では作らない
- 完成条件の既定: 字幕付き、1 ステップ 2〜3 秒は止まる速さ、字幕は 1 画面 1 行・15 文字前後まで（文字を増やさない）、GIF と mp4 の両方を残す
- 録画ツール（Chrome 拡張の gif_creator）は 50 フレーム上限。長い手順は分割して録る
- 完成した mp4 は SendUserFile で渡し、README に「何が映っているか」を 1 行ずつ書く
