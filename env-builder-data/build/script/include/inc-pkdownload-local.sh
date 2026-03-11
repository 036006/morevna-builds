
# SYNFIG_SOURCE_DIR - path to local source directory (set by environment)
# PK_DIRNAME

pkdownload() {
    local TARGET="$DOWNLOAD_PACKET_DIR/$PK_DIRNAME"
    echo "Linking local source $SYNFIG_SOURCE_DIR -> $TARGET"
    # Use a symlink so sha512dir can use the fast .git-based hash
    rm -rf "$TARGET" 2>/dev/null || true
    ln -sf "$SYNFIG_SOURCE_DIR" "$TARGET" || return 1
}
