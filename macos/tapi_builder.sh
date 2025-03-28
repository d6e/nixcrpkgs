source $setup

tar -xf $src
mv apple-libtapi-* tapi
cd tapi
for patch in $patches; do
  echo applying patch $patch
  patch -p1 -i $patch
done

mkdir build
cd build

FLAGS="-I $PWD/../src/llvm/projects/clang/include "
FLAGS+="-I $PWD/projects/clang/include "
FLAGS+="-Wno-redundant-move "
cmake ../src/llvm \
 -DCMAKE_CXX_FLAGS="$FLAGS" \
 -DLLVM_INCLUDE_TESTS=OFF \
 -DCMAKE_BUILD_TYPE=RELEASE \
 -DCMAKE_INSTALL_PREFIX=$out \
 -DTAPI_REPOSITORY_STRING=$TAPI_REPOSITORY_STRING

make -j$NIX_BUILD_CORES clangBasic
make -j$NIX_BUILD_CORES libtapi
make -j$NIX_BUILD_CORES install-libtapi install-tapi-headers

mkdir -p $out/lib/pkgconfig
cat > $out/lib/pkgconfig/libtapi.pc <<END
prefix=$out
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libtapi
Version: $version
Libs: -L\${libdir} -ltapi
Cflags: -I\${includedir}
END
