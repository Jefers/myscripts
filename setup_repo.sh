#!/bin/bash

# Configuration file to store GitHub username
CONFIG_FILE="$HOME/.github_repo_setup_config"

# Default parent directory
PARENT_DIR="$HOME/LocalFile/GitHub"

# Function to validate directory name
validate_directory_name() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Invalid directory name. Use only letters, numbers, hyphens, or underscores."
        return 1
    fi
    return 0
}

# Function to validate Git repository name
validate_repo_name() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Invalid repository name. Use only letters, numbers, hyphens, or underscores."
        return 1
    fi
    return 0
}

# Function to validate GitHub token
validate_github_token() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo "Invalid GitHub token. Use only letters, numbers, or underscores."
        return 1
    fi
    return 0
}

# Load GitHub username from config file or prompt for it
load_github_username() {
    if [[ -f "$CONFIG_FILE" ]]; then
        GITHUB_USERNAME=$(cat "$CONFIG_FILE")
    else
        while true; do
            read -p "Enter your GitHub username: " GITHUB_USERNAME
            if validate_directory_name "$GITHUB_USERNAME"; then
                echo "$GITHUB_USERNAME" > "$CONFIG_FILE"
                break
            fi
        done
    fi
}

# Prompt for subdirectory name
prompt_for_subdirectory() {
    while true; do
        read -p "Enter the name of the subdirectory (repository name): " sub_dir
        if validate_directory_name "$sub_dir"; then
            break
        fi
    done
    echo "$sub_dir"
}

# Ensure the parent directory exists
mkdir -p "$PARENT_DIR"

# Load GitHub username
load_github_username

# Prompt for subdirectory name
sub_dir=$(prompt_for_subdirectory)

# Navigate to the subdirectory (create it if it doesn't exist)
mkdir -p "$PARENT_DIR/$sub_dir"
cd "$PARENT_DIR/$sub_dir" || exit

# Check if the directory already contains files
if [[ $(ls -A .) ]]; then
    echo "The subdirectory '$sub_dir' already contains files. Initializing Git repository in the existing directory."
else
    echo "Creating new subdirectory '$sub_dir' and initializing Git repository."
fi

# Initialize Git repository
git init

# Add all existing files to the repository
if [[ $(ls -A .) ]]; then
    git add .
    git commit -m "Initial commit: Added existing files"
else
    echo "No files found in the directory. You can add files later."
fi

# Ask if user wants to push to GitHub
read -p "Do you want to push this repository to GitHub? (y/n): " push_to_github

if [[ "$push_to_github" == "y" || "$push_to_github" == "Y" ]]; then
    # Prompt for GitHub repository name
    while true; do
        read -p "Enter the name of the GitHub repository: " repo_name
        if validate_repo_name "$repo_name"; then
            break
        fi
    done

    # Prompt for GitHub token
    while true; do
        read -p "Enter your GitHub token: " github_token
        if validate_github_token "$github_token"; then
            break
        fi
    done

    # Create remote repository on GitHub
    curl -u "$GITHUB_USERNAME:$github_token" https://api.github.com/user/repos -d "{\"name\":\"$repo_name\"}"

    # Add remote and push to GitHub
    git remote add origin "https://github.com/$GITHUB_USERNAME/$repo_name.git"
    git push -u origin master

    echo "Repository successfully pushed to GitHub!"
else
    echo "Repository setup complete. You can push to GitHub later if needed."
fi