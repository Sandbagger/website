#!/bin/bash

# chmod u+x go

function usage()
{
  echo "Usage:"
  echo "    go                    Display this help message"
  echo "    go up                 Run the app using the procfile"
  echo "    go test               Run the Minitest suite"
  echo "    go install            Install dependencies and create the database and migrate"
  echo "    go write              Scaffold a new writing post from the template"
}

function up {
  ./bin/dev
}

function run_tests {
  bundle exec rails test "$@"
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

function write {
  echo "Enter the title for your blog post:"
  read input

  title=$(echo "$input" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
  filename=$(echo "$input" | tr ' ' '-' | tr '[:upper:]' '[:lower:]').markerb
  drafts_dir="app/content/pages/writing/drafts"
  filepath="$drafts_dir/$filename"
  template="app/content/templates/writing.makerb"

  mkdir -p "$drafts_dir"

  if [[ -e "$filepath" ]]; then
    echo "Draft already exists at $filepath" >&2
    return 1
  fi

  cp "$template" "$filepath"

  # Try to handle the in-place editing in a cross-platform way
  if [[ "$OSTYPE" == "darwin"* ]]; then
      # For macOS, which requires an empty string argument with -i
      sed -i '' "s/title:/title: $title/" "$filepath"
  else
      # For Linux
      sed -i "s/title:/title: $title/" "$filepath"
  fi

  echo "Draft created at $filepath"
}

case "$1" in
  up) up ;;
  test|spec) shift; run_tests "$@" ;;
  install) install_deps; setup_db; migrate ;;
  write) write ;;
  *) usage ;;
esac
