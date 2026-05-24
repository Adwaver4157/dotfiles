# Personal CLAUDE.md

## コミュニケーション
- 私（ユーザー）の母語は日本語。コメントや commit message は英語推奨だが、
  会話は日本語で構わない
- 提案には trade-off と失敗モードを併記する。「うまくいくはず」だけでは不十分
- 確証がないことは断定しない

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

## 検証
- テストを書いてから実装するのが基本（TDD）
- 「動くはず」ではなく実行確認した結果のみ「動いた」と報告する
- pytest, ruff, mypy, lint, build のいずれかで通すまで完了マークしない
