# Written for Bash, usable in Zsh
# By Robert Cobb (robert.cobb@flatironschool.com)

function github_link_from_https_to_ssh() {
  temp="$(echo $1 | sed 's+https://github.com/+git@github.com:+g')"
  echo "$temp.git"
}

function hub-gh-token() {
  local token=$(cat ~/.config/hub | grep token | cut -d ' ' -f 4)
  [ -n "$token" ] && echo "$token" || >&2 echo "No hub token found, need to configure hub's token"
}

function github_repo_links_from_track_csv() {
   cat $1 | while IFS="," read -r a b c d e; do temp="${e%\"}"; temp="${temp#\"}"; echo "$temp"; done
}

# accepts a track id, outputs a list of lessons
function lesson_list() {
  $PWD/tools/track_output.py $1 -g
}

function update_lesson_lists() {
  while read line; do
    local list_file="$(echo $line | sed 's/[0-9[:space:]]*\(.*\)/\1/'| tr 'A-Z :' 'a-z-').txt"
    local track_id=$(echo $line | sed 's/\([0-9]*\).*/\1/' )
    lesson_list $track_id > "$1/$list_file"
    echo "track $track_id repos stored in $1/$list_file"
  done < $1/names-and-ids.txt
}

# takes a file with a list of lessons as github repos and a directory
# clones all the repos in the list to the directory
function clone_lesson_list_to_dir() {
  mkdir $2
  local PWD=$(pwd)
  cd $2
  while read repo; do
    echo "$repo"
    git clone "$repo" 
  done < $1
  cd $PWD
}

function gh-rate-limit-check() {
  command -v jq
  if [ $? -ne 0 ]
  then
    echo "Must have the `jq` program installed exist" >&2
  fi
  curl -s -H "Authorization: token $(hub-gh-token)" -X GET https://api.github.com/rate_limit | jq '.rate.remaining'
}

function git-check-remote() {
  local UPSTREAM=${1:-'@{u}'}
  local LOCAL=$(git rev-parse @)
  local REMOTE=$(git rev-parse "$UPSTREAM")
  local BASE=$(git merge-base @ "$UPSTREAM")

  if [ $LOCAL = $REMOTE ]; then
    true
  elif [ $LOCAL = $BASE ]; then
    echo "Need to pull"
  elif [ $REMOTE = $BASE ]; then
    echo "Need to push"
  else
    echo "Diverged"
  fi
}

function git-check-status() {
  git remote update &>/dev/null
  local status=$(git-check-remote)
  local pwd=$(pwd)
  local dir=$(basename "$pwd")
  [ -n "$status" ] && echo "$dir: $status";
}

function check-track-git-status() {
  local pwd=$(pwd)
  for f in $(ls);
  do
    cd $f && git-check-status;
    cd "$pwd";
  done
  cd "$pwd";
}

function get-last-commit-sha() {
  local reponame=$1
  curl -H "Authorization: token $(hub-gh-token)" -s "https://api.github.com/repos/${reponame}/commits"  | jq ".[0].sha" 2>&1
}

function check-for-misalignment() {
  local default_org="learn-co-curriculum"
  local students_org="learn-co-students"
  local repo_shortname="$1"
  local downstream_org="$2"
  local canonical_sha=$(get-last-commit-sha "${default_org}/${repo_shortname}")
  local downstream_sha=$(get-last-commit-sha "${students_org}/${repo_shortname}-${downstream_org}")
  if [ $canonical_sha != $downstream_sha ]
  then
    echo "${repo_shortname} is out of sync! ${canonical_sha} versus ${downstream_sha}"
  else
    echo "${repo_shortname} is synchronized at ${canonical_sha}"
  fi
}

function check-for-misalignment-lcc() {
  local default_org="learn-co-curriculum"
  local students_org="learn-co-curriculum"
  local repo_shortname="$1"

  local canonical_sha=$(get-last-commit-sha "${default_org}/${repo_shortname}")
  local downstream_sha=$(get-last-commit-sha "${students_org}/phrg-${repo_shortname}")

  if [ "$(echo $canonical_sha|cut -c1-9)" == 'jq: error' ] || [ "$(echo $downstream_sha|cut -c1-9)" == 'jq: error' ]
  then
    echo "[UNIQSHA] ${repo_shortname} was not replicated"
  elif [ $canonical_sha != $downstream_sha ]
  then
    echo "[UNSYNC] phrg-${repo_shortname} [${canonical_sha}:${downstream_sha}]"
  else
    echo "[SYNC] ${repo_shortname}"
  fi
}
