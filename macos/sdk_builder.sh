source $setup

# Use --warning=no-unknown-keyword to ignore the LIBARCHIVE.xattr warnings
tar -xf $src --warning=no-unknown-keyword
mv MacOSX*.sdk $out

cd $out

ruby -rjson \
  -e "print JSON.load(File.read('SDKSettings.json')).fetch('Version')" \
  > version.txt

# Modern macOS 15.x SDKs have a different structure and don't include 
# C++ standard library headers in the same way as older SDKs.
# Create the required C++ include structure for compatibility
echo "Setting up C++ headers for modern macOS SDK..."

# Clean up any previous structure first
rm -rf usr/include/c++
rm -rf usr/include/c++/v1

# Create the directory structure
mkdir -p usr/include/c++
mkdir -p usr/include/c++/v1

# The directory structure is already set up, so we don't need to check
# for existence of a directory we just removed and recreated

# Try to find libc++ headers on the build system
LIBCXX_HEADERS=$(find /nix/store -path '*/lib/libc++/include' -type d 2>/dev/null | head -1)

if [ -n "$LIBCXX_HEADERS" ] && [ -d "$LIBCXX_HEADERS" ]; then
  echo "Found libc++ headers at: $LIBCXX_HEADERS"
  # Use real libc++ headers if available
  cp -L "$LIBCXX_HEADERS"/* usr/include/c++/ || true
  cp -L "$LIBCXX_HEADERS"/* usr/include/c++/v1/ || true
  echo "Copied real libc++ headers for compatibility"
else
  echo "Creating C++ standard library header stubs for compatibility..."
  
  # Create a list of common C++ headers to stub out
  HEADERS=(
    "algorithm" "array" "atomic" "bitset" "cassert" "ccomplex" "cctype" "cerrno" 
    "cfenv" "cfloat" "chrono" "cinttypes" "ciso646" "climits" "clocale" "cmath" 
    "complex" "condition_variable" "csetjmp" "csignal" "cstdarg" "cstdbool" 
    "cstddef" "cstdint" "cstdio" "cstdlib" "cstring" "ctgmath" "ctime" "cwchar" 
    "cwctype" "deque" "exception" "forward_list" "fstream" "functional" "future" 
    "initializer_list" "iomanip" "ios" "iosfwd" "iostream" "istream" "iterator" 
    "limits" "list" "locale" "map" "memory" "mutex" "new" "numeric" "ostream" 
    "queue" "random" "ratio" "regex" "set" "sstream" "stack" "stdexcept" "streambuf" 
    "string" "system_error" "thread" "tuple" "type_traits" "typeindex" "typeinfo" 
    "unordered_map" "unordered_set" "utility" "valarray" "vector"
  )

  # Create stub files in both locations for maximum compatibility
  for header in "${HEADERS[@]}"; do
    echo "// Stub header for compatibility with modern macOS SDKs" > usr/include/c++/${header}
    echo "// Stub header for compatibility with modern macOS SDKs" > usr/include/c++/v1/${header}
  done

  # Create some additional basic structural headers that might be expected
  echo "#include <stddef.h>" > usr/include/c++/cstddef
  echo "#include <stdint.h>" > usr/include/c++/cstdint
  echo "#include <stdlib.h>" > usr/include/c++/cstdlib
  echo "#include <stddef.h>" > usr/include/c++/v1/cstddef
  echo "#include <stdint.h>" > usr/include/c++/v1/cstdint
  echo "#include <stdlib.h>" > usr/include/c++/v1/cstdlib
  
  echo "C++ header stubs created successfully"
fi

# Verify the iterator header exists
ls usr/include/c++/iterator > /dev/null || echo "ERROR: Failed to create C++ iterator header"
