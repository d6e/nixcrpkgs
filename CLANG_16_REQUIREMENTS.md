# Clang 16.0.0 Build Requirements

## Build System Changes
- Clang now uses `LLVM_ENABLE_PROJECTS` approach instead of placing it in `llvm/projects/`
- Add `-DLLVM_ENABLE_PROJECTS=clang` to CMake flags
- Create directories for third-party components (`llvm/third-party/unittest`) if they don't exist
- The `llvm/cmake/modules` and `clang/cmake/modules` directories already exist in the source and should not need to be created manually

## Requirements
- C++17 is now required (up from C++14)
- Minimum CMake version is 3.13.4
- CMake build type must be specified (e.g., `-DCMAKE_BUILD_TYPE=Release`)

## Breaking Changes
- Legacy pass manager flags have been removed (`-fexperimental-new-pass-manager` and `-fno-legacy-pass-manager`)
- Default C++ standard is now `gnu++17` instead of `gnu++14`
- Resource directory is simplified to `$prefix/lib/clang/$CLANG_MAJOR_VERSION`
- Some warning flags now default to errors in C99/C11/C17 modes
- ABI changes for non-POD members in packed structs
- POD types with defaulted special members are classified differently

## Implementation in nixcrpkgs
The commit (654c3c4) already addresses these issues by:
1. Switching to the `LLVM_ENABLE_PROJECTS` approach
2. Creating necessary third-party directories (`llvm/third-party/unittest`)
3. Adding the required CMake flags

Note: The script creates `llvm/cmake/modules` as a precaution, but this directory already exists in the source. This creation may be unnecessary in the build script.