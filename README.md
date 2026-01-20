# corekeeper-modded

Core Keeper の Dedicated Server を Linux コンテナで動かすための最小構成（まずはバニラ起動）。

- SteamCMD で Dedicated Server を取得/更新して起動します
- 永続化は `./server-data`（ワールド/設定・BepInExの設定/プラグイン）
- Mod は後段で BepInEx を載せる想定（この段階では未対応）

## 使い方

1) env を用意（任意）

```bash
cp core.env.example core.env
```

2) 起動

```bash
docker compose -f compose.yml up -d --build
```

3) ログ確認

```bash
docker compose -f compose.yml logs -f
```

## ネットワークモード

- **SDR (Steam Datagram Relay)**: `SERVER_PORT` を空にする（デフォルト）。基本はポート開放不要。
- **Direct Connection**: `SERVER_PORT` を設定し、必要に応じて `PASSWORD` も設定。
	- `compose.yml` の `ports:` を有効化し、UDPポートを公開してください。

## データの場所

- サーバー本体: `/home/steam/core-keeper-dedicated`（コンテナ内の一時領域。ホストへは保持しない）
- セーブ/設定: `/home/steam/core-keeper-data`（ホスト側 `./server-data`）
- BepInEx 永続化: `./server-data/bepinex/`（`plugins/`, `config/`, `patchers/`, `LogOutput.log`）

## 参考

- https://github.com/escapingnetwork/core-keeper-dedicated （appidや起動方法の参考）

## BepInEx（導入中）

このリポジトリでは、公式ドキュメントの Linux/macOS 手順（`nix` アーカイブ + Doorstop）に寄せて導入します。
（Dedicated Server の起動引数を渡す都合上、実行は `run_bepinex.sh` ではなく Doorstop 環境変数 + `LD_PRELOAD` を設定して直接 `CoreKeeperServer` を起動します）

- 公式: https://docs.bepinex.dev/articles/user_guide/installation/index.html

使い方（最小）:

1) `core.env` に以下を設定して起動
	- `BEPINEX_ENABLED=true`
	- `BEPINEX_RELEASE=5.4.21`（または `BEPINEX_ZIP_URL` を指定）

初回起動後、`./server-data/bepinex/` 配下に設定とログが生成されます。