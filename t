#!/usr/bin/env bash

key=$TRELLO_KEY
token=$TRELLO_TOKEN
pwb_file=${TRELLO_PWB_FILE:?}
endpoint=https://api.trello.com/1/
post_creds="&key=$key&token=$token"
pre_creds="?key=$key&token=$token"
pwb=$(cat $TRELLO_PWB_FILE)

quit() { echo ${@:2}; exit $1; }

fail() { quit $1 ${@:2} >&2; }

request() {
  local method=$1
  local path=$2

  if [[ "$path" =~ '?' ]]; then
    local url=$endpoint$path$post_creds
  else
    local url=$endpoint$path$pre_creds
  fi

  curl --silent --request $method --url $url
}

get()    { request GET    $1; }
post()   { request POST   $1; }
put()    { request PUT    $1; }
patch()  { request PATCH  $1; }
delete() { request DELETE $1; }

raw_get()    { get    $@ | jq '.'; }
raw_post()   { post   $@ | jq '.'; }
raw_put()    { put    $@ | jq '.'; }
raw_patch()  { patch  $@ | jq '.'; }
raw_delete() { delete $@ | jq '.'; }

noquotes() { sed -e "s/'//g" | sed -e 's/"//g'; }

jmap() {
  local json=$(jq '.')
  local n=$(echo $json | jq 'length')

  for i in $(seq 0 $((n - 1))); do
    echo $json | jq ".[$i]" | jecho $@
  done
}

jecho() {
  local json=$(jq '.')
  local out=""
  for spec in $@; do
    local part=$(echo $json | jq $spec | noquotes)
    [[ -z $part ]] && part='-'
    local out="$out $part"
  done
  echo $out
}

jid() {
  local json=$(jq '.')
  local n=$(echo $json | jq 'length')

  local id=""
  for i in $(seq 0 $((n - 1))); do
    local x=$(echo $json | jecho ".[$i].id")
    local name=$(echo $json | jecho ".[$i].name")
    local color=$(echo $json | jecho ".[$i].color")

    if [[ "$1" == "$x" ]] || [[ "$1" == "$name" ]] || [[ "$1" == "$color" ]]; then
      id=$x
      break
    fi
  done
  echo $id
}

usage() {
echo "
  ---- Trello ----
  without a browser

  get-board [<name|id>] # info about a board or the current board
  ls-board              # show all boards
  sh-board              # show shared boards
  set-board <name|id>   # set the current board
  mk-board <name>       # create a new board
  rm-board <name|id>    # delete a board

  ls-lbl                                       # show all labels for the current board
  set-lbl <color|id> <name>                    # set the name of a label
  add-lbl <card-name|id> <label-name|color|id> # add a label to a card
  rm-lbl <card-name|id> <label-name|color|id>  # delete a label from a card

  ls-list            # show all lists
  get-list <name|id> # info about a list
  mk-list <name>     # create a new list on the current board
  rm-list <name|id>  # delete a list

  ls-card [<list>]                      # show all cards in a list or on the current board
  get-card <name|id>                    # info about a card
  mv-card <card-name|id> <list-name|id> # move a card to another list
  mk-card <list-name|id> <name>         # create a new card on the current board
  rm-card <name|id>                     # remove a card

  raw-get    <path>
  raw-post   <path>
  raw-put    <path>
  raw-patch  <path>
  raw-delete <path>

  info # info about your profile
  help # show this help doc
"
}

usage_and_quit() { usage; exit 0; }
usage_and_fail() { usage; fail 1 $1; }

info() {
  get members/me | jecho .id .username .email
}

