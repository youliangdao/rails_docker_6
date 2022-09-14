FROM ruby:2.7.6
# nodejsとyarnはwebpackをインストールする際に必要
# まずyarnリポジトリを有効にしてyarnリポジトリをシステムのソフトウェアリポジトリに追加（そのままyarnをインストールしようとすると古いから）
# set -x：シェルスクリプトの一部分だけをデバッグする(https://atmarkit.itmedia.co.jp/flinux/rensai/linuxtips/787debugsspert.html)
# curl -sS：yarnリポジトリの公開鍵を取得
# gpg --dearmor ファイル:アーマー化を解除してバイナリ化する
# gpg -o：パイプで受け取った公開鍵ファイルをエクスポート
# echo以下：yarnリポジトリをシステムのソフトウェアリポジトリに追加
# stable mainは安定版です。

# 【apt-keyで鍵を登録しない理由】
# apt-keyは単一の/etc/apt/trusted.gpgにキーを追加するが、リスクの異なるキーを同一ファイル内で共存させるべきではないというセキュリティ上の懸念から廃止が決まったらしい
# apt-keyを使用しない方針で作成

RUN set -x && apt-get update && apt-get install -y curl && \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarn-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list > /dev/null && \
  apt-get update && apt-get install -y yarn
RUN apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs
WORKDIR /myapp
COPY Gemfile Gemfile.lock /myapp/
RUN bundle install

# チーム開発でDocker環境を共有することを考えた場合に必要となってくる記述
# リモートリポジトリからアプリケーションファイルをcloneしてきたらdocker-compose upをするだけで環境が立ち上がるのが理想
# それにできるだけ近づけていく
# まずはnode_modulesは通常共有せず、package.jsonで共有するのでyarn installを強制的に実行
# rakeタスクでwebpackerによりbundleする
RUN yarn install --check-files
RUN bundle exec rails webpacker:compile

# コンテナ起動時に実行させるスクリプトを追加
# アクセス権限を実行可能にしておく
# EXPOSEはドキュメント代わり。コンテナ実行時に、指定したポートをコンテナがリッスンするようになる
# EXPOSEだけでは、ポートは公開されず、使用者からコンテナにはアクセスできません。
# 公開用のポートとEXPOSEで指定したポートをPublishにすることで、公開されるようになります。
# そのため、EXPOSEはイメージの作者とコンテナ実行者の両者に対して、ドキュメントのような役割をする。
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000

# Rails サーバ起動
# entrypoint.shでexec "$@"としているためCMDで渡されるオプションが実行されることになる
# docker-compose upはDBコンテナとまとめて起動する用の初期commandが書かれている
# このCMDはrailsサーバーを「単独」で立ち上げて作業したい場合に用いる
CMD ["rails", "server", "-b", "0.0.0.0"]
