#!/bin/bash

set -euo pipefail

#
# Config
#

UNIX_EPOCH_SECONDS=$(date +%s)

CURRENT_PATH=/home/$INPUT_USER/current
SHARED_PATH=/home/$INPUT_USER/shared
RELEASE_PATH=/home/$INPUT_USER/releases/$UNIX_EPOCH_SECONDS

#
# Prepare SSH config
#

echo "$INPUT_KEY" > /etc/ssh/remote.key
echo "$INPUT_PROXY_KEY" > /etc/ssh/proxy.key

chmod 400 /etc/ssh/remote.key
chmod 400 /etc/ssh/proxy.key

echo "Host destination" >> /etc/ssh/ssh_config
echo " User $INPUT_USER" >> /etc/ssh/ssh_config
echo " HostName $INPUT_HOST" >> /etc/ssh/ssh_config
echo " StrictHostKeyChecking=no" >> /etc/ssh/ssh_config
echo " IdentityFile /etc/ssh/remote.key" >> /etc/ssh/ssh_config
echo " ProxyJump proxy" >> /etc/ssh/ssh_config

echo "Host proxy" >> /etc/ssh/ssh_config
echo " User $INPUT_PROXY_USER" >> /etc/ssh/ssh_config
echo " HostName $INPUT_PROXY_HOST" >> /etc/ssh/ssh_config
echo " StrictHostKeyChecking=no" >> /etc/ssh/ssh_config
echo " IdentityFile /etc/ssh/proxy.key" >> /etc/ssh/ssh_config

#
# Functions
#

ssh_command() {
  ssh destination "$1"
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

cleanup() {
  ssh_command "if [ -f cleanup-releases ]; then ./cleanup-releases; else false; fi"
  ssh_command "echo $RELEASE_PATH > previous"
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

cleanup
