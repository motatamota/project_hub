# project_hub

GitLab EE と Redmine を docker-compose で構築する環境。
GitLab のリポジトリ領域を Redmine から read-only マウントし、Redmine の UID を GitLab の `git` ユーザ（UID 998）に揃えてあります。
Redmine の DB は PostgreSQL（独立コンテナ）を使用します。

---

## ディレクトリ構成

```
project_hub/
├── docker-compose.yml     # gitlab + redmine + postgres 定義
├── .env                   # イメージタグ・ポート・DB認証情報・UID/GID
├── setup.sh               # ボリュームディレクトリ作成 + chown
├── image/
│   ├── load-images.sh     # ./image/*.tar を docker load
│   └── *.tar              # （ユーザが配置）GitLab / Redmine / Postgres の tar
├── gitlab/
│   ├── config/            # /etc/gitlab
│   ├── logs/              # /var/log/gitlab
│   └── data/              # /var/opt/gitlab（リポジトリ含む）
└── redmine/
    ├── files/             # /usr/src/redmine/files
    ├── plugins/           # /usr/src/redmine/plugins
    ├── themes/            # /usr/src/redmine/themes
    ├── log/               # /usr/src/redmine/log
    └── postgres/          # /var/lib/postgresql/data（PostgreSQL データ実体）
```

---

## 前提

- Docker / Docker Compose v2 が利用可能
- ホスト側で 80 / 443 / 2222 / 3000 番ポートが空いている
- `image/` 配下に以下の tar を配置（`docker save` で作成したもの）
  - `gitlab-ee.tar`（タグ: `gitlab/gitlab-ee:latest`）
  - `redmine.tar`（タグ: `redmine:5`）
  - `postgres.tar`（タグ: `postgres:16-alpine`）

タグを変えたい場合は `.env` の `GITLAB_IMAGE` / `REDMINE_IMAGE` / `POSTGRES_IMAGE` を書き換えてください。

tar の作成例（イメージ提供側）。プロジェクトルートで実行:

```bash
cd image/

docker pull gitlab/gitlab-ee:latest
docker save gitlab/gitlab-ee:latest -o gitlab-ee.tar

docker pull redmine:5
docker save redmine:5 -o redmine.tar

docker pull postgres:16-alpine
docker save postgres:16-alpine -o postgres.tar
```

---

## セットアップ

プロジェクトルート（このREADMEがあるディレクトリ）で実行:

```bash
# 1. tar からイメージをロード
./image/load-images.sh

# 2. ボリュームディレクトリ作成 & 所有権を UID/GID=998 に揃える（sudo 必要）
./setup.sh

# 3. 起動
docker compose up -d
```

GitLab の初回起動は 3〜5 分かかります。`docker compose logs -f gitlab` で `gitlab Reconfigured!` が出るまで待ってください。

---

## アクセス

| サービス | URL                       | 初期ログイン                                |
| -------- | ------------------------- | ------------------------------------------- |
| GitLab   | http://localhost/         | `root` / `gitlab/config/initial_root_password` 参照 |
| GitLab SSH | `ssh://git@localhost:2222` |                                            |
| Redmine  | http://localhost:3000/    | `admin` / `admin`（初回ログイン時に変更）   |

GitLab 初期 root パスワードの確認:

```bash
docker compose exec gitlab cat /etc/gitlab/initial_root_password
```

---

## .env

| キー               | 既定値                       | 説明                                     |
| ------------------ | ---------------------------- | ---------------------------------------- |
| `GITLAB_IMAGE`     | `gitlab/gitlab-ee:latest`    | tar をロードした後の GitLab イメージタグ |
| `REDMINE_IMAGE`    | `redmine:5`                  | tar をロードした後の Redmine イメージタグ |
| `GITLAB_HOSTNAME`  | `gitlab.local`               | external_url ホスト名                    |
| `GITLAB_HTTP_PORT` | `80`                         | GitLab HTTP ポート                       |
| `GITLAB_HTTPS_PORT`| `443`                        | GitLab HTTPS ポート                      |
| `GITLAB_SSH_PORT`  | `2222`                       | GitLab SSH ポート                        |
| `REDMINE_PORT`     | `3000`                       | Redmine HTTP ポート                      |
| `POSTGRES_IMAGE`   | `postgres:16-alpine`         | tar をロードした後の PostgreSQL イメージタグ |
| `POSTGRES_DB`      | `redmine`                    | Redmine 用 DB 名                         |
| `POSTGRES_USER`    | `redmine`                    | Redmine 用 DB ユーザ                     |
| `POSTGRES_PASSWORD`| `change_me_in_production`    | Redmine 用 DB パスワード（**本番では必ず変更**） |
| `GIT_UID`          | `998`                        | GitLab Omnibus の git ユーザ UID         |
| `GIT_GID`          | `998`                        | GitLab Omnibus の git ユーザ GID         |

---

## Redmine から GitLab リポジトリを参照する

`./gitlab/data/git-data/repositories` を Redmine コンテナ内 `/var/redmine/repositories` に **read-only** マウントしています。

1. Redmine にログインしプロジェクト > 設定 > リポジトリ
2. **リポジトリ管理** = `Git`
3. **リポジトリのパス** = `/var/redmine/repositories/<group>/<project>.git`
   - GitLab が hashed storage を使う場合（既定）はパスが `@hashed/xx/yy/<hash>.git` 形式になります。`<group>/<project>` の対応は GitLab 管理画面または `gitlab-rails console` で確認可能です。

UID が揃っているのでパーミッションエラーは出ない想定です。

---

## 運用コマンド

```bash
# 状態確認
docker compose ps

# ログ
docker compose logs -f gitlab
docker compose logs -f redmine

# 停止
docker compose down

# 完全停止（ボリュームは ./gitlab, ./redmine に残る）
docker compose down

# データを消したい時はホストの ./gitlab, ./redmine ディレクトリを手動削除
#   PostgreSQL のデータも ./redmine/postgres に保存されているので一緒に消える
```

---

## DB バックアップ / リストア

```bash
# バックアップ（コンテナ起動中）
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
  | gzip > redmine_$(date +%Y%m%d_%H%M%S).sql.gz

# リストア
gunzip -c redmine_YYYYMMDD_HHMMSS.sql.gz \
  | docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

---

## 注意事項

- ホスト側の `./gitlab/data/git-data/repositories` のオーナーは UID 998（コンテナ内 `git`）になります。Redmine も同 UID で動くため読み取り可能。
- `setup.sh` は `redmine/` 配下を `998:998` に chown します。WSL 上で `/mnt/c` を使っている場合、`metadata` マウントオプションが有効でないと chown が効かないことがあります。その場合は `/etc/wsl.conf` で `[automount] options = "metadata"` を設定してください。
- Redmine の DB は PostgreSQL（独立コンテナ `redmine_postgres`）。データは `./redmine/postgres/` にbindマウントで保存されます。所有権は `setup.sh` が UID/GID=70（postgresユーザ）に揃えます。`POSTGRES_PASSWORD` は `.env` で必ず変更してください。
- 旧 `redmine/sqlite/` ディレクトリが残っている場合、PostgreSQL 切替後は不要です。手動で削除可。
