source $setup

tar -xf $src
mv cctools-port-* cctools-port

cd cctools-port

for patch in $patches; do
  echo applying patch $patch
  patch -p1 -i $patch
done

# Similar to but not the same as the other _structs.h.
rm cctools/include/foreign/mach/i386/_structs.h

# Causes a troublesome undefined reference.
rm cctools/libstuff/vm_flush_cache.c

cd ..

mv cctools-port/cctools/ar .
mv cctools-port/cctools/include .
mv cctools-port/cctools/libstuff .
rm -r cctools-port

mkdir build
cd build

CFLAGS="-Wno-deprecated -Wno-deprecated-declarations -Wno-unused-result"
CFLAGS+=" -Wfatal-errors -O2 -g"
CFLAGS+=" -I../include -I../include/foreign"
CFLAGS+=" -DPROGRAM_PREFIX=\\\"$host-\\\""
CFLAGS+=" -DPACKAGE_NAME=\\\"cctools\\\" -DPACKAGE_VERSION=\\\"$apple_version\\\""
CFLAGS+=" -D__LITTLE_ENDIAN__ -D__private_extern__= -D__DARWIN_UNIX03"
CFLAGS+=" -DEMULATED_HOST_CPU_TYPE=16777223 -DEMULATED_HOST_CPU_SUBTYPE=3"
CFLAGS+=" -DHAVE_BCMP -DHAVE_BZERO -DHAVE_BCOPY -DHAVE_INDEX -DHAVE_RINDEX"

CXXFLAGS="-std=gnu++17 $CFLAGS"

LDFLAGS="-ldl -lpthread"

# Use GNU parallel if available, otherwise fallback to serial compilation
if command -v parallel &>/dev/null; then
  find ../ar ../libstuff -name "*.c" | parallel -j$NIX_BUILD_CORES "echo compiling {} && gcc -c $CFLAGS {} -o $(basename {}).o"
else
  for f in ../ar/*.c ../libstuff/*.c; do
    echo "compiling $f"
    eval "gcc -c $CFLAGS $f -o $(basename $f).o"
  done
fi

gcc *.o $LDFLAGS -o $host-ar

mkdir -p $out/bin
cp $host-ar $out/bin/

# ar looks for ranlib in this directory
ln -s $ranlib/bin/$host-ranlib $out/bin/
