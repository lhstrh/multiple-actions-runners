#!/bin/bash

# Check if correct number of arguments are provided
if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
    echo "Usage: $0 <url> <num_runners> [platform] [version_number] [directory_prefix]"
    exit 1
fi

# Extract arguments
url=$1
shift
num_runners=$1
platform=${2:-osx-arm64}
version=${3:-2.312.0}
dir_prefix=${4:-"${platform}-runner"}
archive_name="actions-runner-${platform}-${version}.tar.gz"

# Function to check if directory already exists
check_directory() {
    if [ -d "$1" ]; then
        echo "Error: Directory $1 already exists. Please choose a different directory name or remove the existing directory."
        exit 1
    fi
}

# Check if gh is installed
if ! command -v gh &>/dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &>/dev/null; then
    echo "Error: You need to be logged in using 'gh auth login' to use this script."
    exit 1
fi

# Get GitHub token
gh_token=$(gh auth token)
if [ -z "$gh_token" ]; then
    echo "Error: Failed to obtain GitHub token. Please make sure you are logged in using 'gh auth login'."
    exit 1
fi

# Print message indicating directory creation
echo "Creating directories..."

# Create directories with specified prefix and index (00 to num_runners-1)
for ((i=0; i<num_runners; i++)); do
    index=$(printf "%02d" $i)
    directory="${dir_prefix}-${index}"
    check_directory "$directory"
    mkdir "$directory"
done

echo "Directories created: ${dir_prefix}-00 through ${dir_prefix}-$(printf "%02d" $((num_runners - 1)))"

# Change directory to dir-00
cd "${dir_prefix}-00" || exit

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

# Copy contents to other directories
for ((i=1; i<num_runners; i++)); do
    index=$(printf "%02d" $i)
    cp -a "${dir_prefix}-00"/* "${dir_prefix}-${index}/"
    echo "Copied files into ${dir_prefix}-${index}."
done

echo "Done copying files for ${num_runners} runners."

echo "Configuration in progress..."

# Run configuration in each directory
for ((i=0; i<num_runners; i++)); do
    index=$(printf "%02d" $i)
    directory="${dir_prefix}-${index}"
    cd "$directory" || exit
    if ! ./config.sh --unattended \
                    --name "${dir_prefix}-${index}" \
                    --url "$url" \
                    --pat "$gh_token"; then
        echo "Error: Configuration failed for $directory. Please check your settings and try again."
        exit 1
    fi
    cd ..
done

echo "Done configuring ${num_runners} runners."
