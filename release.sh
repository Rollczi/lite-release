#!/bin/bash
set -e

# --- Helpers ---
log() { echo -e "\033[0;34m[Lite-Release]\033[0m $1"; }
error() { echo -e "\033[0;31m[Lite-Release] ERROR: $1\033[0m"; exit 1; }

# 1. Git Configuration
log "Configuring Git..."
git config --global user.name "$INPUT_GIT_USER"
git config --global user.email "$INPUT_GIT_EMAIL"

# 2. Ensure Version File Exists
if [ ! -f "$INPUT_VERSION_FILE" ]; then
  error "Version file not found at: $INPUT_VERSION_FILE. Please create this file before running the release action."
fi

# 3. Read Current Versions
OLD_RELEASE=$(jq -r '.versionRelease' "$INPUT_VERSION_FILE")
OLD_SNAPSHOT=$(jq -r '.versionSnapshot' "$INPUT_VERSION_FILE")

# 4. Calculate New Versions
IFS='.' read -ra V <<< "$OLD_RELEASE"
case "$INPUT_BUMP" in
  major) V[0]=$((V[0] + 1)); V[1]=0; V[2]=0 ;;
  minor) V[1]=$((V[1] + 1)); V[2]=0 ;;
  *)     V[2]=$((V[2] + 1)) ;;
esac

NEW_RELEASE="${V[0]}.${V[1]}.${V[2]}"
NEXT_SNAPSHOT="${V[0]}.${V[1]}.$((V[2] + 1))-SNAPSHOT"

# Prepare dynamic messages
RELEASE_TITLE="${INPUT_GITHUB_RELEASE_TITLE//"{VERSION}"/$NEW_RELEASE}"
RELEASE_COMMIT_MESSAGE="${INPUT_COMMIT_RELEASE//"{VERSION}"/$NEW_RELEASE}"
SNAPSHOT_COMMIT_MESSAGE="${INPUT_COMMIT_SNAPSHOT//"{VERSION}"/$NEXT_SNAPSHOT}"

log "Releasing: $NEW_RELEASE"
log "Next Snapshot: $NEXT_SNAPSHOT"

# 5. UPDATE PHASE: RELEASE
# Here we update EVERYTHING defined in commit_release_update_files (including README)
log "Updating files for Release phase..."
shopt -s globstar
IFS=',' read -ra R_PATTERNS <<< "$INPUT_COMMIT_RELEASE_FILES"
for pattern in "${R_PATTERNS[@]}"; do
    pattern=$(echo "$pattern" | xargs)
    for file in $pattern; do
        if [[ -e "$file" && -f "$file" && ! "$file" =~ \.git/ ]]; then
            log "Updating $file for release..."
            sed -i "s#\b$OLD_RELEASE\b#$NEW_RELEASE#g" "$file"
            sed -i "s#\b$OLD_SNAPSHOT\b#$NEW_RELEASE#g" "$file"
        fi
    done
done

log "Updating version.json for release..."
jq ".versionRelease = \"$NEW_RELEASE\" | .versionSnapshot = \"$OLD_SNAPSHOT\"" "$INPUT_VERSION_FILE" > t.json && mv t.json "$INPUT_VERSION_FILE"

# 6. Commit Release & Tag
git add .
git commit -m "$RELEASE_COMMIT_MESSAGE"
git tag -a "v$NEW_RELEASE" -m "$RELEASE_TITLE"
git push origin HEAD --tags

# 7. Create GitHub Release
log "Creating GitHub Release: $RELEASE_TITLE"
RELEASE_FLAGS=(--title "$RELEASE_TITLE" --generate-notes)

# Process template if provided and exists
if [ -n "$INPUT_GITHUB_RELEASE_TEMPLATE" ] && [ -f "$INPUT_GITHUB_RELEASE_TEMPLATE" ]; then
    log "Using release notes template: $INPUT_GITHUB_RELEASE_TEMPLATE"
    sed "s#{VERSION}#$NEW_RELEASE#g" "$INPUT_GITHUB_RELEASE_TEMPLATE" > processed_notes.md
    RELEASE_FLAGS+=(--notes-file processed_notes.md)
fi

gh release create "v$NEW_RELEASE" "${RELEASE_FLAGS[@]}"
[ -f processed_notes.md ] && rm processed_notes.md

# 8. UPDATE PHASE: SNAPSHOT
# Here we only update files defined in commit_snapshot_update_files (usually no README)
log "Updating files for Snapshot phase..."
IFS=',' read -ra S_PATTERNS <<< "$INPUT_COMMIT_SNAPSHOT_FILES"
for pattern in "${S_PATTERNS[@]}"; do
    pattern=$(echo "$pattern" | xargs)
    for file in $pattern; do
        if [[ -e "$file" && -f "$file" && ! "$file" =~ \.git/ ]]; then
            log "Updating $file for snapshot..."
            # We replace NEW_RELEASE with NEXT_SNAPSHOT only in these specific files
            sed -i "s#\b$NEW_RELEASE\b#$NEXT_SNAPSHOT#g" "$file"
        fi
    done
done

# 9. Update JSON for next snapshot
log "Updating version.json for snapshot..."
jq ".versionRelease = \"$NEW_RELEASE\" | .versionSnapshot = \"$NEXT_SNAPSHOT\"" "$INPUT_VERSION_FILE" > t.json && mv t.json "$INPUT_VERSION_FILE"

# 10. Commit Snapshot
git add .
git commit -m "$SNAPSHOT_COMMIT_MESSAGE"
git push origin HEAD

log "Done! $RELEASE_TITLE published."