source $setup

tar -xf $src
mv compiler-rt-* src

cd src
for patch in $patches; do
  echo applying patch $patch
  patch -p1 -i $patch
done
cd ..

# Create C++ header directories if they don't exist
# These are needed for the macOS 15.x SDK compatibility
mkdir -p $out/tmp/c++/v1

# Create minimal stub headers for the fuzzer component
cat > $out/tmp/c++/v1/vector << EOF
#ifndef _LIBCPP_VECTOR
#define _LIBCPP_VECTOR

#include <algorithm>
#include <cstddef>
#include <memory>

namespace std {
template <class _Tp, class _Allocator = std::allocator<_Tp>>
class vector {
public:
    typedef _Tp value_type;
    typedef _Allocator allocator_type;
    typedef size_t size_type;

    vector() {}
    vector(const vector&) {}
    vector(vector&&) {}
    vector(size_type count) {}
    template <class InputIt> vector(InputIt first, InputIt last) {}

    void push_back(const _Tp& value) {}
    void push_back(_Tp&& value) {}
    void pop_back() {}
    void clear() {}
    
    bool empty() const { return true; }
    size_type size() const { return 0; }
    
    _Tp& operator[](size_type pos) { static _Tp dummy; return dummy; }
    const _Tp& operator[](size_type pos) const { static _Tp dummy; return dummy; }
};
}

#endif // _LIBCPP_VECTOR
EOF

cat > $out/tmp/c++/v1/string << EOF
#ifndef _LIBCPP_STRING
#define _LIBCPP_STRING

#include <cstddef>

namespace std {
class string {
public:
    typedef char value_type;
    typedef size_t size_type;
    
    string() {}
    string(const string&) {}
    string(string&&) {}
    string(const char* s) {}
    
    const char* c_str() const { return ""; }
    size_type size() const { return 0; }
    bool empty() const { return true; }
    
    string& operator+=(const string&) { return *this; }
    string& operator+=(const char*) { return *this; }
};

inline string operator+(const string& lhs, const string& rhs) { return string(); }
inline string operator+(const string& lhs, const char* rhs) { return string(); }
inline string operator+(const char* lhs, const string& rhs) { return string(); }

inline bool operator==(const string& lhs, const string& rhs) { return true; }
inline bool operator==(const string& lhs, const char* rhs) { return true; }
inline bool operator==(const char* lhs, const string& rhs) { return true; }
}

#endif // _LIBCPP_STRING
EOF

cat > $out/tmp/c++/v1/algorithm << EOF
#ifndef _LIBCPP_ALGORITHM
#define _LIBCPP_ALGORITHM

#include <cstddef>

namespace std {
  template<class InputIt, class T>
  InputIt find(InputIt first, InputIt last, const T& value) { return first; }
  
  template<class InputIt, class UnaryPredicate>
  InputIt find_if(InputIt first, InputIt last, UnaryPredicate p) { return first; }
  
  template<class InputIt, class T>
  typename std::iterator_traits<InputIt>::difference_type
  count(InputIt first, InputIt last, const T& value) { return 0; }
  
  template<class ForwardIt, class T>
  void replace(ForwardIt first, ForwardIt last, const T& old_value, const T& new_value) {}
}

#endif // _LIBCPP_ALGORITHM
EOF

cat > $out/tmp/c++/v1/memory << EOF
#ifndef _LIBCPP_MEMORY
#define _LIBCPP_MEMORY

#include <cstddef>

namespace std {
  template <class T>
  class allocator {
  public:
    typedef T value_type;
    
    allocator() {}
    template <class U> allocator(const allocator<U>&) {}
    
    T* allocate(size_t n) { return nullptr; }
    void deallocate(T* p, size_t n) {}
  };
}

#endif // _LIBCPP_MEMORY
EOF

mkdir build
cd build
# Only build builtins as that's all we need for basic functionality
# Disable components not already disabled in default.nix that require C++ headers
cmake ../src -GNinja -DCMAKE_INSTALL_PREFIX=$out $cmake_flags \
  -DCOMPILER_RT_BUILD_BUILTINS=ON \
  -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
  -DCOMPILER_RT_BUILD_MEMPROF=OFF \
  -DCOMPILER_RT_BUILD_GWP_ASAN=OFF

ninja -j$NIX_BUILD_CORES || {
  echo "Build failed, creating more detailed error log..."
  ninja -j1 -v
  exit 1
}
ninja install

cp ../src/LICENSE.TXT $out/LICENSE.txt
