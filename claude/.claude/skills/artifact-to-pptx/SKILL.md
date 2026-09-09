---
name: artifact-to-pptx
description: HTML資料やclaude.aiのArtifactを，編集可能なPPTX（Google Slidesアップロード対応）に変換する。「pptxにして」「スライドにして」「Google Slidesに上げたい」と言われたら使う。
---

# Artifact → PPTX 変換スキル

HTML/Markdown/Artifactの資料を，python-pptx で「全要素が編集可能な」PPTXに変換する。

## 手順

1. **ソース取得**
   - claude.ai の Artifact URL → `WebFetch` で全HTMLを取得（`curl` はSPAシェルしか返らないので使わない）
   - 描画が不安定で WebFetch が失敗する場合はブラウザ（claude-in-chrome）で開いてスクリーンショット読み取り
   - ローカルHTML/mdなら `Read`

2. **環境構築**（scratchpad推奨）
   ```bash
   python3 -m venv .venv
   ./.venv/bin/pip install -U pip setuptools wheel
   ./.venv/bin/pip install --only-binary=:all: pillow python-pptx
   ```
   ※ Pillow はソースビルドが失敗しやすいので必ず `--only-binary=:all:` を付ける

3. **生成スクリプトを書く**
   - このスキルディレクトリの `pptx_helpers.py` を作業ディレクトリへコピーし，`from pptx_helpers import *` で使う
   - スライドごとに `sl = slide(prs)` → `header()` → 本文（`card`/`mk_table`/`box`/`txt`）→ `keyband()` の順に組む

4. **保存と受け渡し**
   - 保存先はユーザー指定の場所（指定がなければ作業リポジトリ直下）
   - `SendUserFile` で送る。**Google Slidesへのアップロードはユーザー本人が行う**（勝手にアップしない）
   - 生成スクリプトは消さずに残す（修正依頼に数分で応えるため）

## 設計ルール（重要）

- 16:9（13.333 × 7.5 in）・blankレイアウト（`prs.slide_layouts[6]`）
- **文字は必ず 15pt（＝20px）以上**。helpers が15pt未満の指定を自動で15ptに引き上げる（`MIN_PT`）。タイトル26pt・キーメッセージ帯15.5〜16pt・本文/表15pt
- 1スライドの型：`header`（眉ラベル＋タイトル＋下罫線）→ 本文 → `keyband`（下部の色帯＝そのスライドのキーメッセージ）
- **不要な文字は載せない**：レビュー注記・要確認メモ・出典の細目・スライド番号は削る
- 大きすぎる表は上位数行の抜粋＋「全表は元資料参照」の1行に落とす
- 棒グラフ・ガント・ファネルは **shape で描く**（画像にしない＝Google Slidesで編集可能に保つ）
- 点線は lxml で `a:prstDash` を注入（`box(..., dash=True)` 相当は helpers 参照）
- 日本語フォントは helpers が `a:ea`（東アジアフォント）まで設定する。**メイリオ（Meiryo）固定**。Macのプレビューでは代替表示になり得るが，Google Slidesアップロード後は正しく当たる
- 影は消す（`shp.shadow.inherit = False`，helpers内で処理済み）

## ハマりどころ（過去の実例）

- `paras` 引数は**2重リスト**：`[[(text, size, bold, color)], [(...)]]`。1重で渡すと unpack エラー
- tmp/scratchpad はセッションを跨ぐと消えることがある → 生成スクリプトとソースHTMLは必ず残す／再生成可能にしておく
- ディスク容量不足で `prs.save()` が失敗することがある → 失敗時は代替パスに保存してユーザーに報告
- 元資料に日付・数値の古い記述がある場合：**黙って直さない**。忠実に変換した上で，確定事項との食い違いをユーザーに報告して指示を仰ぐ

## 別PCへの導入

このディレクトリ（`artifact-to-pptx/`）を丸ごと相手PCの `~/.claude/skills/`（全プロジェクト共通）または対象プロジェクトの `.claude/skills/`（プロジェクト限定）にコピーするだけ。
