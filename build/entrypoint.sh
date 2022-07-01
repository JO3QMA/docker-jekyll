#!/bin/bash
set -e # Error Stopper
set -x # debug

# Initialize
SITE_DIR=/usr/src/app
THEME_DIR=/usr/src/theme
JEKYLL_DIR=/usr/src/jekyll
DEST_DIR=/usr/local/app
BUNDLE_DIR=/usr/local/bundle
: ${JEKYLL_MODE:="build"}
: ${THEME_TAG:="HEAD"}

# Set Bundle Install Path
bundle config set --local path $BUNDLE_DIR

# Check environment variables
echo "========================================"
echo "Starting Environment variables Check..."
[ -z "${SITE_REPOSITORY}" ]  && echo "Undefined variable: SITE_REPOSITORY"  && exit 1
[ -z "${THEME_REPOSITORY}" ] && echo "Undefined variable: THEME_REPOSITORY" && exit 1
echo "Variables Check: Passed."

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

  # Check Theme Repo's Info
  echo "Check Theme Reposiroty..."
  case ${THEME_TAG} in
    "HEAD")
      THEME_GIT_OPTIONS=""
      echo "Using latest commit of Theme Reposiotry.";;
    "latest")
      LATEST_TAG=`git ls-remote --tags -q  ${THEME_REPOSITORY} | tail -1 | awk '{print $2}' | sed -e "s/refs\/tags\///" -e "s/\^{}//"`
      THEME_GIT_OPTIONS="-b ${LATEST_TAG}"
      echo "Using ${LATEST_TAG}.";;
    *)
      git ls-remote --tags -q ${THEME_REPOSITORY} | awk '{print $2}'| sed -e "s/refs\/tags\///" | grep -x ${THEME_TAG}
      if [ $? -eq 0 ]; then
        THEME_GIT_OPTIONS="-b ${THEME_TAG}"
        echo "Using ${THEME_TAG}."
      else
        echo "There is no matching tag for ${THEME_TAG}."
        exit 1
      fi
  esac

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


  # Clone Site Repository  
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

  # Bundle
  echo "========================================"

  # If Jekyll's mode is "serve", install webrick.
  [ ${JEKYLL_MODE} = "serve" ] && grep -q "webrick" ./Gemfile || bundle add webrick && \
  echo "Added webrick to Gemfile."

  # Bundle Install
  echo "Starting Bundle Install..."
  bundle install
  echo "Done!"

  # Run Jekyll
  echo "========================================"
  bundle exec jekyll ${JEKYLL_MODE} ${JEKYLL_ARGS} -s ${JEKYLL_DIR} -d ${DEST_DIR} `[ ${JEKYLL_MODE} = "serve" ] && echo "--host=0.0.0.0"`

  # Update check
  echo "========================================"
  echo "Check Repository Update..."
  while [ $([ ${THEME_TAG} = "latest" ] && git ls-remote --tags -q ${THEME_REPOSITORY} | tail -1 | awk '{print $1}' || git ls-remote ${THEME_REPOSITORY} | grep "`[ ${THEME_TAG} = "HEAD" ] && echo "HEAD" || echo "refs/tags/${THEME_TAG}"`" | awk '{print $1}') = $(git -C ${THEME_DIR} rev-parse HEAD) ] && \
        [ $(git ls-remote ${SITE_REPOSITORY}  | grep "`git -C ${SITE_DIR}  branch --contains | awk '{print$2}'`" | awk '{print$1}') = $(git -C ${SITE_DIR} rev-parse HEAD) ]; do sleep 60 ; done
  echo "Update Found!"
  echo "Start Updating..."
done
