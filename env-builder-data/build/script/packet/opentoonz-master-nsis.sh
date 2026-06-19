DEPS="opentoonz-master"
DEPS_NATIVE="nsis-3.08"

pkfunc_register_file() {
    local FILE=$1
    local WIN_FILE=$(echo "$FILE" | sed "s|\/|\\\\|g")
    ! [ -L "$FILE" ] || return 0

    # NSIS 3.08 in this environment may segfault on UTF-8 path components.
    # Skip non-ASCII entries during list generation.
    if ! printf '%s' "$FILE" | LC_ALL=C grep -Eq '^[ -~]+$'; then
        echo "skip path (non-ascii): $FILE"
        return 0
    fi

    # On case-insensitive Windows filesystems the stray top-level "LICENSE"
    # file (shipped by one of the dependencies, e.g. OpenCV) collides with the
    # aggregated third-party "license/" directory. NSIS writes the file first,
    # then CreateDirectory "$INSTDIR\license" fails because the name is already
    # taken, and every "license\license-*" write aborts with
    # "Error opening file for writing". Install the stray file as LICENSE.txt
    # so both can coexist.
    if [ "$FILE" = "./LICENSE" ]; then
        echo "skip case-collision file (install as LICENSE.txt): $FILE"
        echo "File \"/oname=LICENSE.txt\" \"LICENSE\"" >> "files-install.nsh"
        echo "Delete \"\$INSTDIR\\LICENSE.txt\""       >> "files-uninstall.nsh"
        return 0
    fi

    # NSIS 3.08 crashes while packaging the large stuff/doc payload in this
    # environment. Skip docs to keep installer generation reliable.
    if [ "$FILE" = "./share/opentoonz/stuff/doc" ]; then
        echo "skip doc subtree (nsis instability): $FILE"
        return 0
    fi

    # NSIS 3.08 on this build image crashes or misparses when File commands
    # recurse through non-ASCII path components (e.g. Español, Français).
    # Package only ASCII-safe locale directory names to keep installer
    # generation stable.
    if [ "$FILE" = "./share/opentoonz/stuff/config/loc" ]; then
        local LOC_SUBDIR=
        local LOC_NAME=
        echo "CreateDirectory \"\$STUFFDIR\\config\\loc\"" >> "files-stuff-install.nsh"
        for LOC_SUBDIR in "$FILE"/*; do
            [ -d "$LOC_SUBDIR" ] || continue
            LOC_NAME=$(basename "$LOC_SUBDIR")
            if printf '%s' "$LOC_NAME" | grep -Eq '^[A-Za-z0-9._ -]+$'; then
                if ! pkfunc_register_file "$LOC_SUBDIR"; then
                    return 1
                fi
            else
                echo "skip locale directory (non-ascii): $LOC_NAME"
            fi
        done
        echo "RMDir \"\$STUFFDIR\\config\\loc\"" >> "files-stuff-uninstall.nsh"
        return 0
    fi

    if [ "${FILE:0:8}" = "./files-" ]; then
        true # skip
    elif [ "${FILE:0:24}" = "./share/opentoonz/stuff/" ]; then
        if [ -d "$FILE" ]; then
            echo "CreateDirectory \"\$STUFFDIR\\${WIN_FILE:24}\""   >> "files-stuff-install.nsh"
            foreachfile "$FILE" pkfunc_register_file
            echo "RMDir \"\$STUFFDIR\\${WIN_FILE:24}\""             >> "files-stuff-uninstall.nsh"
        else
            echo "File \"/oname=${WIN_FILE:24}\" \"${WIN_FILE:2}\"" >> "files-stuff-install.nsh"
            echo "Delete \"\$STUFFDIR\\${WIN_FILE:24}\""            >> "files-stuff-uninstall.nsh"
        fi
    elif [ "${FILE:0:2}" = "./" ]; then
        if [ -d "$FILE" ]; then
            echo "CreateDirectory \"\$INSTDIR\\${WIN_FILE:2}\""     >> "files-install.nsh"
            foreachfile "$FILE" pkfunc_register_file
            echo "RMDir \"\$INSTDIR\\${WIN_FILE:2}\""               >> "files-uninstall.nsh" 
        else
            echo "File \"/oname=${WIN_FILE:2}\" \"${WIN_FILE:2}\""  >> "files-install.nsh"
            echo "Delete \"\$INSTDIR\\${WIN_FILE:2}\""              >> "files-uninstall.nsh" 
        fi
    else
        foreachfile $FILE pkfunc_register_file
    fi
}

pkinstall_release() {
    # create temporary dir
    rm -rf "$INSTALL_RELEASE_PACKET_DIR/installer"
    mkdir -p "$INSTALL_RELEASE_PACKET_DIR/installer"
    cd "$INSTALL_RELEASE_PACKET_DIR/installer" || return 1

    # copy files
    copy "$ENVDEPS_RELEASE_PACKET_DIR" "./" || return 1

    # get version
    local LOCAL_VERSION_FULL=$(cat $ENVDEPS_RELEASE_PACKET_DIR/version-opentoonz-*)
    local LOCAL_VERSION=$(echo "$LOCAL_VERSION_FULL" | cut -d - -f 1)
    local LOCAL_VERSION2=$(echo "$LOCAL_VERSION" | cut -d . -f -2)
    local LOCAL_COMMIT=$(echo "$LOCAL_VERSION_FULL" | cut -d - -f 2)

    # create file lists
    echo "create file lists"
    pkfunc_register_file .
    echo "created"

    # copy NSIS configuration
    cp "$FILES_PACKET_DIR/opentoonz.nsi" "./" || return 1

    # create config.nsh (see opentoons.nsi)
    cat > config.nsh << EOF
!define PK_NAME         "OpenToonz" 
!define PK_NAME_FULL    "OpenToonz Morevna Edition (${ARCH}bit)"
!define PK_ARCH         "${ARCH}"
!define PK_VERSION      "${LOCAL_VERSION2}"
!define PK_VERSION_FULL "${LOCAL_VERSION}-${LOCAL_COMMIT:0:5}" 
!define PK_EXECUTABLE   "bin\\\${PK_NAME}.exe"
!define PK_ICON         "bin\\toonz.ico" 
EOF

    # let's go
    makensis opentoonz.nsi || return 1

    # remove temporary dir
    cd "$INSTALL_RELEASE_PACKET_DIR" || return 1
    mv installer/*.exe ./ || return 1
    rm -rf "installer"
}
