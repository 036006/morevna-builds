DEPS=""

PK_DIRNAME="lz4"
PK_URL="https://github.com/Cyan4973/$PK_DIRNAME.git"
PK_GIT_CHECKOUT="tags/v1.7.5"
PK_LICENSE_FILES="LICENSE lib/LICENSE programs/COPYING tests/COPYING examples/COPYING"

source $INCLUDE_SCRIPT_DIR/inc-pkall-git.sh

pkbuild() {
    cd "$BUILD_PACKET_DIR/$PK_DIRNAME"
    # Build only the library, not the tools. For cross-compilation to Windows,
    # the executable may not be created correctly, but we only need liblz4.a
    if ! PREFIX=${INSTALL_PACKET_DIR} make -j${THREADS} lib; then
        return 1
    fi
}

pkinstall() {
    cd "$BUILD_PACKET_DIR/$PK_DIRNAME"
    # Install only the library, not programs. This avoids trying to install
    # the lz4 executable which may not have been built for Windows cross-compile.
    if ! PREFIX=${INSTALL_PACKET_DIR} make -C lib install; then
        return 1
    fi
    
    # For Windows cross-compilation, remove .so files to prevent mingw linker 
    # from selecting ELF shared objects instead of static archives
    if [ "$BUILD_TARGET_WIN" = "1" ] || [ "$PLATFORM" = "win" ]; then
        rm -f "$INSTALL_PACKET_DIR/lib/"*.so* 2>/dev/null || true
    fi
}
