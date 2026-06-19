#!/bin/bash

set -e

PUBLISH_DIR=$(cd `dirname "$0"`; pwd)

publish() {
    local NAME="$1"
    local TEMPLATE="$2" # Xxxxx-%VERSION%-%DATE%-%COMMIT%-xxxxx.xxx
    local FILEPATH="$3"
    local MASK="$4"
    local VERSION_FILE="$5"

    local VERSION=`cat "$VERSION_FILE" | cut -d'-' -f 1`
    local COMMIT=`cat "$VERSION_FILE" | cut -d'-' -f 2-`
    COMMIT="${COMMIT:0:5}"
    local DATE=`date -u +%Y.%m.%d`

    shopt -s nullglob
    local FILES=("$FILEPATH/"$MASK)
    shopt -u nullglob

    if [ ${#FILES[@]} -eq 0 ]; then
        echo "Cannot find package files by mask '$MASK' in '$FILEPATH'. Cancel."
        return 1
    fi

    local FILE=
    if [ ${#FILES[@]} -eq 1 ]; then
        FILE="${FILES[0]}"
    else
        local VERSION_MATCH=()
        local FILE_BASE=
        for FILE in "${FILES[@]}"; do
            FILE_BASE=$(basename "$FILE")
            if [[ "$FILE_BASE" == *"$VERSION"*"$COMMIT"* ]]; then
                VERSION_MATCH+=("$FILE")
            fi
        done

        if [ ${#VERSION_MATCH[@]} -eq 1 ]; then
            FILE="${VERSION_MATCH[0]}"
        elif [ ${#VERSION_MATCH[@]} -gt 1 ]; then
            FILE=$(ls -t "${VERSION_MATCH[@]}" | head -n 1)
            echo "Multiple package files match version/commit; using newest: $FILE"
        else
            FILE=$(ls -t "${FILES[@]}" | head -n 1)
            echo "Multiple package files matched mask; using newest: $FILE"
        fi
    fi

    if [ -z "$COMMIT" ]; then
        echo "Cannot find version, pheraps package not ready. Cancel."
        return 1
    fi

    local CHECK_MASK=` \
        echo "$TEMPLATE" \
        | sed "s|%VERSION%|$VERSION|g" \
        | sed "s|%DATE%|*|g" \
        | sed "s|%COMMIT%|$COMMIT|g" `
    local RM_MASK=` \
        echo "$TEMPLATE" \
        | sed "s|%VERSION%|*|g" \
        | sed "s|%DATE%|*|g" \
        | sed "s|%COMMIT%|*|g" `
    local CHECK=`ls "$PUBLISH_DIR/"$CHECK_MASK 2>/dev/null`
    if [ -z "$CHECK" ]; then
        local TARGET_NAME=` \
            echo "$TEMPLATE" \
            | sed "s|%VERSION%|$VERSION|g" \
            | sed "s|%DATE%|$DATE|g" \
            | sed "s|%COMMIT%|$COMMIT|g" `
        local TARGET="$PUBLISH_DIR/$TARGET_NAME"

        echo "Publish new version $VERSION-$COMMIT ($TARGET_NAME)"
        `rm -f "$PUBLISH_DIR/"$RM_MASK`
        cp "$FILE" "$TARGET"
        if [ -f "$PUBLISH_DIR/publish-$NAME.sh" ]; then
            echo "Call publish-$NAME.sh"
            "$PUBLISH_DIR/publish-$NAME.sh" "$TARGET"
        fi
    else
        echo "Version $VERSION-$COMMIT already published ($CHECK)"
    fi
}

publish $@
