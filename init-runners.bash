#!/bin/bash

# Check if correct number of arguments are provided
if [ "$#" -lt 1 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <num_runners> [platform] [version_number] [directory_prefix]"
    exit 1
fi

# Extract arguments
num_runners=$1
platform=${2:-osx-arm64}
version=${3:-2.312.0}
dir_prefix=${4:-action-runner}
archive_name="actions-runner-${platform}-${version}.tar.gz"

# Function to check if directory already exists
check_directory() {
    if [ -d "$1" ]; then
        echo "Error: Directory $1 already exists. Please choose a different directory name or remove the existing directory."
        exit 1
    fi
}

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

echo "Downloading actions runner..."

# Run the curl command with the specified platform and version number, showing a progress bar
curl -# -o "$archive_name" -L "https://github.com/actions/runner/releases/download/v${version}/${archive_name}"

echo "Extracting actions runner..."

# Extract the archive, remove it, and move back to the parent directory.
tar -xzf "$archive_name"
rm "$archive_name"
cd ..

# Print message indicating copying
echo "Copying actions runner to other directories..."

# Copy contents of dir-00 to other directories
for ((i=1; i<num_runners; i++)); do
    index=$(printf "%02d" $i)
    cp -a "${dir_prefix}-00"/* "${dir_prefix}-${index}/"
    echo "Copied files into ${dir_prefix}-${index}."
done

echo "Done initializing ${num_runners} runners."
