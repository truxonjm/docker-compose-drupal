#!/bin/bash

# This is an helper to setup this docker compose Drupal stack on Ubuntu 16.04/18.04.
# This script must be run as ubuntu user with sudo privileges without password.
# We assume that docker and docker-compose is properly installed when using this
# script (From cloud config files in this folder).
# This script is used with a cloud config setup from this folder.

# Variables.
_USER="ubuntu"
_GROUP="ubuntu"

# Project variables.
_BASE=${1-"default"}
_PROJECT_PATH="$HOME/docker-compose-drupal"
_PHP="dcd-php"
_PROJECT_ROOT="$_PROJECT_PATH/data/www"
_ROOT="/var/www/localhost/drupal"
_WEB="$_ROOT/web"
_DRUPAL_CONSOLE="$_ROOT/vendor/bin/drupal"
_DRUSH="$_ROOT/vendor/bin/drush"

# Ensure permissions.
sudo chown -R $_USER:$_GROUP $HOME

# Set Docker group to our user (temporary fix?).
sudo usermod -a -G docker $_USER

# Get a Docker compose stack.
if [ ! -d "$_PROJECT_PATH" ]; then
  echo -e "\n>>>>\n[setup::info] Get Docker stack...\n<<<<\n"
  curl -fSL https://gitlab.com/mog33/docker-compose-drupal/-/archive/master/docker-compose-drupal-master.tar.gz -o docker-compose-drupal-master.tar.gz
  if ! [ -f "docker-compose-drupal-master.tar.gz" ]; then
  echo -e "\n>>>>\n[setup::info] Get Docker stack, 2nd try...\n<<<<\n"
  curl -fSL https://gitlab.com/mog33/docker-compose-drupal/-/archive/master/docker-compose-drupal-master.tar.gz -o docker-compose-drupal-master.tar.gz
  fi
  if ! [ -f "docker-compose-drupal-master.tar.gz" ]; then
    echo -e "\n>>>>\n[setup::error] Failed to download DcD :(\n<<<<\n"
    exit 1
  fi
  tar -xzf docker-compose-drupal-master.tar.gz
  mv docker-compose-drupal-master $_PROJECT_PATH
  rm -f docker-compose-drupal-master.tar.gz
else
  echo -e "\n>>>>\n[setup::notice] Docker stack already here!\n<<<<\n"
fi

# Set-up and launch this Docker compose stack.
echo -e "\n>>>>\n[setup::info] Prepare Docker stack...\n<<<<\n"
(cd $_PROJECT_PATH && make setup)

echo -e "\n>>>>\n[setup::info] Set and launch stack ${_BASE}\n<<<<\n"
if [ -f "$_PROJECT_PATH/samples/$_BASE.yml" ]; then
  cp $_PROJECT_PATH/samples/$_BASE.yml $_PROJECT_PATH/docker-compose.yml
fi

docker-compose --file "${_PROJECT_PATH}/docker-compose.yml" up -d --build

# Set-up composer.
if ! [ -f "/usr/bin/composer" ]; then
  echo -e "\n>>>>\n[setup::info] Set-up Composer and dependencies...\n<<<<\n"
  cd $HOME
  curl -sS https://getcomposer.org/installer | php -- --install-dir=$HOME --filename=composer
  sudo mv $HOME/composer /usr/bin/composer
  sudo chmod +x /usr/bin/composer
  /usr/bin/composer global require "hirak/prestissimo:^0.3" "drupal/coder"
else
  echo -e "\n>>>>\n[setup::notice] Composer already here!\n<<<<\n"
  # Install dependencies just in case.
  /usr/bin/composer global require "hirak/prestissimo:^0.3" "drupal/coder"
fi

# Set-up Code sniffer.
echo -e "\n>>>>\n[setup::info] Set-up Code sniffer and final steps...\n<<<<\n"
if [ -f "$HOME/.config/composer/vendor/bin/phpcs" ]; then
  $HOME/.config/composer/vendor/bin/phpcs --config-set installed_paths $HOME/.config/composer/vendor/drupal/coder/coder_sniffer
fi

# Check if containers are up...
RUNNING=$(docker inspect --format="{{ .State.Running }}" $_PHP 2> /dev/null)
if [ $? -eq 1 ]; then
  echo -e "\n>>>>\n[setup::ERROR] Container $_PHP does not exist...\n<<<<\n"
  # Wait a bit for stack to be up....
  sleep 10s
fi

# Add composer path to environment.
cat <<EOT >> $HOME/.profile
PATH=\$PATH:$HOME/.config/composer/vendor/bin
EOT

# Add docker, phpcs, drush and drupal console aliases.
cat <<EOT >> $HOME/.bash_aliases
# Docker
alias dk='docker'
# Docker-compose
alias dkc='docker-compose'
# Drush and Drupal console
alias drush="$_PROJECT_PATH/scripts/drush"
alias drupal="$_PROJECT_PATH/scripts/drupal"
# Check Drupal coding standards
alias cs="$HOME/.config/composer/vendor/bin/phpcs --standard=Drupal --extensions='php,module,inc,install,test,profile,theme,info'"
# Check Drupal best practices
alias csbp="$HOME/.config/composer/vendor/bin/phpcs --standard=DrupalPractice --extensions='php,module,inc,install,test,profile,theme,info'"
# Fix Drupal coding standards
alias csfix="$HOME/.config/composer/vendor/bin/phpcbf --standard=Drupal --extensions='php,module,inc,install,test,profile,theme,info'"
EOT

# Convenient links.
if [ ! -d "$HOME/www" ]; then
  ln -s $_PROJECT_ROOT $HOME/www
fi
if [ ! -d "/www" ]; then
  sudo ln -s $_PROJECT_ROOT /www
  sudo chown $_USER:$_GROUP /www
fi
if [ ! -d "$HOME/dcd" ]; then
  ln -s $_PROJECT_PATH $HOME/dcd
fi
if [ ! -d "/dcd" ]; then
  sudo ln -s $_PROJECT_PATH $HOME/dcd
  sudo chown $_USER:$_GROUP /dcd
fi

# Set up tools from stack.
if [ -d "$_PROJECT_PATH" ]; then
  echo -e "\n>>>>\n[setup::info] Setup Docker stack tools...\n<<<<\n"
  $_PROJECT_PATH/scripts/get-tools.sh install
fi

# Ensure permissions.
sudo chown -R $_USER:$_GROUP $HOME

echo -e "\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n
[setup::info] Docker compose stack install finished!\n
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n"
