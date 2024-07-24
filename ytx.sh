#!/usr/bin/env bash

# ----legacy-----

# ---- constants -----
APP_NAME="ytx"

APP_CACHE_DIR="$HOME/.cache/$APP_NAME"
SEARCH_RESULTS_DIR="$APP_CACHE_DIR/search_results"
SEARCH_THUMBNAILS_DIR="$SEARCH_RESULTS_DIR/thumbnails"
DESCRIPTIONS_DIR="$SEARCH_RESULTS_DIR/descriptions"

SEARCH_RESULTS="$SEARCH_RESULTS_DIR/results.json"
SEARCH_TITLES="$SEARCH_RESULTS_DIR/titles.txt"
CURRENT_SEARCH_RESULT="$SEARCH_RESULTS_DIR/current_index.txt"
SEARCH_RESULTS_IDS="$SEARCH_RESULTS_DIR/ids.txt"
SEARCH_THUMBNAILS="$SEARCH_RESULTS_DIR/thumbnails.txt"
SEARCH_THUMBNAIL_URLS="$SEARCH_RESULTS_DIR/thumbnail_urls.txt"
SEARCH_VIDEO_URLS="$SEARCH_RESULTS_DIR/video_urls.txt"

load_config() {
  FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
  --color=fg:#d0d0d0,fg+:#d0d0d0,bg:#121212,bg+:#262626
  --color=hl:#5f87af,hl+:#5fd7ff,info:#afaf87,marker:#87ff00
  --color=prompt:#d7005f,spinner:#af5fff,pointer:#af5fff,header:#87afaf
  --color=border:#262626,label:#aeaeae,query:#d9d9d9
  --border="rounded" --border-label="" --preview-window="border-rounded" --prompt="> "
  --marker=">" --pointer="◆" --separator="─" --scrollbar="│"'
}

ensure_paths() {
  ! [[ -d $SEARCH_RESULTS_DIR ]] || mkdir -p "$SEARCH_RESULTS_DIR"
  ! [[ -d $THUMBNAILS_DIR ]] || mkdir -p "$THUMBNAILS_DIR"

}

search_youtube() {
  clear
  SEARCH_TERM=$(gum input --header YTX-Search --placeholder search...)
  gum spin -- yt-dlp "https://www.youtube.com/results?search_query=$SEARCH_TERM&sp=EgIQAQ%253D%253D" -J --flat-playlist --playlist-start 1 --playlist-end 40 --cookies-from-browser chrome >"$SEARCH_RESULTS"

  # --- parse results ---
  jq '.entries[].id' "$SEARCH_RESULTS" -r >"$SEARCH_RESULTS_IDS"
  jq '.entries[].title' "$SEARCH_RESULTS" -r >"$SEARCH_TITLES"
  jq '.entries[].thumbnails[1].url' "$SEARCH_RESULTS" -r >"$SEARCH_THUMBNAIL_URLS"
  jq '.entries[].url' "$SEARCH_RESULTS" -r >"$SEARCH_VIDEO_URLS"

  # --- init image loader ---
  i=1
  cat /dev/null >"$SEARCH_THUMBNAILS"
  while [ $i -le "$(wc -l <"$SEARCH_RESULTS_IDS")" ]; do
    # * url *
    URL=$(head -$i <"$SEARCH_THUMBNAIL_URLS" | tail +$i)
    echo "url = \"$URL\"" >>"$SEARCH_THUMBNAILS"

    # * dest *
    OUTPUT=$(head -$i <"$SEARCH_RESULTS_IDS" | tail +$i)
    echo "output = \"$SEARCH_THUMBNAILS_DIR/$OUTPUT.jpg\"" >>"$SEARCH_THUMBNAILS"
    ((i++))
  done
  echo Downloading thumbnails in background...
  curl -s -K "$SEARCH_THUMBNAILS" &

  # --- select video ---

  # ** constants **

  HEADER=$(figlet "YTX")
  SHELL=$(which bash)
  export SEARCH_RESULTS_IDS SEARCH_THUMBNAILS_DIR SHELL CURRENT_SEARCH_RESULT
  PREVIEW='
  i="$(echo {} | sed "s/\\t.*$//g")";
  echo $i >$CURRENT_SEARCH_RESULT;
  IMAGE="$SEARCH_THUMBNAILS_DIR/$(cat "$SEARCH_RESULTS_IDS" | head -$i | tail +$i)";
  fzf-preview "$IMAGE.jpg";
  echo ----------------------------------------
  echo {}
  '

  # run fzf
  TITLE=$(cat -n "$SEARCH_TITLES" | sed 's/^. *//g' | fzf --preview="$PREVIEW" --cycle --reverse --prompt "Watch: " --header="$HEADER" --header-first --exact -i --layout=reverse)

  i=$(cat "$CURRENT_SEARCH_RESULT")
  URL=$(cat "$SEARCH_VIDEO_URLS" | head -$i | tail -$i)
  # --- stream with mpv ---
  mpv "$URL"

  # jq '.entries[1].thumbnails[].url' "$SEARCH_RESULTS"
  # curl --silent -K "$SEARCH_THUMBNAILS"

}
load_config
ensure_paths
search_youtube
