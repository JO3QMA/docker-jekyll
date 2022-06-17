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
      sudo \
&&  echo "update完了しました。"

# 実行ユーザーを作成
ENV USER_NAME=jekyll
RUN echo "実行ユーザーを作成します。" \
&&  echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${USER_NAME} \
&&  chmod u+s /usr/sbin/useradd \
&&  chmod u+s /usr/sbin/groupadd

# Jekyllに必要なGemをインストール
RUN  gem update \
&&  gem install jekyll bundler

# entrypoint.shと作業に必要なディレクトリを作成
ADD entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
&&  mkdir /usr/src/app -p \
&&  mkdir /usr/src/theme -p \
&&  mkdir /usr/src/jekyll -p \
&&  mkdir /usr/local/app -p \
&&  mkdir /usr/local/bundle -p

WORKDIR /usr/src/jekyll

ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
EXPOSE 4000