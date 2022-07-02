FROM ruby:3.1.2-bullseye

# パッケージ関連
RUN echo "リポジトリをrikenに変更します。" \
&&  echo "deb http://ftp.riken.jp/pub/Linux/debian/debian bullseye main contrib non-free" > /etc/apt/sources.list \
&&  echo "deb http://security.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list \
&&  apt update \
&&  apt upgrade -y \
&&  apt install -y \
      build-essential \
      git \
&&  echo "update完了しました。"

# Jekyllに必要なGemをインストール
RUN  gem update \
&&  gem install jekyll bundler

# entrypoint.shと作業に必要なディレクトリを作成
ADD entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
&&  mkdir /usr/src/{app,theme,jekyll} /usr/local/{app,bundle} -p

WORKDIR /usr/src/jekyll

ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
EXPOSE 4000