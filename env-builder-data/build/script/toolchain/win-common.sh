#!/bin/bash

# TC_HOST should be set before inclusion of this file

export CROSS_TRIPLE="${TC_HOST}"
export CROSS_ROOT="/usr/${CROSS_TRIPLE}"

# Set CC, CXX, AR for cross-compilation. Needed for Makefile-based builds.
export TC_CC="${CROSS_TRIPLE}-gcc"
export TC_CXX="${CROSS_TRIPLE}-g++"
export TC_AR="${CROSS_TRIPLE}-ar"
export TC_RANLIB="${CROSS_TRIPLE}-ranlib"
# Cross Fortran compiler. Needed so Makefile-based builds (e.g. superlu, blas)
# produce Windows PE/COFF objects instead of native ELF. Without this, the
# Fortran/C objects are ELF and the mingw linker silently fails to resolve
# their symbols (e.g. undefined reference to intMalloc/superlu_malloc).
export TC_FORTRAN="${CROSS_TRIPLE}-gfortran"
export TC_FC="${CROSS_TRIPLE}-gfortran"
export TC_F77="${CROSS_TRIPLE}-gfortran"

#export TC_PATH="${CROSS_ROOT}/bin:$INITIAL_PATH"
export TC_LD_LIBRARY_PATH="$CROSS_ROOT/lib:$INITIAL_LD_LIBRARY_PATH"

export TC_LDFLAGS=" -L${CROSS_ROOT}/lib -L/usr/lib/gcc/${CROSS_TRIPLE}/10-posix/ -L/usr/lib/gcc/${CROSS_TRIPLE}/6.3-posix/ $INITIAL_LDFLAGS"

export WINEPATH_BASE="/usr/${CROSS_TRIPLE}/bin/;/usr/lib/gcc/${CROSS_TRIPLE}/10-posix;/usr/${CROSS_TRIPLE}/lib/"
export WINEPATH="$WINEPATH_BASE"

# Optional c/c++ flags from Fedora MinGW:
#   -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions --param=ssp-buffer-size=4
#
#   -Wall -g            - don't need
#   -02 -fexceptions    - should be defined in packet if need
#   -pipe               - not compatible with windres (used in lzma packet)
#
#   -Wp,-D_FORTIFY_SOURCE=2 --param=ssp-buffer-size=4
#                       - may be better, but work fine without it, will added when any problem raised
#
# So no extra options for now
export TC_EXTRA_CPP_OPTIONS=""
export TC_CFLAGS=" $TC_EXTRA_CPP_OPTIONS $INITIAL_CFLAGS"
export TC_CPPFLAGS=" $TC_EXTRA_CPP_OPTIONS $INITIAL_CPPFLAGS"
export TC_CXXFLAGS=" $TC_EXTRA_CPP_OPTIONS $INITIAL_CXXFLAGS"
unset TC_EXTRA_CPP_OPTIONS

export TC_PKG_CONFIG_PATH=""
#export TC_PKG_CONFIG_LIBDIR="$CROSS_ROOT/lib"
#export TC_CMAKE_INCLUDE_PATH="${CROSS_ROOT}/include:$INITIAL_CMAKE_INCLUDE_PATH"
# Add the mingw sysroot lib dir to CMAKE_LIBRARY_PATH so find_library() can
# locate the toolchain libraries (opengl32 -> GL_LIB, glu32 -> GLU_LIB,
# pthread -> PTHREAD_LIBRARY) used by OpenToonz. Without this they resolve to
# NOTFOUND and cmake configure fails.
export TC_CMAKE_LIBRARY_PATH="${CROSS_ROOT}/lib:$INITIAL_CMAKE_LIBRARY_PATH"

#export TC_ACLOCAL_PATH="/usr/share/aclocal"
#if [ ! -z "$INITIAL_ACLOCAL_PATH" ]; then
#    export TC_ACLOCAL_PATH="$INITIAL_ACLOCAL_PATH:$TC_ACLOCAL_PATH"
#fi

unset CROSS_ROOT

