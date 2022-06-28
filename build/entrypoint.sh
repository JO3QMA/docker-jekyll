#!/bin/bash
set -e # Error Stopper
set -x # debug

# Initialize
SITE_DIR=/usr/src/app
THEME_DIR=/usr/src/theme
JEKYLL_DIR=/usr/src/jekyll
DEST_DIR=/usr/local/app
BUNDLE_DIR=/usr/local/bundle

# ユーザーがJekyllではない場合 (Rootだと都合が悪い) # のか？
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

# Main Loop
while : ; do
  # Theme Repository Clone
  echo "テーマの処理を開始します。"
  # cd ${THEME_DIR}
  if [ -n "$THEME_REPOSITORY" ]; then
    # ${THEME_REPOSITORY}が空でない場合
    : ${THEME_TAG:="HEAD"}
    if [ ${THEME_TAG} = "latest" ]; then
      # 最後のタグを取得
      echo "一番最後のタグを取得します。"
      LATEST_TAG=`git ls-remote --tags -q  ${THEME_REPOSITORY} | tail -1 | awk '{print $2}' | sed -e "s/refs\/tags\///" -e "s/\^{}//"`
      THEME_GIT_OPTIONS="-b ${LATEST_TAG}"
      echo "Tag: ${LATEST_TAG}"
    elif [ ${THEME_TAG} = "HEAD" ]; then
      # HEADを取得
      echo "HEADを取得します。"
      THEME_GIT_OPTIONS=""
    else
      # 指定バージョンを取得
      git ls-remote --tags -q ${THEME_REPOSITORY} | awk '{print $2}'| sed -e "s/refs\/tags\///" | grep -x ${THEME_TAG}
      if [ $? -eq 0 ]; then
        THEME_GIT_OPTIONS="-b ${THEME_TAG}"
        echo "Tag: ${THEME_TAG} を取得します。"
      else
        echo "THEME_TAGと一致するタグが存在しません。"
        exit 1
      fi
    fi
  else
    echo "環境変数:THEME_REPOSITORYが空です。処理を中断します。"
    exit 1
  fi

  echo "テーマリポジトリのダウンロード処理を開始します。"
  git -C ${THEME_DIR} remote -v > /dev/null && :
  if [ $? -eq 0 ]; then
    # すでにGitリポジトリがある場合
    THEME_REMOTE=`git -C ${THEME_DIR}  remote -v | grep "origin" | grep "fetch" | awk '{print $2}'`
    echo "${THEME_REMOTE}"
    if [ ${THEME_REMOTE} = ${THEME_REPOSITORY} ];then
      rm -rf ${THEME_DIR}/* ${THEME_DIR}/.[!.]*
      git clone ${THEME_REPOSITORY} ${THEME_DIR} ${THEME_GIT_OPTIONS} --depth 1
    else
      echo "${THEME_DIR}に${THEME_REPOSITORY}以外のリポジトリが入っています。"
      exit 1
    fi
  elif [ $? -eq 1 ]; then
    # Gitリポジトリがない場合
    git clone ${THEME_REPOSITORY} ${THEME_DIR} ${THEME_GIT_OPTIONS} --depth 1
  else
    # その他
    echo "git remote -vが${?}で終了しました。"
    exit 1
  fi

  # Copy theme to Jekyll Dir
  \cp -r ${THEME_DIR}/* ${JEKYLL_DIR}
  rm -rf ${JEKYLL_DIR}/_posts/ ${JEKYLL_DIR}/.git/


  # Site Repository Clone
  if [ -n ${SITE_REPOSITORY} ]; then
    if [ -n "${SITE_BRANCH}" ]; then
      git ls-remote --heads ${SITE_REPOSITORY} | awk '{print $2}' | sed -e "s/refs\/heads\///" | grep -x ${SITE_BRANCH}
      if [ $? -eq 0 ]; then
        SITE_GIT_OPTIONS="-b ${SITE_BRANCH}"
      else
        echo "SITE_BRANCHが存在しません。"
        exit 1
      fi
    else
      # Branchが指定されていない場合、メインブランチを使う
      SITE_GIT_OPTIONS=""
    fi
  else
    echo "SITE_REPOSITORYが指定されていません。"
    exit 1
  fi

  git -C ${SITE_DIR} remote -v > /dev/null && :
  if [ $? -eq 0 ]; then
    # すでにGitリポジトリがある場合
    SITE_REMOTE=`git -C ${SITE_DIR}  remote -v | grep "origin" | grep "fetch" | awk '{print $2}'`
    echo "${SITE_REMOTE}"
    if [ ${SITE_REMOTE} = ${SITE_REPOSITORY} ];then
      rm -rf ${SITE_DIR}/* ${SITE_DIR}/.[!.]*
      git clone ${SITE_REPOSITORY} ${SITE_DIR} ${SITE_GIT_OPTIONS} --depth 1
    else
      echo "${SITE_DIR}に${SITE_REPOSITORY}以外のリポジトリが入っています。"
      exit 1
    fi
  elif [ $? -eq 1 ]; then
    # Gitリポジトリがない場合
    git clone ${SITE_REPOSITORY} ${SITE_DIR} ${SITE_GIT_OPTIONS} --depth 1
  else
    # その他
    echo "git remote -vが${?}で終了しました。"
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
  /usr/local/bundle/bin/bundle install

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

  # update check
  echo "========================================"
  echo "Check Repository Update..."
  while [ $(git ls-remote ${THEME_REPOSITORY} | grep "`[ ${THEME_TAG} = "latest" ] && $(git ls-remote --tags -q  ${THEME_REPOSITORY} | tail -1 | awk '{print $2}' | sed -e "s/refs\/tags\///" -e "s/\^{}//")git -C ${THEME_DIR} describe --tags 2>/dev/null || echo "HEAD" `" | awk '{print$1}') = $(git -C ${THEME_DIR} rev-parse HEAD) ] && \
        [ $(git ls-remote ${SITE_REPOSITORY}  | grep "`git -C ${SITE_DIR}  branch --contains | awk '{print$2}'`" | awk '{print$1}') = $(git -C ${SITE_DIR} rev-parse HEAD) ]; do sleep 60 ; done
  echo "Update Found!"
  echo "Start Updating..."
done

echo "########ここには来ないはず"
