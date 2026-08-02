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
  if ! IFS= read -r input; then
    echo "Failed to read title" >&2
    return 1
  fi

  slug=$(ruby -e \
    'print ARGV.fetch(0).downcase.gsub(/[^a-z0-9]+/, "-").sub(/\A-+/, "").sub(/-+\z/, "")' \
    "$input") || {
    echo "Failed to derive draft slug" >&2
    return 1
  }

  if [[ -z "$slug" ]]; then
    echo "Title must contain at least one ASCII letter or number" >&2
    return 1
  fi

  filename="$slug.markerb"
  drafts_dir="app/content/pages/writing/drafts"
  posts_dir="app/content/pages/writing/posts"
  filepath="$drafts_dir/$filename"
  template="app/content/templates/writing.makerb"

  if [[ ! -f "$template" ]]; then
    echo "Writing template not found at $template" >&2
    return 1
  fi

  if [[ -d "$posts_dir" ]]; then
    if post_scan_output=$(ruby -r "./lib/writing/path" -e '
      posts_dir, slug = ARGV

      begin
        Dir.children(posts_dir).sort.each do |filename|
          source_path = File.join(posts_dir, filename)
          next unless File.file?(source_path) || File.symlink?(source_path)

          path = Writing::Path.new(source_path)
          next unless path.slug == slug

          puts source_path
          exit 2
        end
      rescue Writing::Path::Invalid => error
        warn error.message
        exit 3
      end
    ' "$posts_dir" "$slug" 2>&1); then
      :
    else
      post_scan_status=$?
      if [[ "$post_scan_status" -eq 2 ]]; then
        echo "Writing slug already published at $post_scan_output" >&2
      else
        echo "$post_scan_output" >&2
      fi
      return 1
    fi
  fi

  if ! mkdir -p "$drafts_dir"; then
    echo "Failed to create drafts directory at $drafts_dir" >&2
    return 1
  fi

  if [[ -e "$filepath" || -L "$filepath" ]]; then
    echo "Draft already exists at $filepath" >&2
    return 1
  fi

  temporary_path=$(mktemp "$drafts_dir/.${filename}.tmp.XXXXXX") || {
    echo "Failed to create temporary draft" >&2
    return 1
  }

  if ! cp -p "$template" "$temporary_path"; then
    rm -f "$temporary_path"
    echo "Failed to copy writing template" >&2
    return 1
  fi

  if ! ruby -rjson -e '
    path, title = ARGV
    content = File.binread(path)
    replaced = content.sub!(/^title:[^\r\n]*(\r?)$/) do
      "title: #{JSON.generate(title)}#{Regexp.last_match(1)}"
    end
    exit 1 unless replaced
    File.binwrite(path, content)
  ' "$temporary_path" "$input"; then
    rm -f "$temporary_path"
    echo "Failed to populate title in draft" >&2
    return 1
  fi

  if [[ -e "$filepath" || -L "$filepath" ]]; then
    rm -f "$temporary_path"
    echo "Draft already exists at $filepath" >&2
    return 1
  fi

  if ! mv -n "$temporary_path" "$filepath"; then
    rm -f "$temporary_path"
    echo "Failed to finalize draft at $filepath" >&2
    return 1
  fi

  if [[ -e "$temporary_path" || -L "$temporary_path" ]]; then
    rm -f "$temporary_path"
    if [[ -e "$filepath" || -L "$filepath" ]]; then
      echo "Draft already exists at $filepath" >&2
    else
      echo "Failed to finalize draft at $filepath" >&2
    fi
    return 1
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
