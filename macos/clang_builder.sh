source $setup

tar -xf $llvm_src
rm -r cmake
mv llvm-* llvm

tar -xf $src
ls -l
mv clang-* clang
cd clang
for patch in $patches; do
  echo applying patch $patch
  patch -p1 -i $patch
done
cd ..
mv clang llvm/projects/

mkdir build
cd build

cmake ../llvm -GNinja -DDEFAULT_SYSROOT=$out -DCMAKE_INSTALL_PREFIX=$out $cmake_flags

# Use NIX_BUILD_CORES for parallelization

ninja -j$NIX_BUILD_CORES

ninja install
