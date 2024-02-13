#!/bin/bash

# Colors
RC='\033[0;31m'
GC='\033[0;32m'
YC='\033[0;33m'
BF='\033[1m'
UL='\033[4m'
NC='\033[0m' # No Color

# Derive default platform based on the current environment
get_platform() {
  local uname_out
  uname_out=$(uname -s)
  case $uname_out in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    *)          machine=Unknown;;
  esac

  if [ "$machine" == "Linux" ]; then
    case $(uname -m) in
      x86_64) echo "linux-x64";;
      aarch64) echo "linux-arm64";;
      *) echo "Unknown architecture"; exit 1;;
    esac
  elif [ "$machine" == "Mac" ]; then
    case $(uname -m) in
      x86_64) echo "osx-x64";;
      arm64) echo "osx-arm64";;
      *) echo "Unknown architecture"; exit 1;;
    esac
  else
    echo "Unknown platform"
    exit 1
  fi
}

default_platform=$(get_platform)

# Function to display usage
usage() {
  echo -e "${UL}Usage:${NC} ${BF}$0 ${YC}<task>${NC} [OPTIONS]"
  echo -e "${UL}Tasks:${NC}"
  echo -e "  ${BF}init${NC}                              Initialize the given number of runners"
  echo -e "    ${UL}Options:${NC}"
  echo -e "      -u, --url ${YC}<url>${NC}               The URL to be used for configuring the runners."
  echo -e "      -r, --runners ${YC}<num>${NC}           The number ${YC}(1-99)${NC} of runners to create."
  echo -e "      -p, --platform ${YC}<platform>${NC}     ${BF}(Optional)${NC} The platform of the runners. ${BF}Default:${NC} ${GC}${default_platform}${NC}"
  echo -e "      -v, --version ${YC}<version>${NC}       ${BF}(Optional)${NC} The version the actions runner to install. ${BF}Default:${NC} ${GC}2.312.0${NC}"
  echo -e "  ${BF}enable${NC}|${BF}disable${NC}|${BF}start${NC}|${BF}stop${NC}"
  echo -e "    ${UL}Options:${NC}"
  echo -e "      -r, --runners ${YC}<range>${NC}|${YC}<num>${NC}   The range or number of runners to operate on. Format for range: ${YC}<start>${NC}-${YC}<end>${NC}."
  echo -e "      -p, --platform ${YC}<platform>${NC}     ${BF}(Optional)${NC} The platform of the runners. ${BF}Default:${NC} ${GC}${default_platform}${NC}"
  echo -e "${UL}Examples:${NC}"
  echo -e "  ${BF}$0 init ${NC}--url https://github.com/my-org --runners 5 --platform ${default_platform} --version 2.315.0"
  echo -e "  ${BF}$0 enable ${NC}--runners 1-5 --platform ${default_platform}"
}



# Function to display error message for extra arguments
check_extra_arguments() {
  if [ $# -gt 0 ]; then
    echo -e "${RC}${BF}Error:${NC} Extra arguments detected."
    usage
    exit 1
  fi
}

# Function to parse options for init task
parse_other_options() {
  task="$1"
  shift
  runners=""
  platform=${default_platform}

  OPTS=$(getopt r:p: "$@")
  if [ $? != 0 ]; then
    usage
    exit 1
  fi

  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -r)
        runners="$2"
        if [[ $runners =~ ^[0-9]+$ && "$runners" -ge 1 && "$runners" -lt 100 ]]; then
          start=$runners
          end=$runners
        else
          # Try to split the input by dash and assign to start and end
          IFS='-' read -r start end <<< "$runners"
          if ! [[ $start =~ ^[0-9]+$ && $end =~ ^[0-9]+$ ]]; then
            echo "${RC}${BF}Error:${NC} The value of runners is not a valid format (should be a non-negative integer or a combination of two non-negative integers to indicate a range)."
          fi
        fi
        shift 2
        ;;
      -p)
        platform="$2"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        echo "Internal error!"
        exit 1
        ;;
    esac
  done

  if [[ -z "$runners" ]]; then
    echo -e "${RC}${BF}Error:${NC} Missing required 'runners' option for '$task' task."
    usage
    exit 1
  fi

  # Check for extra arguments
  check_extra_arguments "$@"
}

