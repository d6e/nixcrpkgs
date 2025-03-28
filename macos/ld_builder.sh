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

cd ..

mv cctools-port/cctools/ld64 ld64
mv cctools-port/cctools/include include
rm -r cctools-port
rm -r ld64/src/other

mkdir build
cd build

CFLAGS="-Wno-format -Wno-deprecated -Wno-deprecated-declarations -Wno-unused-result"
CFLAGS+=" -Wfatal-errors -O2 -g -fblocks"
CFLAGS+=" -I../ld64/src -I../ld64/src/ld -I../ld64/src/ld/parsers -I../ld64/src/abstraction -I../ld64/src/3rd -I../ld64/src/3rd/include -I../ld64/src/3rd/BlocksRuntime"
CFLAGS+=" -I../include -I../include/foreign"
CFLAGS+=" $(pkg-config --cflags libtapi) -DTAPI_SUPPORT"
CFLAGS+=" -DPROGRAM_PREFIX=\\\"$host-\\\""
CFLAGS+=" -DHAVE_BCMP -DHAVE_BZERO -DHAVE_BCOPY -DHAVE_INDEX -DHAVE_RINDEX -D__LITTLE_ENDIAN__"

CXXFLAGS="-std=gnu++17 $CFLAGS"

LDFLAGS="$(pkg-config --libs libtapi) -ldl -lpthread"

# Use GNU parallel if available, otherwise fallback to serial compilation
if command -v parallel &>/dev/null; then
  find ../ld64/src/ld -name "*.c" ../ld64/src/3rd -name "*.c" | parallel -j$NIX_BUILD_CORES "echo compiling {} && clang -c $CFLAGS {} -o $(basename {}).o"
  find ../ld64/src -name "*.cpp" | parallel -j$NIX_BUILD_CORES "echo compiling {} && clang++ -c $CXXFLAGS {} -o $(basename {}).o"
else
  for f in ../ld64/src/ld/*.c ../ld64/src/3rd/*.c ../ld64/src/3rd/**/*.c; do
    echo "compiling $f"
    eval "clang -c $CFLAGS $f -o $(basename $f).o"
  done

  for f in $(find ../ld64/src -name \*.cpp); do
    echo "compiling $f"
    eval "clang++ -c $CXXFLAGS $f -o $(basename $f).o"
  done
fi

clang++ *.o $LDFLAGS -o $host-ld

mkdir -p $out/bin
cp $host-ld $out/bin
