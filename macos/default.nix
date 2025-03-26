# Note: There are several LLVM versions in sight here:
# 1. The one that comes with tapi.
#    (Just so that the tapi library can use its YAML parser!)
# 2. The one used by nixpkgs.clang which we use to build ld.
# 3. The one we build here (macos.clang) and use as our cross-compiler.
#    We also use compiler-rt from this version.

# Note: To reduce clutter here, it might be nice to move clang to
# `native`, and also make `native` provide a function for building
# binutils.  So clang and binutils recipes could be shared by the
# different platforms we targets.

{ native, macos_sdk, arch }:
let
  nixpkgs = native.nixpkgs;

  # macOS 11 is the first version to support ARM and it was released in 2020,
  # so it seems reasonable to specify it as the minimum version which various
  # tools ask for, but I'm not sure what all the implications are.
  macos_version_min = "11.0";

  # This is the Darwin version corresponding to macOS 11.0 according to
  # https://en.wikipedia.org/wiki/Darwin_(operating_system)
  darwin_name = "darwin20.1";

  host = "${arch}-apple-${darwin_name}";

  clang_version = "16.0.0";  # 2023-03-17

  clang_src = nixpkgs.fetchurl {
    url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${clang_version}/clang-${clang_version}.src.tar.xz";
    sha256 = "13srp7nq6ydfaa6y8pcgnwc9pny0ipka06gcxkni7vxiif639lc6";
  };

  llvm_src = nixpkgs.fetchurl {
    url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${clang_version}/llvm-${clang_version}.src.tar.xz";
    sha256 = "1bjabmdmlbg4x2fij2gxbhxs4vipxv4kkf77jxh580c5qhczrrmw";
  };

  compiler-rt_src = nixpkgs.fetchurl {
    url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${clang_version}/compiler-rt-${clang_version}.src.tar.xz";
    sha256 = "0kilx9c8dzcsc8mx4cssd113122i5lwnqqj3857k4f35l2mi0dm4";
  };

  clang = native.make_derivation rec {
    name = "clang-${clang_version}";

    src = clang_src;
    inherit llvm_src;

    patches = [ ];

    builder = ./clang_builder.sh;

    native_inputs = [ nixpkgs.python3 ];

    cmake_flags =
      "-DCMAKE_BUILD_TYPE=Release " +
      # "-DCMAKE_BUILD_TYPE=Debug " +
      "-DLLVM_TARGETS_TO_BUILD=X86\;ARM\;AArch64 " +
      "-DLLVM_INCLUDE_BENCHMARKS=OFF " +
      "-DLLVM_ENABLE_ASSERTIONS=OFF " +
      # LLVM 16 supports LLVM_ENABLE_PROJECTS for better component management
      "-DLLVM_ENABLE_PROJECTS=clang " +
      "-DLLVM_INSTALL_UTILS=ON";
  };

  tapi = native.make_derivation rec {
    name = "tapi-${version}";
    version = "1100.0.11";
    TAPI_REPOSITORY_STRING = "tpoechtrager/apple-libtapi";
    src = nixpkgs.fetchurl {
      url = "https://github.com/tpoechtrager/apple-libtapi/archive/b7b5bdb.tar.gz";  # 2022-05-29
      sha256 = "V3uG9XKfJNwQ66SJlTY8/9XWK7CATIBR4cGi8IpxBzc=";
    };
    patches = [ ./tapi.patch ];
    builder = ./tapi_builder.sh;
    native_inputs = [ nixpkgs.python3 ];
  };

  cctools_commit = "3ecb04b";  # 2023-01-24
  cctools_apple_version = "973.0.1";  # from README.md
  cctools_port_src = nixpkgs.fetchurl {
    url = "https://github.com/tpoechtrager/cctools-port/archive/${cctools_commit}.tar.gz";
    hash = "sha256-ZGjOJD8rUPcldLmbRW2FDKj23IzpWwwM5wa+klMQCRE==";
  };
  cctools_patches = [
    # Fix a warning about returning a local variable.  A memory leak would
    # be better than doing that.
    ./cctools_symloc_bug.patch

    # libstuff has a function named 'error' and that clashes with the
    # functions of the same name in the programs we are linking, like 'ar'.
    ./cctools_stuff_error.patch

    # Add -gc-sections as an alias for -dead_strip for better compatibility.
    ./cctools_gc_sections.patch
  ];

  # We build ld with clang because it uses "Blocks", a clang extension.
  ld = native.make_derivation rec {
    name = "cctools-ld64";
    apple_version = cctools_apple_version;
    src = cctools_port_src;
    patches = cctools_patches;
    builder = ./ld_builder.sh;
    native_inputs = [ nixpkgs.clang tapi ];
    inherit host;
  };

  misc = native.make_derivation rec {
    name = "cctools-misc";
    apple_version = cctools_apple_version;
    src = cctools_port_src;
    builder = ./misc_builder.sh;
    patches = cctools_patches;
    inherit host;
  };

  ar = native.make_derivation rec {
    name = "cctools-ar";
    apple_version = cctools_apple_version;
    src = cctools_port_src;
    builder = ./ar_builder.sh;
    patches = cctools_patches;
    inherit host;
    ranlib = misc;
  };

  sdk = native.make_derivation rec {
    name = "macos-sdk";
    builder = ./sdk_builder.sh;
    src = if macos_sdk != null then macos_sdk else ./MacOSX.sdk.tar.xz;
    native_inputs = [ nixpkgs.ruby ];
  } // {
    version = builtins.readFile "${sdk}/version.txt";
  };

  # Note: compiler-rt actually builds itself for three different architectures:
  # i386, x86_64, x86_64h.  It uses lipo to create fat archives that hold
  # binaries for all the different architectures.
  compiler_rt = native.make_derivation rec {
    name = "compiler-rt-${clang_version}-${host}";

    src = compiler-rt_src;

    builder = ./compiler_rt_builder.sh;

    patches = [ ./compiler_rt.patch ];

    native_inputs = [ clang ld misc ar nixpkgs.python3 ];

    _cflags = "-target ${host} --sysroot ${sdk} " +
      "-I${sdk}/usr/include -mlinker-version=${ld.apple_version}";
    CC = "clang ${_cflags}";
    CXX = "clang++ ${_cflags} -stdlib=libc++ -cxx-isystem ${sdk}/usr/include/c++";

    cmake_flags =
      "-DCMAKE_BUILD_TYPE=Release " +
      "-DCMAKE_SYSTEM_NAME=Darwin " +
      "-DCMAKE_OSX_SYSROOT=${sdk} " +
      "-DDARWIN_osx_SYSROOT=${sdk} " +
      "-DDARWIN_osx_ARCHS=${arch} " +
      "-DDARWIN_osx_BUILTIN_ARCHS=${arch} " +
      "-DCMAKE_LINKER=${ld}/bin/${host}-ld " +
      "-DCMAKE_AR=${ar}/bin/${host}-ar " +
      "-DCMAKE_RANLIB=${misc}/bin/${host}-ranlib " +
      "-DCOMPILER_RT_BUILD_SANITIZERS=OFF " +
      "-DCOMPILER_RT_BUILD_XRAY=OFF " +
      "-DCOMPILER_RT_BUILD_LIBFUZZER=OFF " +
      "-DCOMPILER_RT_BUILD_ORC=OFF " +
      "-DCOMPILER_RT_BUILD_PROFILE=OFF " +
      "-DCOMPILER_RT_INCLUDE_TESTS=OFF " +
      "-DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=ON " +
      "-DHAVE_RPC_XDR_H=OFF";

    inherit host sdk;
  };

  toolchain = native.make_derivation rec {
    name = "macos-toolchain";
    builder = ./toolchain_builder.sh;
    src_file = ./wrapper.cpp;
    inherit host clang ld misc ar;

    CXXFLAGS =
      "-std=c++11 " +
      "-Wall " +
      "-I. " +
      "-O2 -g " +
      "-DWRAPPER_OS_VERSION_MIN=\\\"${macos_version_min}\\\" " +
      "-DWRAPPER_HOST=\\\"${host}\\\" " +
      "-DWRAPPER_ARCH=\\\"${arch}\\\" " +
      "-DWRAPPER_SDK_PATH=\\\"${sdk}\\\" " +
      "-DWRAPPER_COMPILER_RT_PATH=\\\"${compiler_rt}\\\" " +
      "-DWRAPPER_LINKER_VERSION=\\\"${ld.apple_version}\\\"";
  };

  crossenv = rec {
    is_cross = true;

    # Target info.
    inherit host arch;
    os = "macos";
    inherit macos_version_min;
    compiler = "clang";
    exe_suffix = "";
    cmake_system = "Darwin";
    meson_system = "darwin";
    meson_cpu_family = arch;
    meson_cpu = arch;

    # System libraries
    frameworks = "${sdk}/System/Library/Frameworks/";

    # Build tools.
    inherit nixpkgs native;
    wrappers = import ../wrappers crossenv;

    # License information that should be shipped with any software
    # compiled by this environment.
    global_license_set = { compiler_rt = "${compiler_rt}/LICENSE.txt"; };

    # Handy shortcuts.
    inherit clang compiler_rt tapi ld misc ar sdk toolchain;

    # Build tools available on the PATH for every derivation.
    default_native_inputs = native.default_native_inputs
      ++ [ clang toolchain wrappers ];

    make_derivation = import ../make_derivation.nix crossenv;
  };
in
  crossenv
