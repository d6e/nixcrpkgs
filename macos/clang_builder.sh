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

# Create and prepare third-party directories
mkdir -p third-party/unittest
ln -s $(pwd)/third-party llvm/third-party

# Set up CMake modules directly in the expected location for absolute paths
mkdir -p /build/cmake/Modules
cp -r llvm/cmake/* /build/cmake/
cp -r llvm/cmake/modules/* /build/cmake/Modules/

# Ensure a CMakePolicy.cmake file exists
touch /build/cmake/Modules/CMakePolicy.cmake
echo "# Empty placeholder" > /build/cmake/Modules/CMakePolicy.cmake
echo "# Empty placeholder" > /build/cmake/Modules/GNUInstallPackageDir.cmake
echo "# Empty placeholder" > /build/cmake/Modules/ExtendPath.cmake
echo "# Empty placeholder" > /build/cmake/Modules/FindPrefixFromConfig.cmake

# Add macro definitions to FindPrefixFromConfig.cmake
cat > /build/cmake/Modules/FindPrefixFromConfig.cmake << 'EOF'
# Simple implementation of find_prefix_from_config
macro(find_prefix_from_config)
  # Empty placeholder implementation
endmacro()
EOF

# Create ExtendPath.cmake with definition of extend_path
cat > /build/cmake/Modules/ExtendPath.cmake << 'EOF'
# Simple implementation of extend_path
macro(extend_path var_name path)
  set(${var_name} "${${var_name}}:${path}")
endmacro()
EOF

# Create CMake policy file to suppress FindCUDA warnings
cat > /build/cmake/Modules/CMakePolicy.cmake << 'EOF'
# Set policy CMP0146 to suppress FindCUDA warnings
cmake_policy(SET CMP0146 NEW)
# Set any other relevant policies
EOF

# Create additional symlinks to ensure all required paths work
ln -sf /build/cmake llvm/../cmake
mkdir -p clang/../cmake
ln -sf /build/cmake/Modules clang/../cmake/Modules

mkdir build
cd build

# Set CMAKE_MODULE_PATH to find the required CMake modules
cmake ../llvm -GNinja \
  -DDEFAULT_SYSROOT=$out \
  -DCMAKE_INSTALL_PREFIX=$out \
  -DCMAKE_MODULE_PATH=$(pwd)/../cmake/modules \
  $cmake_flags

# Use NIX_BUILD_CORES for parallelization

ninja -j$NIX_BUILD_CORES

ninja install
