# Core Keeper Dedicated Server (Modded)

Core Keeper の Dedicated Server を Docker コンテナで手軽に構築・運用するためのプロジェクトです。
BepInEx による Mod サポート、Discord 通知、Game ID の動的生成などの便利機能を搭載しています。

## 特徴

- **Mod 対応**: BepInEx を自動セットアップし、Mod 環境を簡単に構築可能
- **Discord 通知**: サーバーの起動・停止、Game ID、プレイヤーの参加・退出を Discord に通知
- **完全な永続化**: ワールドデータ、設定、Mod、ログをホスト側のディレクトリで管理
- **Game ID 管理**: 固定 ID の利用も、起動ごとの新規発行（再生成）も設定一つで切り替え可能
- **クロスプレイ対応**: Steam Datagram Relay (SDR) または Direct Connection のネットワークモードを選択可能

## クイックスタート

### 1. 環境変数の準備
`core.env.example` をコピーして `core.env` を作成します。

```bash
cp core.env.example core.env
```

`core.env` を開き、必要な設定（PUID/PGIDやDiscord Webhookなど）を編集してください。

### 2. サーバー起動

```bash
docker compose up -d --build
```

### 3. ログ確認

```bash
docker compose logs -f
```

## ディレクトリ構成と永続化

ホスト側の `./server-data` ディレクトリに全てのデータが保存されます。

- `./server-data/`
  - `worlds/`, `ServerConfig.json`, `prefs.json`: ワールドデータとサーバー設定
  - `bepinex/`: Mod 関連データ
    - `plugins/`: Mod (.dll) はここに配置します
    - `config/`: 各 Mod の設定ファイル
    - `patchers/`: Patcher 系 Mod
    - `LogOutput.log`: BepInEx のログファイル

## Mod の導入方法 (BepInEx)

1. `core.env` で `BEPINEX_ENABLED=true` に設定します。
2. サーバーを起動 (`docker compose up -d`) すると、自動的に BepInEx がダウンロード・インストールされます。
3. `./server-data/bepinex/plugins/` に導入したい Mod の `.dll` ファイルを配置します。
4. サーバーを再起動 (`docker compose restart`) して Mod を読み込ませます。

## 機能詳細

### Discord 通知 & プレイヤー監視
`core.env` に `DISCORD_WEBHOOK_URL` を設定すると、以下の通知が送信されます。

- **起動ステータス**: 起動開始(🚀) / 停止(🛑)
- **接続情報**: 準備完了時の Game ID (✅)
- **プレイヤー入退室**: 参加(👋 [Name] joined) / 退出(👋 [Name] left)

### Game ID の動的再生成
通常、Dedicated Server は `ServerConfig.json` に Game ID を保存し続けます。
サーバー再起動のたびに新しい Game ID を発行したい場合は、以下を設定してください。

```bash
DISCARD_GAME_ID=true
```

起動ごとに `ServerConfig.json` と `GameID.txt` を削除し、新規 ID の生成を強制します。

### ネットワークモード設定
- **SDR (デフォルト)**: ポート開放不要。Game ID で接続します。
  - `SERVER_PORT=` (空欄)
- **Direct Connection**: IP/Port指定で接続する場合。UDPポート開放が必要です。
  - `SERVER_PORT=27015` (例)
  - `compose.yml` の `ports` 設定のコメントアウトを外してください。

## トラブルシューティング

- **BepInEx が動作しない**: ログ (`docker compose logs`) を確認し、`Doorstop` や `BepInEx` のロードエラーが出ていないか確認してください。
- **通知が来ない**: Webhook URL が正しいか、curl がコンテナ内で実行できているか確認してください。

## バックアップとリストア

## バックアップとリストア

このプロジェクトには、環境設定(`core.env`)とサーバーデータ(`server-data/`)を簡単にバックアップ・リストアするためのユーティリティが含まれています。

### バックアップ作成

`scripts/backup.sh` を実行すると、`backups/` ディレクトリ（デフォルト）にアーカイブが作成されます。

```bash
./scripts/backup.sh [出力ディレクトリ]
# 例: ./scripts/backup.sh
# -> backups/backup_corekeeper_YYYYMMDD_HHMMSS.tar.gz が作成されます
```

### リストア実行

`scripts/restore.sh` を使用して、バックアップからデータを復元します。
**注意**: `core.env` が含まれるバックアップの場合、現在の設定ファイルを上書きするか確認を求められます。

```bash
# 1. 安全のためサーバーを停止
docker compose stop

# 2. リストア実行 (作成されたtar.gzファイルを指定)
./scripts/restore.sh backups/backup_corekeeper_YYYYMMDD_HHMMSS.tar.gz

# 3. サーバー起動
### 定期バックアップ (Crontab)

`cron` を使用してバックアップを定期実行することができます。
以下は毎日午前4時にバックアップを実行する例です。

1. crontab 編集モードを開く:
   ```bash
   crontab -e
   ```

2. 以下の行を追加（パスは環境に合わせて変更してください）:
   ```cron
   0 4 * * * /home/your_user/corekeeper-modded/scripts/backup.sh /home/your_user/corekeeper-modded/backups >> /home/your_user/corekeeper-modded/logs/backup.log 2>&1
   ```
