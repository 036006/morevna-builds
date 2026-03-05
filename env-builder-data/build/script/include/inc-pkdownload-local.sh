
# SYNFIG_SOURCE_DIR - path to local source directory (set by environment)
# PK_DIRNAME

pkdownload() {
    local TARGET="$DOWNLOAD_PACKET_DIR/$PK_DIRNAME"
    echo "Copying local source from $SYNFIG_SOURCE_DIR to $TARGET"
    mkdir -p "$TARGET" || return 1
    rsync -a --delete --exclude='.git' "$SYNFIG_SOURCE_DIR/" "$TARGET/" || return 1
}
