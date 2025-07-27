
#!/bin/bash

set -euo pipefail

# Ensure GH is authenticated
gh auth status > /dev/null

echo "Fetching artifact usage for all accessible repositories..."
echo ""

# Arrays to store data
declare -a all_artifacts=()
declare -A repo_totals=()
declare -A latest_releases=()

USERNAME=$(gh api user | jq -r .login)

# Function to get latest release tag for a repository
function get_latest_release() {
    local full_repo="$1"
    local release_tag
    
    release_tag=$(gh api "/repos/$full_repo/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' || echo "")
    if [ -n "$release_tag" ]; then
        latest_releases["$full_repo"]="$release_tag"
    fi
}

# Function to check if artifact is associated with latest release
function is_latest_release_artifact() {
    local full_repo="$1"
    local artifact_name="$2"
    
    local release_tag="${latest_releases[$full_repo]:-}"
    
    if [ -z "$release_tag" ]; then
        return 1
    fi
    
    # Simple heuristic: if artifact name contains release tag
    if [[ "$artifact_name" == *"$release_tag"* ]]; then
        return 0
    fi
    
    return 1
}

# Function to collect artifact usage for a single repository
function process_repo() {
    local full_repo="$1"
    echo "🔍 Checking $full_repo..."

    # Get latest release info
    get_latest_release "$full_repo"

    local artifact_json
    artifact_json=$(gh api -H "Accept: application/vnd.github+json" \
        "/repos/$full_repo/actions/artifacts?per_page=100" --paginate 2>/dev/null || echo "")

    if [ -z "$artifact_json" ]; then
        return
    fi

    local repo_total_mb=0

    # Process artifacts
    while IFS= read -r artifact; do
        local artifact_id artifact_name artifact_size_bytes created_at pr_number size_mb
        
        artifact_id=$(echo "$artifact" | jq -r '.id')
        artifact_name=$(echo "$artifact" | jq -r '.name')
        artifact_size_bytes=$(echo "$artifact" | jq -r '.size_in_bytes')
        created_at=$(echo "$artifact" | jq -r '.created_at')
        pr_number=$(echo "$artifact" | jq -r '.workflow_run.pull_requests[0].number // empty')

        # Skip if no valid size or zero bytes
        if [[ "$artifact_size_bytes" =~ ^[0-9]+$ ]] && [ "$artifact_size_bytes" -gt 0 ]; then
            size_mb=$(echo "scale=2; $artifact_size_bytes / 1024 / 1024" | bc)
            
            # Store artifact info: repo|id|name|size_mb|created_at|pr_number|size_bytes
            all_artifacts+=("$full_repo|$artifact_id|$artifact_name|$size_mb|$created_at|$pr_number|$artifact_size_bytes")
            
            repo_total_mb=$(echo "$repo_total_mb + $size_mb" | bc)
        fi
    done < <(echo "$artifact_json" | jq -c '.artifacts[]')
    
    # Store repo total if it has artifacts
    if (( $(echo "$repo_total_mb > 0" | bc -l) )); then
        repo_totals["$full_repo"]="$repo_total_mb"
    fi
}

# Function to process all repositories
function process_all_repos() {
    # Get all personal repositories
    echo "📂 Getting personal repositories for $USERNAME..."
    
    while IFS= read -r repo; do
        [ -n "$repo" ] && process_repo "$repo"
    done < <(gh repo list "$USERNAME" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner')

    # Get all organizations and their repos
    echo ""
    echo "👥 Fetching organizations..."
    
    while IFS= read -r org; do
        if [ -n "$org" ]; then
            echo "📂 Repos in org: $org"
            while IFS= read -r repo; do
                [ -n "$repo" ] && process_repo "$repo"
            done < <(gh repo list "$org" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner')
        fi
    done < <(gh api user/orgs --paginate | jq -r '.[].login')
}

# Function to display artifacts by repository
function display_artifacts() {
    if [ ${#repo_totals[@]} -eq 0 ]; then
        echo "No artifacts found."
        return
    fi
    
    echo ""
    echo "Artifact Usage Summary:"
    echo ""
    
    # Sort repositories by total size (largest first)
    for repo in "${!repo_totals[@]}"; do
        echo "$repo ${repo_totals[$repo]}"
    done | sort -k2 -nr | while read -r repo total; do
        printf "📂 %-50s %s MB\n" "$repo" "$total"
    done
}

# Function to calculate total storage
function calculate_total_storage() {
    local total_bytes=0
    
    for artifact_data in "${all_artifacts[@]}"; do
        local size_bytes
        size_bytes=$(echo "$artifact_data" | cut -d'|' -f7)
        if [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
            total_bytes=$((total_bytes + size_bytes))
        fi
    done
    
    local total_mb
    total_mb=$(echo "scale=2; $total_bytes / 1024 / 1024" | bc)
    echo "🧮 Total Storage Used: $total_mb MB"
}

# Function to review and delete artifacts
function review_and_delete() {
    if [ ${#all_artifacts[@]} -eq 0 ]; then
        echo "No artifacts to review for deletion."
        return
    fi
    
    echo ""
    echo "Reviewing artifacts for deletion..."
    echo ""
    
    # Sort artifacts by size (largest first)
    IFS=$'\n' sorted_artifacts=($(printf '%s\n' "${all_artifacts[@]}" | sort -t'|' -k4 -nr))
    
    for artifact_data in "${sorted_artifacts[@]}"; do
        IFS='|' read -r repo artifact_id artifact_name size_mb created_at pr_number size_bytes <<< "$artifact_data"
        
        # Check if this artifact is associated with the latest release
        if is_latest_release_artifact "$repo" "$artifact_name"; then
            echo "⏭️  Skipping $artifact_name in $repo (associated with latest release)"
            continue
        fi
        
        # Display artifact info
        echo ""
        echo "Artifact in repo: $repo"
        echo "Artifact Name: $artifact_name"
        echo "Size: $size_mb MB"
        echo "Created: $created_at"
        if [ -n "$pr_number" ] && [ "$pr_number" != "empty" ]; then
            echo "Associated with PR #$pr_number"
        fi
        echo "View artifact: https://github.com/$repo/actions"
        
        # Prompt for deletion
        read -p "Do you want to delete this artifact? (y/n/q to quit): " choice
        
        case "$choice" in
            y|Y|yes|YES)
                if gh api --method DELETE "/repos/$repo/actions/artifacts/$artifact_id" 2>/dev/null; then
                    echo "✅ Artifact $artifact_name deleted."
                else
                    echo "❌ Failed to delete artifact $artifact_name."
                fi
                ;;
            q|Q|quit|QUIT)
                echo "Exiting artifact review."
                return
                ;;
            *)
                echo "⏭️  Skipping artifact $artifact_name"
                ;;
        esac
    done
}

# Main execution
echo "Starting artifact audit..."
process_all_repos
display_artifacts
calculate_total_storage
review_and_delete
