
# PK_VERSION
# PK_DIRNAME
# SYNFIG_SOURCE_DIR

pkunpack() {
    if ! (copy "$DOWNLOAD_PACKET_DIR" "$UNPACK_PACKET_DIR" \
     && rm -f -r "$UNPACK_PACKET_DIR/$PK_DIRNAME/.git"); then
        return 1
    fi

    if [ -z "$PK_VERSION" ]; then
        PK_VERSION="$(pkhook_version)"
        [ $? -eq 0 ] || return 1
    fi

    # Try to get commit hash from the original local source directory
    local COMMIT="local"
    if [ -d "$SYNFIG_SOURCE_DIR/.git" ]; then
        COMMIT=$(cd "$SYNFIG_SOURCE_DIR" && git rev-parse HEAD 2>/dev/null) || COMMIT="local"
    fi
    echo "$PK_VERSION-$COMMIT" > "$UNPACK_PACKET_DIR/version-$NAME"
    [ $? -eq 0 ] || return 1
    return 0
}