rm_card() {
  local id=$(get boards/$pwb/cards | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find card: $1"

  delete cards/$id > /dev/null

  ls_card
}

mk_card() {
  local id=$(get boards/$pwb/lists | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find list: $1"

  post "cards?idList=$id&name=$2" | jecho .id .name
}

mv_card() {
  local id=$(get boards/$pwb/cards | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find card: $1"

  local list_id=$(get boards/$pwb/lists | jid $2)
  [[ -z $list_id ]] && fail 3 "Failed to find card: $2"

  put "cards/$id?idList=$list_id" > /dev/null

  ls_card $list_id
}

get_card() {
  local id=$(get boards/$pwb/cards | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find card: $1"

  get cards/$id | jecho .id .name .labels
}

ls_card() {
  if [[ -z $1 ]]; then
    get boards/$pwb/cards | jmap .id .idList .name
  else
    local id=$(get boards/$pwb/lists | jid $1)
    [[ -z $id ]] && fail 3 "Failed to find list: $1"

    get lists/$id/cards | jmap .id .idList .name
  fi
}

rm_list() {
  local id=$(get boards/$pwb/lists | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find list: $1"

  put "lists/$id/closed?value=true" > /dev/null

  ls_list
}

mk_list() {
  post "lists?name=$1&idBoard=$pwb" | jecho .id .name
}

get_list() {
  local id=$(get boards/$pwb/lists | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find list: $1"

  get lists/$id | jecho .id .name
}

ls_list() {
  get boards/$pwb/lists | jmap .id .name
}

rm_lbl() {
  local id=$(get boards/$pwb/cards | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find card: $1"

  local lbl_id=$(get boards/$pwb/labels | jid $2)
  [[ -z $lbl_id ]] && fail 3 "Failed to find label: $2"

  delete cards/$id/idLabels/$lbl_id > /dev/null

  get_card $id
}

add_lbl() {
  local id=$(get boards/$pwb/cards | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find card: $1"

  local lbl_id=$(get boards/$pwb/labels | jid $2)
  [[ -z $lbl_id ]] && fail 3 "Failed to find label: $2"

  post "cards/$id/idLabels?value=$lbl_id" > /dev/null

  get_card $id
}

set_lbl() {
  local id=$(get boards/$pwb/labels | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find label: $1"

  put "labels/$id?name=$2" > /dev/null

  ls_lbl
}

ls_lbl() {
  get boards/$pwb/labels | jmap .id .color .name
}

rm_board() {
  local id=$(get member/me/boards | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find board: $1"

  delete boards/$id > /dev/null
}

mk_board() {
  post boards/?name=$1 | jecho .id
}

set_board() {
  local id=$(get member/me/boards | jid $1)
  [[ -z $id ]] && fail 3 "Failed to find board: $1"

  echo $id > $TRELLO_PWB_FILE
  echo $id
}

sh_board() {
  local my_id=$(get members/me | jecho .id)

  local is_not_mine=".idMember == \"$my_id\" and .memberType != \"admin\""

  get members/me/boards \
    | jq "map(select(.memberships | map($is_not_mine) | any))" \
    | jmap .id .name
}

ls_board() {
  local my_id=$(get members/me | jecho .id)

  local is_mine=".idMember == \"$my_id\" and .memberType == \"admin\""

  get members/me/boards \
    | jq "map(select(.memberships | map($is_mine) | any))" \
    | jmap .id .name
}

get_board() {
  local id=""

  if [[ -z $1 ]]; then
    id=$pwb
  else
    local id=$(get member/me/boards | jid $1)
    [[ -z $id ]] && fail 3 "Failed to find board: $1"
  fi

  get boards/$id | jecho .id .name
}

[[ -z $1 ]] && usage_and_quit

case $1 in
  get-board) get_board ${@:2} ;;
  ls-board)  ls_board  ${@:2} ;;
  sh-board)  sh_board  ${@:2} ;;
  set-board) set_board ${@:2} ;;
  mk-board)  mk_board  ${@:2} ;;
  rm-board)  rm_board  ${@:2} ;;

  ls-lbl)    ls_lbl    ${@:2} ;;
  set-lbl)   set_lbl   ${@:2} ;;
  add-lbl)   add_lbl   ${@:2} ;;
  rm-lbl)    rm_lbl    ${@:2} ;;

  ls-list)   ls_list   ${@:2} ;;
  get-list)  get_list  ${@:2} ;;
  mk-list)   mk_list   ${@:2} ;;
  rm-list)   rm_list   ${@:2} ;;

  ls-card)   ls_card   ${@:2} ;;
  get-card)  get_card  ${@:2} ;;
  mv-card)   mv_card   ${@:2} ;;
  mk-card)   mk_card   ${@:2} ;;
  rm-card)   rm_card   ${@:2} ;;

  raw-get)    raw_get    ${@:2} ;;
  raw-post)   raw_post   ${@:2} ;;
  raw-put)    raw_put    ${@:2} ;;
  raw-patch)  raw_patch  ${@:2} ;;
  raw-delete) raw_delete ${@:2} ;;

  info)  shift; info $@ ;;
  help)  usage_and_quit ;;
  *)     usage_and_fail "Unknown command: $1" ;;
esac
