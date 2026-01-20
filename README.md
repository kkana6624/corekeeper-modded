# corekeeper-modded

Core Keeper の Dedicated Server を Linux コンテナで動かすための最小構成（まずはバニラ起動）。

- SteamCMD で Dedicated Server を取得/更新して起動します
- 永続化は `./server-data`（ワールド/設定）と、任意で `./server-files`（サーバー本体）
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

- サーバー本体: `/home/steam/core-keeper-dedicated`（ホスト側 `./server-files`）
- セーブ/設定: `/home/steam/core-keeper-data`（ホスト側 `./server-data`）

## 参考

- https://github.com/escapingnetwork/core-keeper-dedicated （appidや起動方法の参考）