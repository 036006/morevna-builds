
# PK_VERSION
# PK_DIRNAME
# SYNFIG_SOURCE_DIR

pkunpack() {
    # Copy from symlinked source to unpack dir (following symlinks, excluding .git)
    local SRC="$DOWNLOAD_PACKET_DIR/$PK_DIRNAME"
    local DEST="$UNPACK_PACKET_DIR/$PK_DIRNAME"
    rm -rf "$DEST" 2>/dev/null || true
    mkdir -p "$DEST" || return 1
    rsync -a --delete --exclude='.git' "$SRC/" "$DEST/" || return 1

    if [ -z "$PK_VERSION" ]; then
        PK_VERSION="$(pkhook_version)"
        [ $? -eq 0 ] || return 1
    fi

    # Get commit hash from local source .git if available
    local COMMIT="local"
    if [ -d "$SYNFIG_SOURCE_DIR/.git" ]; then
        COMMIT=$(cd "$SYNFIG_SOURCE_DIR" && git rev-parse HEAD 2>/dev/null) || COMMIT="local"
    fi
    echo "$PK_VERSION-$COMMIT" > "$UNPACK_PACKET_DIR/version-$NAME"
    [ $? -eq 0 ] || return 1
    return 0
}
