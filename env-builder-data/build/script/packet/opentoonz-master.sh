DEPS="jpeg-9b png-1.6.26 libjpeg-turbo-3.0.3 opencv-4.2.0 lz4-master lzo-2.10 lzma-5.2.3 glew-2.0.0 freeglut-3.0.0 superlu-5.2.1 openblas-0.3.3 boost-1.61.0 qt-5.11.3 mypaintlib-master"
DEPS_NATIVE="cmake-3.12.4"

PK_DIRNAME="opentoonz"
PK_URL="https://github.com/opentoonz/$PK_DIRNAME.git"
PK_LICENSE_FILES="README.md LICENSE.txt thirdparty/tiff-4.0.3/COPYRIGHT stuff/library/mypaint?brushes/Licenses.txt"

PK_CONFIGURE_OPTIONS=

source $INCLUDE_SCRIPT_DIR/inc-pkall-git.sh

if [ "$PLATFORM" = "linux" ]; then
    DEPS="$DEPS usb-1.0.20 sdl-2.0.5"
fi

pkhook_version() {
    local LOCAL_FILENAME="$PK_DIRNAME/toonz/sources/include/tversion.h"
    LANG=C LC_NUMERIC=C printf "%0.1f.%g\\n" \
      `cat "$LOCAL_FILENAME" | grep applicationVersion -m1 | cut -d "=" -f 2 | cut -d ";" -f 1 | cut -d "f" -f 1` \
      `cat "$LOCAL_FILENAME" | grep applicationRevision -m1 | cut -d "=" -f 2 | cut -d ";" -f 1` \
    || return 1
}

