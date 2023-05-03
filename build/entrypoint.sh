#!/bin/bash
set -e # Error Stopper
#set -x # debug

# function

## Ruled Line
function hr () {
  printf '%.0s=' {1..40}
  echo ""
}

function item () {
  local subject=$1
  local value=$2
  printf '%-19s' "${subject}" ": ${value}"
  echo ""
}

# Initialize
SITE_DIR=/usr/src/app
THEME_DIR=/usr/src/theme
JEKYLL_DIR=/usr/src/jekyll
DEST_DIR=/usr/local/app
BUNDLE_DIR=/usr/local/bundle
: "${JEKYLL_MODE:="build"}"
: "${THEME_TAG:="HEAD"}"

# Set Bundle Install Path
bundle config set --local path $BUNDLE_DIR

# Check environment variables
hr
echo "Starting Environment variables Check..."
[ -z "${SITE_REPOSITORY}" ]  && echo >&2 "Undefined variable: SITE_REPOSITORY"  && exit 1
[ -z "${THEME_REPOSITORY}" ] && echo >&2 "Undefined variable: THEME_REPOSITORY" && exit 1
echo "Variables Check: Passed."

# Show Settings
hr
item "Site Files Dir" "${SITE_DIR}"
item "Site Repo's URL" "${SITE_REPOSITORY}"
item "Site Repo's Branch" "${SITE_BRANCH}"
item "Theme Fils Dir" "${THEME_DIR}"
item "Theme Repo's URL" "${THEME_REPOSITORY}"
item "Theme Repo's Tag" "${THEME_TAG}"
item "Output Dir" "${DEST_DIR}"
item "Jekyll Dir" "${JEKYLL_DIR}"
item "Jekyll Mode" "${JEKYLL_MODE}"
item "jekyll ARGS" "${JEKYLL_ARGS}"
item "jekyll NEW BLANK" "${JEKYLL_NEW_BLANK}"
item "Bundler Dir" "${BUNDLE_DIR}"
hr

# Main Loop
while : ; do

  # Check Theme Repo's Info
  echo "Check Theme Reposiroty..."
  case ${THEME_TAG} in
    "HEAD")
      THEME_GIT_OPTIONS=""
      echo "Using latest commit of Theme Reposiotry.";;
    "latest")
      LATEST_TAG=$(git ls-remote --tags -q  "${THEME_REPOSITORY}" | tail -1 | awk '{print $2}' | sed -e "s/refs\/tags\///" -e "s/\^{}//")
      THEME_GIT_OPTIONS="-b ${LATEST_TAG}"
      echo "Using ${LATEST_TAG}.";;
    *)
      git ls-remote --tags -q "${THEME_REPOSITORY}" | awk '{print $2}'| sed -e "s/refs\/tags\///" | grep -x ${THEME_TAG}
      if [ $? -eq 0 ]; then
        THEME_GIT_OPTIONS="-b ${THEME_TAG}"
        echo "Using ${THEME_TAG}."
      else
        echo >&2 "There is no matching tag for ${THEME_TAG}."
        exit 1
      fi
  esac

  # Clone Theme Repository
  echo "Starting Theme Downloads..."
  if [ "$(git -C ${THEME_DIR} rev-parse HEAD)" = $(git ls-remote ${THEME_REPOSITORY} ${THEME_GIT_OPTIONS} | tail -1 | awk '{print $1}') ]; then
    echo "Local has the same commit ID as remote."
    echo "Skipped the theme download."
  else
    echo "Local has a different commit ID than remote."
    rm -rf ${THEME_DIR}/* ${THEME_DIR}/.[!.]*
    git clone ${THEME_REPOSITORY} ${THEME_DIR} ${THEME_GIT_OPTIONS} --depth 1
    echo "Done."
  fi

  # Copy theme to Jekyll Dir
  \cp -r ${THEME_DIR}/* ${JEKYLL_DIR}
  rm -rf ${JEKYLL_DIR}/_posts/ ${JEKYLL_DIR}/.git/

  # Check Site Repo's Info
  echo "Check Site Repository..."
  if [ -n "${SITE_BRANCH}" ]; then
    git ls-remote --heads -q ${SITE_REPOSITORY} ${SITE_BRANCH} | awk '{print $2}' | sed -e 's/refs\/heads\///' | grep -x ${SITE_BRANCH}
    if [ $? -eq 0 ]; then
      SITE_GIT_OPTIONS="-b ${SITE_BRANCH}"
      echo "Using ${SITE_BRANCH}"
    else
      echo >&2 "There is no matching branch for ${SITE_BRANCH}."
      exit 1
    fi
  else
    echo "The environment variable SITE_BRANCH is undefined. Use the main branch."
    SITE_GIT_OPTIONS=""
  fi

  # Clone Site Repository
  echo "Starting Site Downloads..."
  if [ "$(git -C ${SITE_DIR} rev-parse HEAD)" = $(git ls-remote ${SITE_REPOSITORY} ${SITE_GIT_OPTIONS} | tail -1 | awk '{print $1}') ]; then
    echo "Local has the same commit ID as remote."
    echo "Skipped the theme download."
  else
    echo "Local has a different commit ID than remote."
    rm -rf ${SITE_DIR}/* ${SITE_DIR}/.[!.]*
    git clone ${SITE_REPOSITORY} ${SITE_DIR} ${SITE_GIT_OPTIONS} --depth 1
    echo "Done."
  fi

  # Copy Src Dir to Jekyll Dir
  \cp -r ${SITE_DIR}/. ${JEKYLL_DIR}/

  cd $JEKYLL_DIR

  # Bundle
  hr

  # If Jekyll's mode is "serve", install webrick.
  [ ${JEKYLL_MODE} = "serve" ] && $(grep -q "webrick" ./Gemfile || bundle add webrick) && \
  echo "Added webrick to Gemfile."

  # Bundle Install
  echo "Starting Bundle Install..."
  bundle install
  echo "Done!"

  # Run Jekyll
  hr
  bundle exec jekyll ${JEKYLL_MODE} ${JEKYLL_ARGS} -s ${JEKYLL_DIR} -d ${DEST_DIR} `[ ${JEKYLL_MODE} = "serve" ] && echo "--host=0.0.0.0"`

  # Update check
  hr
  echo "Check Repository Update..."
  while [ $([ ${THEME_TAG} = "latest" ] && git ls-remote --tags -q ${THEME_REPOSITORY} | tail -1 | awk '{print $1}' || git ls-remote ${THEME_REPOSITORY} | grep "`[ ${THEME_TAG} = "HEAD" ] && echo "HEAD" || echo "refs/tags/${THEME_TAG}"`" | awk '{print $1}') = $(git -C ${THEME_DIR} rev-parse HEAD) ] && \
        [ $(git ls-remote ${SITE_REPOSITORY}  | grep "`git -C ${SITE_DIR}  branch --contains | awk '{print$2}'`" | awk '{print$1}') = $(git -C ${SITE_DIR} rev-parse HEAD) ]; do sleep 60 ; done
  echo "Update Found!"
  echo "Start Updating..."
done
