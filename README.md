# project_hub

GitLab EE と Redmine を docker-compose で構築する環境。
GitLab のリポジトリ領域を Redmine から read-only マウントし、Redmine の UID を GitLab の `git` ユーザ（UID 998）に揃えてあります。

---

## ディレクトリ構成

```
project_hub/
├── docker-compose.yml     # gitlab + redmine 定義
├── .env                   # イメージタグ・ポート・UID/GID
├── setup.sh               # ボリュームディレクトリ作成 + chown
├── image/
│   ├── load-images.sh     # ./image/*.tar を docker load
│   └── *.tar              # （ユーザが配置）GitLab / Redmine の tar
├── gitlab/
│   ├── config/            # /etc/gitlab
│   ├── logs/              # /var/log/gitlab
│   └── data/              # /var/opt/gitlab（リポジトリ含む）
└── redmine/
    ├── files/             # /usr/src/redmine/files
    ├── plugins/           # /usr/src/redmine/plugins
    ├── themes/            # /usr/src/redmine/themes
    ├── log/               # /usr/src/redmine/log
    └── sqlite/            # /usr/src/redmine/sqlite（DB ファイル）
```

---

## 前提

- Docker / Docker Compose v2 が利用可能
- ホスト側で 80 / 443 / 2222 / 3000 番ポートが空いている
- `image/` 配下に以下の tar を配置（`docker save` で作成したもの）
  - `gitlab-ee.tar`（タグ: `gitlab/gitlab-ee:latest`）
  - `redmine.tar`（タグ: `redmine:5`）

タグを変えたい場合は `.env` の `GITLAB_IMAGE` / `REDMINE_IMAGE` を書き換えてください。

tar の作成例（イメージ提供側）:

```bash
docker pull gitlab/gitlab-ee:latest
docker save gitlab/gitlab-ee:latest -o gitlab-ee.tar

docker pull redmine:5
docker save redmine:5 -o redmine.tar
```

---

## セットアップ

```bash
cd /mnt/c/Users/tiger/Desktop/project_hub

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
```

---

## 注意事項

- ホスト側の `./gitlab/data/git-data/repositories` のオーナーは UID 998（コンテナ内 `git`）になります。Redmine も同 UID で動くため読み取り可能。
- `setup.sh` は `redmine/` 配下を `998:998` に chown します。WSL 上で `/mnt/c` を使っている場合、`metadata` マウントオプションが有効でないと chown が効かないことがあります。その場合は `/etc/wsl.conf` で `[automount] options = "metadata"` を設定してください。
- DB は SQLite（`redmine/sqlite/redmine.db`）。MySQL/PostgreSQL に切り替える場合は `docker-compose.yml` に DB サービスを追加し、Redmine 側に `REDMINE_DB_*` 環境変数を渡してください。
