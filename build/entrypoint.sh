#!/bin/bash
set -e

# 初期化
SITE_DIR=/usr/src/app
THEME_DIR=/usr/src/theme
JEKYLL_DIR=/usr/src/jekyll
DEST_DIR=/usr/local/app
BUNDLE_DIR=/usr/local/bundle

if [ ! -e /home/jekyll/check_user ]; then
  # UID,GIDを取得
  USER_ID=$(id -u)
  GROUP_ID=$(id -g)

  # グループを作成する
  if [ x"$GROUP_ID" != x"0" ]; then
      groupadd -g $GROUP_ID $USER_NAME
  fi

  # ユーザを作成する
  if [ x"$USER_ID" != x"0" ]; then
      useradd -d /home/$USER_NAME -m -s /bin/bash -u $USER_ID -g $GROUP_ID $USER_NAME
  fi

  # パーミッションを元に戻す
  sudo chmod u-s /usr/sbin/useradd
  sudo chmod u-s /usr/sbin/groupadd

  # パーミッション変更
  sudo chown $USER_NAME:$USER_NAME $SITE_DIR
  sudo chown $USER_NAME:$USER_NAME $THEME_DIR
  sudo chown $USER_NAME:$USER_NAME $JEKYLL_DIR
  sudo chown $USER_NAME:$USER_NAME $DEST_DIR
  sudo chown $USER_NAME:$USER_NAME $BUNDLE_DIR

  touch /home/jekyll/check_user
fi

exec $@

# 設定値表示
echo "========================================"
echo "Site Files Dir    : ${SITE_DIR}"
echo "Site Repo's URL   : ${SITE_REPOSITORY}"
echo "Site Repo's Branch: ${SITE_BRANCH}"
echo "Theme Fils Dir    : ${THEME_DIR}"
echo "Theme Repo's URL  : ${THEME_REPOSITORY}"
echo "Theme Repo's Tag  : ${THEME_TAG}"
echo "Output Dir        : ${DEST_DIR}"
echo "Jekyll Dir        : ${JEKYLL_DIR}"
echo "Jekyll Mode       : ${JEKYLL_MODE}"
echo "jekyll ARGS       : ${JEKYLL_ARGS}"
echo "jekyll NEW BLANK  : ${JEKYLL_NEW_BLANK}"
echo "Bundler Dir       : ${BUNDLE_DIR}"
echo "========================================"

# Theme Repository Clone
echo "テーマのダウンロード処理を開始します。"
# cd ${THEME_DIR}
if [ -n "$THEME_REPOSITORY" ]; then
  # ${THEME_REPOSITORY}が空でない場合
  : ${THEME_TAG:="HEAD"}
  if [ ${THEME_TAG} = "latest" ]; then
    # 最後のタグを取得
    LATEST_TAG=`git ls-remote --tags -q  ${THEME_REPOSITORY} | tail -1 | awk '{print $2}' | sed -e "s/refs\/tags\///" -e "s/\^{}//"`
    git clone ${THEME_REPOSITORY} ${THEME_DIR} -b ${LATEST_TAG} --depth 1
  elif [ ${THEME_TAG} = "HEAD" ]; then
    # HEADを取得
    git clone ${THEME_REPOSITORY} ${THEME_DIR} --depth 1
  else
    # 指定バージョンを取得
    git ls-remote --tags -q ${THEME_REPOSITORY} | awk '{print $2}'| sed -e "s/refs\/tags\///" | grep -x ${THEME_TAG}
    if [ $? -eq 0 ]; then
      git clone ${THEME_REPOSITORY} ${THEME_DIR} -b ${THEME_TAG} --depth 1
    else
      echo "THEME_TAGと一致するタグが存在しません。"
      exit 1
    fi
  fi
else
  echo "環境変数:THEME_REPOSITORYが空です。処理を中断します。"
  exit 1
fi


# Copy theme to Jekyll Dir
cd ${JEKYLL_DIR}
cp -r ${THEME_DIR}/* ${JEKYLL_DIR}
rm -rf ${JEKYLL_DIR}/_posts/
rm -rf ${JEKYLL_DIR}/.git/


# Site Repository Clone
if [ -n ${SITE_REPOSITORY} ]; then
  if [ -n "${SITE_BRANCH}" ]; then
    git ls-remote --heads ${SITE_REPOSITORY} | awk '{print $2}' | sed -e "s/refs\/heads\///" | grep -x ${SITE_BRANCH}
    if [ $? -eq 0 ]; then
      git clone ${SITE_REPOSITORY} ${SITE_DIR} -b ${SITE_BRANCH} --depth 1
    else
      echo "SITE_BRANCHが存在しません。"
      exit 1
    fi
  else
    # Branchが指定されていない場合、メインブランチを使う
    git clone ${SITE_REPOSITORY} ${SITE_DIR} --depth 1
  fi
else
  echo "SITE_REPOSITORYが指定されていません。"
  exit 1
fi

# Copy Src Dir to Jekyll Dir
\cp -r ${SITE_DIR}/. ${JEKYLL_DIR}/

cd $JEKYLL_DIR

# bundler settings
bundle config set --local path $BUNDLE_DIR

# Gemfileにwebrickがない場合追加
echo "GemfileにWebrickが記述されていない場合、追加します。"
cd ${JEKYLL_DIR}
grep -q "webrick" "${JEKYLL_DIR}/Gemfile"
if [ $? -eq 0 ]; then
  echo "webrickはすでに入っています。"
elif [ $? -eq 1 ]; then
  echo $PWD
  echo "webrickを追加しました。"
  bundle add webrick
else
  echo "エラーが発生しました。 Exit Code: ${?}"
  exit 1
fi

# bundle
echo "Bundle installをします"
/usr/local/bundle/bin/bundle install --path ${BUNDLE_DIR}

echo "========================================"

# Jekyll 起動
if   [ ${JEKYLL_MODE} = "serve"     ]; then
  /usr/local/bundle/bin/bundle exec jekyll serve     ${JEKYLL_ARGS} -s ${JEKYLL_DIR} -d ${DEST_DIR} --host=0.0.0.0
elif [ ${JEKYLL_MODE} = "build"     ]; then
  /usr/local/bundle/bin/bundle exec jekyll build     ${JEKYLL_ARGS} -s ${JEKYLL_DIR} -d ${DEST_DIR}
elif [ ${JEKYLL_MODE} = "doctor"    ]; then
  /usr/local/bundle/bin/bundle exec jekyll doctor    ${JEKYLL_ARGS} -s ${JEKYLL_DIR} -d ${DEST_DIR}
elif [ ${JEKYLL_MODE} = "clean"     ]; then
  /usr/local/bundle/bin/bundle exec jekyll clean     ${JEKYLL_ARGS} -s ${JEKYLL_DIR} -d ${DEST_DIR}
elif [ ${JEKYLL_MODE} = "new-theme" ]; then
  /usr/local/bundle/bin/bundle exec jekyll new-theme ${JEKYLL_ARGS} -s ${JEKYLL_DIR} -d ${DEST_DIR}
else
  # それ以外はエラーを返す
  echo "モードが不適切です。使用可能なモードは(serve|build|doctor|clean|new-theme)です。"
  exit 1
fi