# Function to check if directory already exists
check_not_exists() {
  if [ -d "$1" ]; then
    echo -e "${RC}${BF}Error:${NC} Directory $1 already exists. Please choose a different directory name or remove the existing directory."
    exit 1
  fi
}

# Function to check if directory exists
check_exists() {
  if [ ! -d "$1" ]; then
    echo -e "${RC}${BF}Error:${NC} Directory $1 does not exist. Skipping..."
  fi
}
# Function to perform actions for init mode
init_mode() {
    # Print message indicating directory creation
    echo "Creating directories..."

    # Create directories with specified prefix and index (00 to runners-1)
    for ((i=0; i<runners; i++)); do
        index=$(printf "%02d" $i)
        directory="${platform}-${index}"
        check_not_exists "$directory"
        mkdir "$directory"
        echo "Created $directory."
    done

    # Change directory to dir-00
    cd "${platform}-00" || exit

    # Print message indicating download
    echo "Downloading actions runner..."

    # Run the curl command with the specified platform and version number, showing a progress bar
    curl -# -o "$archive_name" -L "https://github.com/actions/runner/releases/download/v${version}/${archive_name}"

    # Print message indicating extraction
    echo "Extracting actions runner..."

    # Extract the archive
    tar -xzf "$archive_name"

    # Remove the archive
    rm "$archive_name"

    # Move back to the parent directory
    cd ..

    # Print message indicating copying
    echo "Copying actions runner to other directories..."

    # Copy contents of dir-00 to other directories
    for ((i=1; i<runners; i++)); do
        index=$(printf "%02d" $i)
        cp -a "${platform}-00"/* "${platform}-${index}/"
    done

    echo "Configuration in progress..."

    # Run configuration in each directory
    for ((i=0; i<runners; i++)); do
        index=$(printf "%02d" $i)
        directory="${platform}-${index}"
        cd "$directory" || exit
        # ./config.sh --unattended \
        #             --name "${platform}-${index}" \
        #             --url "$url" \
        #             --pat "$gh_token"
        # if [ $? -ne 0 ]; then
        #     echo -e "${RC}${BF}Error:${NC} Configuration failed for directory $directory"
        #     exit 1
        # fi
        # if [ "$(uname)" == "Darwin" ]; then
        #     ./svc.sh install
        # elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        #     ./svc.sh install "$USERNAME"
        # fi
        cd ..
    done

    echo "Script execution completed."
}

# Check if gh is installed and configured properly
check_pat() {
  # Check installation
  if ! command -v gh &>/dev/null; then
    echo -e "${RC}${BF}Error:${NC} GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/"
    exit 1
  fi

  # Check if user is authenticated
  if ! gh auth status &>/dev/null; then
    echo -e "${RC}${BF}Error:${NC} You need to be logged in using 'gh auth login' to use this script."
    exit 1
  fi

  # Get GitHub token
  gh_token=$(gh auth token)
  if [ -z "$gh_token" ]; then
    echo -e "${RC}${BF}Error:${NC} Failed to obtain GitHub token. Please make sure you are logged in using 'gh auth login'."
    exit 1
  fi
}

# Main script logic
task="$1"
shift

case "$task" in
  init)
    parse_init_options "$@"
    echo "Initializing $runners $platform runners with for $url using version $version."
    check_pat
    init_mode
    ;;
  enable | disable | start | stop) # install start status stop
    parse_other_options "$task" "$@"
    echo "Taking action to $task $platform runner(s) $runners."
    for ((i=start; i<=end; i++)); do
      index=$(printf "%02d" $i)
      directory="${platform}-runner-${index}"
      if [ ! -d "$directory" ]; then
        echo -e "${RC}${BF}Error:${NC} Directory $directory does not exist. Skipping..."
        continue
      else
        cd "$directory"
      fi
      if [ ! -f "./svc.sh" ]; then
        echo -e "${RC}${BF}Error:${NC} Runner $directory does not appear to be initialized. Skipping..."
        cd ..
        continue
      else
        if [ "$(uname)" == "Darwin" ]; then
          ./svc.sh start
        elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
          ./svc.sh install "$USERNAME"
        fi
        cd ..
      fi
    done
    ;;
  *)
    echo -e "${RC}${BF}Error:${NC} Unrecognized task: $task" >&2
    usage
    exit 1
    ;;
esac