pkbuild() {
    local LOCAL_OPTIONS=
    local LOCAL_CMAKE_OPTIONS=
    local LOCAL_PNG_LIB="libpng16.so"
    local LOCAL_GLUT_LIB="libglut.so"
    if [ ! -z "$HOST" ]; then
        LOCAL_OPTIONS="--host=$HOST"
    fi
    if [ "$PLATFORM" = "win" ]; then
        LOCAL_CMAKE_OPTIONS="$LOCAL_CMAKE_OPTIONS -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=${HOST}-gcc -DCMAKE_CXX_COMPILER=${HOST}-g++"
        # When cross-compiling for Windows, CMake's UNIX variable is false, so
        # FindPkgConfig builds PKG_CONFIG_PATH from CMAKE_PREFIX_PATH using ';'
        # separators and skips the ';'->':' conversion. pkg-config then sees a
        # single invalid path and pkg_check_modules (liblzma, liblz4) fails.
        # Disable that rewrite so the already-correct env PKG_CONFIG_PATH is used.
        LOCAL_CMAKE_OPTIONS="$LOCAL_CMAKE_OPTIONS -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=FALSE"
        LOCAL_PNG_LIB="libpng16.dll.a"
        LOCAL_GLUT_LIB="libfreeglut.dll.a"

        # On win64 the SSE2 path is enabled (USE_SSE2 = _WIN32 && x64). Inside
        # the template rop_resample_rgbm_2<T> the line "TRaster32P rout32 = rout;"
        # fails to compile when instantiated with T=TPixelRGBM64, because
        # converting TRasterPT<TPixelRGBM64> to TRaster32P (TRasterPT<TPixelRGBM32>)
        # would need two user-defined conversions. Route it through the generic
        # TRasterP so it compiles for both instantiations (and yields a null
        # raster for the 64-bit case, correctly skipping the 32-bit SSE2 path).
        # Idempotent: the exact "= rout;" pattern no longer matches once patched.
        sed -i 's/TRaster32P rout32 = rout;/TRaster32P rout32 = (TRasterP)rout;/' \
            "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/sources/common/trop/tresample.cpp" || return 1
        
        # Fix duplicate explicit template instantiation in tnotanimatableparam.h
        # Keep the first occurrence and drop any later duplicates in a
        # line-content-based way (avoid brittle fixed line numbers).
        local _tna_file="$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/sources/include/tnotanimatableparam.h"
        awk 'BEGIN{n=0} {
            if ($0 == "template class DVAPI TNotAnimatableParam<std::wstring>;") {
                n++
                if (n > 1) next
            }
            print
        }' "$_tna_file" > "$_tna_file.tmp" || return 1
        mv "$_tna_file.tmp" "$_tna_file" || return 1

        # tnzext links the static Fortran BLAS (libblas.a) pulled in by SuperLU.
        # Those objects need the gfortran runtime (_gfortran_*) and libm. Append
        # the plain library names 'gfortran m' (CMake turns them into -lgfortran
        # -lm; using a leading dash here would make CMake treat them as missing
        # file targets and fail with "No rule to make target '-lgfortran'").
        # Idempotent: only matches the line that does not already contain gfortran.
        sed -i 's/\(\${SUPERLU_LIB} \${OPENBLAS_LIB}\) \(\${EXTRA_LIBS}\)/\1 gfortran m \2/' \
            "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/sources/tnzext/CMakeLists.txt" || return 1

        # toonzqt compiles ../tnztools/cursormanager.cpp into its own DLL (to
        # avoid a circular toonzqt<->tnztools dependency). On Windows the
        # cursormanager.h declarations use DV_IMPORT_API unless TNZTOOLS_EXPORTS
        # is defined, so toonzqt's own callers (schematicviewer.cpp) reference
        # __imp_setToolCursor which does not exist (the function is defined
        # locally, not imported) -> "undefined reference to
        # __imp__Z13setToolCursorP7QWidgeti". Define TNZTOOLS_EXPORTS for the
        # toonzqt target so setToolCursor/getToolCursor are treated as exported
        # (local) symbols. toonzqt only pulls cursormanager.h/cursors.h from
        # tnztools, so this does not affect any genuinely-imported symbols.
        sed -i 's/    -DTOONZQT_EXPORTS/    -DTOONZQT_EXPORTS\n    -DTNZTOOLS_EXPORTS/' \
            "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/sources/toonzqt/CMakeLists.txt" || return 1

        # The MinGW sysroot only ships a lowercase "windows.h"; a couple of
        # sources (stopmotion/webcam.cpp, toonz/penciltestpopup.cpp) include
        # <Windows.h> with a capital W, which fails on the case-sensitive Linux
        # build host ("fatal error: Windows.h: No such file or directory").
        # Lowercase the include so it resolves. (On real Windows the filesystem
        # is case-insensitive, so this is a no-op there.)
        grep -rlZ '#include <Windows.h>' "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/sources" 2>/dev/null \
            | xargs -0 -r sed -i 's/#include <Windows.h>/#include <windows.h>/' || return 1

        # stopmotion/webcam.cpp and toonz/penciltestpopup.cpp call the Media
        # Foundation device-enumeration function MFEnumDeviceSources, which
        # MinGW-w64's mfidl.h does not declare -> "not declared in this scope".
        # The symbol IS exported by mf.dll (present in libmf.a). Insert the
        # prototype after the #include <mfidl.h> line in every file that uses it.
        # Idempotent: grep check prevents double-insertion.
        for _f in $(grep -rlZ '<mfidl.h>' "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/sources" 2>/dev/null | tr '\0' ' '); do
            if ! grep -q 'MFEnumDeviceSources(IMFAttributes' "$_f"; then
                sed -i '/#include <mfidl.h>/a extern "C" HRESULT __stdcall MFEnumDeviceSources(IMFAttributes *pAttributes, IMFActivate ***pppSourceActivate, UINT32 *pcSourceActivate);' \
                    "$_f" || return 1
            fi
        done

        # The OpenToonz target links the Media Foundation libs only through MSVC
        # "#pragma comment(lib, ...)" directives in webcam.cpp, which GCC/MinGW
        # ignores. The cross build therefore fails to resolve MFEnumDeviceSources,
        # MFCreateAttributes, MFStartup, etc. Add the corresponding MinGW import
        # libraries to the OpenToonz link line (next to the existing strmiids).
        # Idempotent: only matches the line that does not already contain mfplat.
        sed -i 's/\(Qt5::WinMain -lstrmiids\) \(-mwindows\)/\1 -lmfplat -lmf -lmfreadwrite -lmfuuid \2/' \
            "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/sources/toonz/CMakeLists.txt" || return 1
    fi

    cd "$BUILD_PACKET_DIR/$PK_DIRNAME/thirdparty/tiff-4.0.3"
    CFLAGS="$CFLAGS -fPIC" CXXFLAGS="$CXXFLAGS -fPIC" ./configure --disable-jbig $LOCAL_OPTIONS || return 1 
    make clean
    make -j${THREADS} || return 1

    rm -rf "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/build"
    mkdir -p "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/build"
    cd "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/build"
    
    if [ "$PLATFORM" = "linux" ]; then
        LOCAL_CFLAGS=" -fpermissive"
    fi
    if [ "$PLATFORM" = "win" ]; then
        # The OpenToonz sources rely on a few implicit downcasts (e.g.
        # "TVectorImageP vi = img->cloneImage();" where cloneImage() returns
        # TImage*). GCC rejects these as errors by default; the Linux build
        # already relaxes them with -fpermissive. The cross (mingw) build needs
        # the same relaxation, otherwise toonzlib fails with
        # "invalid conversion from 'TImage*' to 'TVectorImage*'".
        #
        # -fcommon: GCC 10 defaults to -fno-common, which turns tentative
        # definitions in headers (e.g. "double Avl_Dummy[];" in toonz4.6/avl.h,
        # included by avl.c and tiio_plt.cpp) into multiple-definition link
        # errors for the "image" library. Restore the pre-GCC10 -fcommon
        # behaviour so these legacy globals collapse into one definition.
        LOCAL_CFLAGS=" -fpermissive -fcommon"
    fi
    
    if ! check_packet_function $NAME build.configure; then
        if ! CFLAGS="$CFLAGS $LOCAL_CFLAGS" CXXFLAGS="$CXXFLAGS $LOCAL_CFLAGS" \
              PKG_CONFIG_PATH="$ENVDEPS_PACKET_DIR/lib/pkgconfig:$PKG_CONFIG_PATH" \
              cmake \
              -DCMAKE_PREFIX_PATH="$ENVDEPS_PACKET_DIR" \
              -DCMAKE_MODULE_PATH="$ENVDEPS_NATIVE_PACKET_DIR/share/cmake-3.6.2/Modules" \
              -DCMAKE_INSTALL_PREFIX="$INSTALL_PACKET_DIR" \
              -DPNG_PNG_INCLUDE_DIR="$ENVDEPS_PACKET_DIR/include" \
              -DPNG_LIBRARY="$ENVDEPS_PACKET_DIR/lib/$LOCAL_PNG_LIB" \
              -DGLUT_LIB="$ENVDEPS_PACKET_DIR/lib/$LOCAL_GLUT_LIB" \
              -DSUPERLU_INCLUDE_DIR="$ENVDEPS_PACKET_DIR/include/superlu" \
              -DSUPERLU_LIBRARY="$ENVDEPS_PACKET_DIR/lib/libsuperlu.a;$ENVDEPS_PACKET_DIR/lib/libblas.a" \
              $LOCAL_CMAKE_OPTIONS \
              $PK_CONFIGURE_OPTIONS \
              ../sources; \
        then
            return 1
        fi
        set_done $NAME build.configure
    fi
    
    make -j${THREADS} || return 1
}

