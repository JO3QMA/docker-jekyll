#!/bin/bash

# UID,GIDを取得
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# 初期化
SRC_DIR=/usr/src/app
CHIRPY_DIR=/usr/src/chirpy
JEKYLL_DIR=/usr/src/jekyll
DEST_DIR=/usr/local/app

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
sudo chown $USER_NAME:$USER_NAME $SRC_DIR
sudo chown $USER_NAME:$USER_NAME $CHIRPY_DIR
sudo chown $USER_NAME:$USER_NAME $JEKYLL_DIR
sudo chown $USER_NAME:$USER_NAME $DEST_DIR

exec $@

# 設定値表示
echo "========================================"
echo "Source Dir      : ${SRC_DIR}"
echo "Target Dir      : ${DEST_DIR}"
echo "Jekyll Mode     : ${JEKYLL_MODE}"
echo "jekyll ARGS     : ${JEKYLL_ARGS}"
echo "jekyll NEW BLANK: ${JEKYLL_NEW_BLANK}"
echo "========================================"

# git clone
cd ${CHIRPY_DIR}
CHIRPY_REMOTE="https://github.com/cotes2020/jekyll-theme-chirpy"
LATEST_TAG=`git ls-remote --tags -q  ${CHIRPY_REMOTE} | tail -1 | awk '{print $2}' | sed -e "s/refs\/tags\///"`
git clone ${CHIRPY_REMOTE} ./ -b ${LATEST_TAG} > /dev/null 2>&1

# Copy chirpy to Jekyll Dir
cd ${JEKYLL_DIR}
cp -r ${CHIRPY_DIR}/* ${JEKYLL_DIR}
rm -rf ${JEKYLL_DIR}/_posts/
rm -rf ${JEKYLL_DIR}/.git/

# Copy Src Dir to Jekyll Dir
\cp -r ${SRC_DIR}/* ${JEKYLL_DIR}/

cd $JEKYLL_DIR

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
  /usr/local/bundle/bin/bundle exec jekyll serve     ${JEKYLL_ARGS} -s ${JEKYLL_DIR} -d ${DEST_DIR} --host=0.0.0.0 --watch
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
  echo "newは/usr/src/appが空の場合、自動的に実行されます。"
  exit 1
fi
