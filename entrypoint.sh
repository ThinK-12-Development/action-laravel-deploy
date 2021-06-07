#!/bin/bash

set -euo pipefail

#
# Config
#

UNIX_EPOCH_MILLISECONDS=$(($(date +%s%N)/1000000))

CURRENT_PATH=/home/$INPUT_USER/current
SHARED_PATH=/home/$INPUT_USER/shared
RELEASE_PATH=/home/$INPUT_USER/releases/$UNIX_EPOCH_MILLISECONDS

REMOTE_SSH_KEY_FILE=remote.key
PROXY_SSH_KEY_FILE=proxy.key
PROXY_COMMAND="ssh -o StrictHostKeyChecking=no -i $PROXY_SSH_KEY_FILE $INPUT_PROXY_USER@$INPUT_PROXY_HOST -W %h:%p"

#
# Prepare SSH Keys
#

echo "$INPUT_KEY" > $REMOTE_SSH_KEY_FILE
echo "$INPUT_PROXY_KEY" > $PROXY_SSH_KEY_FILE

chmod 400 $REMOTE_SSH_KEY_FILE
chmod 400 $PROXY_SSH_KEY_FILE

#
# Functions
#

ssh_command() {
  ssh -o "ProxyCommand $PROXY_COMMAND" -i "$REMOTE_SSH_KEY_FILE" "$INPUT_USER@$INPUT_HOST" "$1"
}

release_create() {
  ssh_command "mkdir -p $RELEASE_PATH"
}

release_link() {
  ssh_command "ln -sfn $RELEASE_PATH $CURRENT_PATH"
}

env_copy() {
  ssh_command "cp $SHARED_PATH/.env $RELEASE_PATH"
}

source_copy() {
  ssh_command "mv $INPUT_SOURCE/* $RELEASE_PATH"
}

laravel_cache() {
  local remote_commands=("cd $INPUT_SOURCE" ";php artisan cache:clear")

  IFS=',' read -r -a cache_commands <<< "$INPUT_CACHE"

  for i in "${!cache_commands[@]}"; do
      if [[ $i -ne 0 ]]; then
          remote_commands[i]=";php artisan ${cache_commands[i]}:cache"
      fi
  done

  ssh_command "${remote_commands[@]}"
}

laravel_storage_link() {
  ssh_command "rm -rf $RELEASE_PATH/storage;ln -s $SHARED_PATH/storage $RELEASE_PATH;ln -s $RELEASE_PATH/storage/app/public $RELEASE_PATH/public/storage"
}

#
# Main
#

release_create

env_copy

source_copy

laravel_cache

laravel_storage_link

release_link
