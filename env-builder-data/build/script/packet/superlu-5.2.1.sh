DEPS="blas-3.7.0"

PK_DIRNAME="superlu-5.2.1"
PK_ARCHIVE="v5.2.1.tar.gz"
PK_URL="https://github.com/xiaoyeli/superlu/archive/$PK_ARCHIVE"

source $INCLUDE_SCRIPT_DIR/inc-pkall-default.sh

pkbuild() {
    cd "$BUILD_PACKET_DIR/$PK_DIRNAME"

rm -f make.inc
cat > make.inc << EOF 	
SuperLUroot  = $BUILD_PACKET_DIR/$PK_DIRNAME
SUPERLULIB   = \$(SuperLUroot)/lib/libsuperlu.a
BLASDEF      = -DUSE_VENDOR_BLAS
BLASLIB      = \$(LDFLAGS) -lblas -lgfortran
TMGLIB       = libtmglib.a
LIBS         = \$(SUPERLULIB) \$(BLASLIB)
ARCH         = ${AR:-ar}
ARCHFLAGS    = cr
RANLIB       = ${RANLIB:-ranlib}
CC           = ${CC:-gcc}
CFLAGS       = -O3 -fPIC
NOOPTS       = -fPIC
FORTRAN      = ${FORTRAN:-${FC:-gfortran}}
FFLAGS       = -O2 -fPIC
LOADER       = \$(CC)
LOADOPTS     =
CDEFS        = -DAdd_
EOF
	
	cp --remove-destination "$FILES_PACKET_DIR/mc64ad.c" "$BUILD_PACKET_DIR/$PK_DIRNAME/SRC/" || return 1
	# Remove any stale object files / archives from a previous build so that
	# 'make lib' actually recompiles the sources with the current compiler.
	# Without this, a prior native (ELF) build leaves *.o behind and 'make lib'
	# just re-archives the old ELF objects, producing a libsuperlu.a that the
	# mingw linker cannot use (undefined references to intMalloc, etc.).
	find "$BUILD_PACKET_DIR/$PK_DIRNAME" -name '*.o' -delete 2>/dev/null || true
	rm -f "$BUILD_PACKET_DIR/$PK_DIRNAME/lib/"*.a 2>/dev/null || true
	make lib || return 1
}

pkinstall() {
	cp --remove-destination -r "$BUILD_PACKET_DIR/$PK_DIRNAME/lib" "$INSTALL_PACKET_DIR" || return 1
	mkdir -p "$INSTALL_PACKET_DIR/include/superlu"
	cp --remove-destination $BUILD_PACKET_DIR/$PK_DIRNAME/SRC/*.h "$INSTALL_PACKET_DIR/include/superlu" || return 1
}
