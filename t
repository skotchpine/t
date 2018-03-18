#!/usr/bin/env bash

key=$TRELLO_KEY
token=$TRELLO_TOKEN
endpoint=https://api.trello.com/1/
post_creds="&key=$key&token=$token"
pre_creds="?key=$key&token=$token"

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

noquotes() { sed -e "s/'//g" | sed -e 's/"//g'; }

usage() {
echo "
  ---- Trello ----
  without a browser

  get-board           # info about a board or the current board
  ls-board            # show all boards
  sh-board            # show shared boards
  set-board <name|id> # set the current board
  mk-board <name>     # create a new board
  rm-board <name|id>  # delete a board

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
"
}

usage_and_quit() { usage; exit 0; }
usage_and_fail() { usage; fail 1 $1; }

info() {
  local me=$(get members/me)

  if [[ $1 == '--raw' ]]; then
    echo $me | jq '.'
  else
    local id=$(echo $me | jq '.id' | noquotes)
    local name=$(echo $me | jq '.username' | noquotes)
    local email=$(echo $me | jq '.email' | noquotes)

    echo $name $email $id
  fi
}

#rm_card() {
#}
#
#mk_card() {
#}
#
#mv_card() {
#}
#
#get_card() {
#}
#
#ls_card() {
#}
#
#rm_list() {
#}
#
#mk_list() {
#}
#
#get_list() {
#}
#
#ls_list() {
#}
#
#rm_lbl() {
#}
#
#add_lbl() {
#}
#
#set_lbl() {
#}
#
#ls_lbl() {
#}
#
#rm_board() {
#}
#
#mk_board() {
#}
#
#set_board() {
#}
#
#sh_board() {
#}
#
#ls_board() {
#}
#
#get_board() {
#}
#
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

  info)  shift; info $@ ;;
  help)  usage_and_quit ;;
  *)     usage_and_fail "Unknown command: $1" ;;
esac
