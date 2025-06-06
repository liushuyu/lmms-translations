#!/bin/bash -e

aberr(){ printf "[\e[31mERROR\e[0m]: \e[1m%s\e[0m\n" "$*" >&2; }
abinfo(){ printf "[\e[96mINFO\e[0m]: \e[1m%s\e[0m\n" "$*" >&2; }

function push_repo_translation() {
    set +e
    if ! git log -1 | grep '\[skip ci\]'; then
        CHANGED="$(git diff --name-only HEAD^ -- | grep -E 'lmms(.io)?/.*\.(xlf|ts)')"
        abinfo "Detected changes: $CHANGED"
        for i in $CHANGED; do
            FILE_RES="${i%/*}" # strip content after /
            FILE_RES="${FILE_RES/./}" # remove .
            FILE_LANG="${i#*/}" # strip content before /
            FILE_LANG="${FILE_LANG%.*}" # strip content after .
            FILE_LANG="${FILE_LANG/messages./}" # remove substring 'messages.'
            abinfo "Pushing resource ${FILE_RES} (${FILE_LANG})..."
            tx push -r "lmms.${FILE_RES}" -l "${FILE_LANG}" -t 
        done
    else
        abinfo "No previous translation changes detected."
    fi
    set -e
}

abinfo "Setting up Transifex..."

export TX_TOKEN="$TX_API_KEY"
cat <<EOF > ~/.transifexrc
[https://www.transifex.com]
api_hostname = https://api.transifex.com
rest_hostname = https://rest.api.transifex.com
hostname = https://www.transifex.com
password = $TX_API_KEY
token = $TX_API_KEY
username = api
EOF

git config --global --add safe.directory "$PWD"
push_repo_translation
set +e
# Only push when needed
if ! git diff --quiet; then
    set -e
    abinfo "Now uploading to Transifex..."

    tx push -s

    abinfo "Fetching latest translations from Transifex..."

    tx pull -a -f

    abinfo "Now pushing to GitHub..."

    git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git config --global user.name 'github-actions[bot]'
    git checkout master
    git add lmms/ lmms.io/
    git commit -m "Automatically generated translations [skip ci]"
    git push
fi

abinfo "Tasks are finished!"
