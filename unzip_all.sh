#!/bin/bash

# Loop through all .zip files in the current directory
for file in *.zip; do
  # Check if the file exists
  if [ -e "$file" ]; then
    extract_dir="${file%.zip}"  # Remove .zip extension to create folder name

    # Create the directory if it doesn't exist
    mkdir -p "$extract_dir"

    echo "Unzipping $file into $extract_dir..."
    unzip -o "$file" -d "$extract_dir"
  else
    echo "No zip files found."
    exit 1
  fi
done

echo "All zip files extracted."
