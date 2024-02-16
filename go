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
else
  usage
fi