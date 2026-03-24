
# SYNFIG_SOURCE_DIR - path to local source directory (set by environment)
# PK_DIRNAME

pkdownload() {
    # Remove any leftover symlink or directory from previous runs
    rm -rf "$DOWNLOAD_PACKET_DIR/$PK_DIRNAME" 2>/dev/null || true

    # Write source state as a regular file (no dotfile prefix so ls -1 / sha512dir can see it)
    # sha512dir hashes this file to detect changes between builds
    local STATE_FILE="$DOWNLOAD_PACKET_DIR/source-state"
    echo "Capturing source state from $SYNFIG_SOURCE_DIR"
    if [ -d "$SYNFIG_SOURCE_DIR/.git" ]; then
        (cd "$SYNFIG_SOURCE_DIR" && git rev-parse HEAD && git status -s && git diff) \
            > "$STATE_FILE" || return 1
    else
        find "$SYNFIG_SOURCE_DIR" -not -path '*/.git/*' -type f -printf '%T@ %p\n' \
            | sort > "$STATE_FILE" || return 1
    fi
}