pkinstall() {
    cd "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/build"
    make install || return 1
    if [ "$PLATFORM" = "win" ]; then
        true
        #cp --remove-destination "$BUILD_PACKET_DIR/$PK_DIRNAME/thirdparty/tiff-4.0.3/libtiff/.libs/libtiff-5.dll" "$INSTALL_PACKET_DIR/bin/" || return 1
        #cp --remove-destination "$BUILD_PACKET_DIR/$PK_DIRNAME/thirdparty/tiff-4.0.3/libtiff/.libs/libtiffxx-5.dll" "$INSTALL_PACKET_DIR/bin/" || return 1
    else
        cp --remove-destination "$FILES_PACKET_DIR/launch-opentoonz.sh" "$INSTALL_PACKET_DIR/bin/opentoonz" || return 1
        cp --remove-destination $BUILD_PACKET_DIR/$PK_DIRNAME/thirdparty/tiff-4.0.3/libtiff/.libs/libtiff.so* "$INSTALL_PACKET_DIR/lib" || return 1
        cp --remove-destination $BUILD_PACKET_DIR/$PK_DIRNAME/thirdparty/tiff-4.0.3/libtiff/.libs/libtiffxx.so* "$INSTALL_PACKET_DIR/lib" || return 1
    fi

    if [ "$PLATFORM" = "win" ]; then
        local TARGET="$INSTALL_PACKET_DIR/bin/"
        
        # GCC runtime DLLs — Debian mingw-w64 layout (not the old Fedora
        # /usr/local/HOST/sys-root layout the original script assumed).
        local GCC_DIR="/usr/lib/gcc/$HOST/10-posix"
        cp "$GCC_DIR"/libgcc_s_seh-1.dll   "$TARGET" || return 1
        cp "$GCC_DIR"/libstdc++-6.dll      "$TARGET" || return 1
        cp "$GCC_DIR"/libgfortran-5.dll    "$TARGET" || return 1
        # libquadmath may not be present for all targets; ignore if absent.
        cp "$GCC_DIR"/libquadmath*.dll     "$TARGET" 2>/dev/null || true

        local MINGW_DIR="/usr/$HOST"
        cp "$MINGW_DIR/lib"/libwinpthread-1.dll "$TARGET" || return 1
        cp "$MINGW_DIR/bin"/libintl-8.dll       "$TARGET" || return 1
        cp "$MINGW_DIR/bin"/libiconv-2.dll      "$TARGET" || return 1
        # libgettextlib may not ship as a standalone DLL; ignore if absent.
        cp "$MINGW_DIR/bin"/libgettextlib*.dll  "$TARGET" 2>/dev/null || true

        # add icon
        cp "$BUILD_PACKET_DIR/$PK_DIRNAME/toonz/sources/toonz/toonz.ico" "$TARGET" || return 1
    else
        local TARGET="$INSTALL_PACKET_DIR/lib/"
        copy_system_gcc_libs               "$TARGET" || return 1
        copy_system_lib libudev            "$TARGET" || return 1
        copy_system_lib libicui18n         "$TARGET" || return 1
        copy_system_lib libicuuc           "$TARGET" || return 1
        copy_system_lib libicudata         "$TARGET" || return 1
    fi
}

pkhook_postlicense() {
    local TARGET="$LICENSE_PACKET_DIR"
    if [ "$PLATFORM" = "win" ]; then
        local LOCAL_DIR="/usr/$HOST/sys-root/mingw/bin/"
        copy_system_license gcc                    "$TARGET" || return 1
        copy_system_license mingw-w64              "$TARGET" || return 1
        copy_system_license gettext                "$TARGET" || return 1
        copy_system_license iconv                  "$TARGET" || return 1
    else
        copy_system_license gcc                    "$TARGET" || return 1
        copy_system_license libudev                "$TARGET" || return 1
    fi
}
