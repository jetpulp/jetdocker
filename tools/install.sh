#!/usr/bin/env bash
main() {
  # Use colors, but only if connected to a terminal, and that terminal
  # supports them.
  if which tput >/dev/null 2>&1; then
      ncolors=$(tput colors)
  fi
  if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    BOLD="$(tput bold)"
    NORMAL="$(tput sgr0)"
  else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NORMAL=""
  fi

  # Only enable exit-on-error after the non-critical colorization stuff,
  # which may fail on systems lacking tput or terminfo
  set -e

  printf "${BLUE}Check requirements ...${NORMAL}\n"
  for command in docker docker-compose await
  do
    command -v $command >/dev/null 2>&1 || {
      echo "${RED}Error: $command is not installed"
      exit 1
    }
  done

  bash --version | grep "version 4\." >/dev/null 2>&1  || {
      echo "${RED}Error: bash 4 is not installed"
      if [ "$OSTYPE" != 'linux-gnu' ]; then
          echo ""
          echo "On mac OSX you can install it, run :"
          echo ""
          echo "brew install bash"
          echo "echo '/usr/local/bin/bash' | sudo tee -a /etc/shells;"
          echo ""
      fi
      exit 1
  }

  if [ ! -n "$JETDOCKER" ]; then
    JETDOCKER=~/.jetdocker
  fi

  if [ -d "$JETDOCKER" ]; then
    printf "${YELLOW}You already have jetdocker installed.${NORMAL}\n"
    printf "You'll need to remove $JETDOCKER if you want to re-install.\n"
    exit 1
  fi

  # Prevent the cloned repository from having insecure permissions. Failing to do
  # so causes compinit() calls to fail with "command not found: compdef" errors
  # for users with insecure umasks (e.g., "002", allowing group writability). Note
  # that this will be ignored under Cygwin by default, as Windows ACLs take
  # precedence over umasks except for filesystems mounted with option "noacl".
  umask g-w,o-w

  printf "${BLUE}Cloning Jetdocker...${NORMAL}\n"
  command -v git >/dev/null 2>&1 || {
    echo "${RED}Error: git is not installed"
    exit 1
  }
  # The Windows (MSYS) Git is not compatible with normal use on cygwin
  if [ "$OSTYPE" = cygwin ]; then
    if git --version | grep msysgit > /dev/null; then
      echo "${RED}Error: Windows/MSYS Git is not supported on Cygwin"
      echo "${RED}Error: Make sure the Cygwin git package is installed and is first on the path"
      exit 1
    fi
  fi
  env git clone https://github.com/coordtechjetpulp/jetdocker.git "$JETDOCKER" || {
    printf "${RED}Error: git clone of jetdocker repo failed\n"
    exit 1
  }

  printf "${BLUE}Add the jetdocker command to your local path ~/bin${NORMAL}\n"
  rm ~/bin/jetdocker || true 2> /dev/null
  ln -s ~/.jetdocker/jetdocker.sh ~/bin/jetdocker

  printf "${BLUE}Looking for an existing jetdocker config...${NORMAL}\n"
  if [ -f ~/.jetdockerrc ] || [ -h ~/.jetdockerrc ]; then
    printf "${YELLOW}Found ~/.jetdockerrc.${NORMAL} ${GREEN}Backing up to ~/.jetdockerrc.backup${NORMAL}\n";
    mv ~/.jetdockerrc ~/.jetdockerrc.backup;
  fi

  printf "${BLUE}Using the jetdocker template file and adding it to ~/.jetdockerrc${NORMAL}\n"

  cp "${JETDOCKER}/templates/jetdockerrc" ~/.jetdockerrc
  sed "/^export JETDOCKER=/ c\\
  export JETDOCKER=\"${JETDOCKER}\"
  " ~/.jetdockerrc > ~/.jetdockerrc-temp
  mv -f ~/.jetdockerrc-temp ~/.jetdockerrc
  sed "/^export USER_UID=/ c\\
  export USER_UID=\"$(id -u)\"
  " ~/.jetdockerrc > ~/.jetdockerrc-temp
  mv -f ~/.jetdockerrc-temp ~/.jetdockerrc
  sed "/^export USER_GROUP=/ c\\
  export USER_GROUP=\"$(id -g)\"
  " ~/.jetdockerrc > ~/.jetdockerrc-temp
  mv -f ~/.jetdockerrc-temp ~/.jetdockerrc

  printf "${BLUE}Source .jetdockerrc in your shell${NORMAL}\n"
  if [ -f ~/.zshrc ] ;
  then
      if ! grep -q "jetdockerrc" ~/.zshrc;
      then
          echo ". ~/.jetdockerrc" >>  ~/.zshrc
      fi
  fi

  if [ -f ~/.bashrc ] ;
  then
      if ! grep -q "jetdockerrc" ~/.bashrc;
      then
          echo ". ~/.jetdockerrc" >>  ~/.bashrc
      fi
  fi

  if [ -f ~/.bash_profile ] ;
  then
      if ! grep -q "jetdockerrc" ~/.bash_profile;
      then
          echo ". ~/.jetdockerrc" >>  ~/.bash_profile
      fi
  fi
  . ~/.jetdockerrc

  printf "${GREEN}"
  echo '                                          '
  echo '      _     __     __         __          '
  echo '     (_)__ / /____/ /__  ____/ /_____ ____'
  echo '    / / -_) __/ _  / _ \/ __/  ''_/ -_) __/'
  echo ' __/ /\__/\__/\_,_/\___/\__/_/\_\\__/_/   '
  echo '|___/                                     '
  echo '                                         ....is now installed!'
  echo ''
  echo 'Please look over the ~/.jetdockerrc file to set options.'
  echo ''
  printf "${NORMAL}"
}

main
