#!/bin/bash

# chmod u+x go

function usage()
{
  echo "Usage:"
  echo "    go                    Display this help message"
  echo "    go up                 Run the app using the procfile"
  echo "    go spec               Run the specs"
  echo "    go install            Install dependencies and create the database and migrate"
  echo "    go init               (Re)name app"
}

function up {
  ./bin/dev
}

function spec {
  bundle exec rspec
}

function install_deps {
  bundle install
  yarn install
}

function setup_db {
  bundle exec rails db:create
  migrate
}

function migrate {
  bundle exec rails db:migrate
  RACK_ENV=test bundle exec rails db:migrate
}

function init {
  APP_NAME="${1}"
  MODULE_NAME="${2}"

  FIND_APP_NAME="LiteRails"
  FIND_MODULE_NAME="lite_rails"
  FIND_FRAMEWORK="rails"

  if [ -z "${APP_NAME}" ] || [ -z "${MODULE_NAME}" ]; then
      echo "You must supply both an app and module name, example: ${0} myapp MyApp"
      exit 1
  fi

  if [ "${APP_NAME}" = "${FIND_APP_NAME}" ]; then
      echo "Your new app name must be different than the current app name"
      exit 1
  fi

  # -----------------------------------------------------------------------------
  # The core of the script which renames a few things.
  # -----------------------------------------------------------------------------
  find . -type f -exec \
    perl -i \
      -pe "s/(${FIND_APP_NAME}${FIND_FRAMEWORK}|${FIND_APP_NAME})/${APP_NAME}/g;" \
      -pe "s/${FIND_MODULE_NAME}/${MODULE_NAME}/g;" {} +
  # -----------------------------------------------------------------------------

  while true; do
    read -p "Do you want to init a new local git repo (y/n)? " -r yn
    case "${yn}" in
        [Yy]* ) init_git_repo; break;;
        [Nn]* ) break;;
        * ) echo "";;
    esac
  done
}

function init_git_repo {
  [ -d .git/ ] && rm -rf .git/
}

function write {
  echo "Enter the title for your blog post:"
  read input

  title=$(echo "$input" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
  filename=$(echo "$input" | tr ' ' '-' | tr '[:upper:]' '[:lower:]').makerb
  filepath="app/content/pages/writing/$filename"
  template="app/content/pages/writing/template.makerb"
  
  touch "app/content/pages/writing/$filename"

  cp "$template" "$filepath"

  # Try to handle the in-place editing in a cross-platform way
  if [[ "$OSTYPE" == "darwin"* ]]; then
      # For macOS, which requires an empty string argument with -i
      sed -i '' "s/title:/title: $title/" "$filepath"
  else
      # For Linux
      sed -i "s/title:/title: $title/" "$filepath"
  fi

  echo "File $filename created in app/content/pages/writing/ based on template"
}

if [ "$1" == "up" ]; then
  up
elif [ "$1" == "spec" ]; then
  spec
elif [ "$1" == "install" ]; then
  install_deps
  setup_db
  migrate
  elif [ "$1" == "init" ]; then
  init "${2}" "${3}"
elif [ "$1" == "write" ]; then
  write
else
  usage
fi