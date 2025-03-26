source $setup

# Extract LLVM source
tar -xf $llvm_src
if [ -d cmake ]; then
  rm -r cmake
fi
mv llvm-* llvm

# Extract and prepare Clang source
tar -xf $src
ls -l
mv clang-* clang
cd clang
for patch in $patches; do
  echo applying patch $patch
  patch -p1 -i $patch
done
cd ..

# In LLVM 16, Clang can be placed either in projects/ or via LLVM_ENABLE_PROJECTS
# We'll use the LLVM_ENABLE_PROJECTS approach as it's the recommended method
mkdir -p llvm/third-party/unittest

# Create the cmake modules directory if it's missing
mkdir -p llvm/cmake/modules

mkdir build
cd build

cmake ../llvm -GNinja \
  -DDEFAULT_SYSROOT=$out \
  -DCMAKE_INSTALL_PREFIX=$out \
  $cmake_flags

# Use NIX_BUILD_CORES for parallelization

ninja -j$NIX_BUILD_CORES

ninja install
