#
# To validate podspec run
# pod spec lint bls-signatures-pod.podspec --no-clean --verbose --allow-warnings --skip-import-validation
#
# To submit podspec to the CocoaPods trunk:
# pod trunk push --allow-warnings --skip-import-validation
# 
# Requirements: cmake
#

Pod::Spec.new do |s|
  s.name             = 'bls-signatures-pod'
  s.version          = '0.2.12'
  s.summary          = 'BLS signatures in C++, using the relic toolkit'

  s.description      = <<-DESC
Implements BLS signatures with aggregation as in Boneh, Drijvers, Neven 2018, using relic toolkit for cryptographic primitives (pairings, EC, hashing). The BLS12-381 curve is used.
                       DESC

  s.homepage         = 'https://github.com/Chia-Network/bls-signatures'
  s.license          = { :type => 'Apache License 2.0' }
  s.author           = { 'Chia Network' => 'hello@chia.net' }
  s.social_media_url = 'https://twitter.com/ChiaNetworkInc'

  s.source           = { 
    :git => 'https://github.com/Chia-Network/bls-signatures.git',
    :commit => 'f114ffeff4653e5522d1b3e28687fa9f384a557f',
    :submodules => false
  }

  # Temporary workaround: don't allow CocoaPods to clone and fetch submodules.
  # Fetch submodules _after_ checking out to the needed commit in prepare command.

  s.prepare_command = <<-CMD
#!/bin/sh

set -x

git submodule update --init

MIN_IOS="13.0"
MIN_WATCHOS="5.0"
MIN_TVOS=$MIN_IOS
MIN_MACOS="10.15"

IPHONEOS=iphoneos
IPHONESIMULATOR=iphonesimulator
WATCHOS=watchos
WATCHSIMULATOR=watchsimulator
TVOS=appletvos
TVSIMULATOR=appletvsimulator
MACOS=macosx

LOGICALCPU_MAX=`sysctl -n hw.logicalcpu_max`

GMP_DIR="`pwd`/gmp"

version_min_flag()
{
    PLATFORM=$1

    FLAG=""
    if [[ $PLATFORM = $IPHONEOS ]]; then
        FLAG="-miphoneos-version-min=${MIN_IOS}"
    elif [[ $PLATFORM = $IPHONESIMULATOR ]]; then
        FLAG="-mios-simulator-version-min=${MIN_IOS}"
    elif [[ $PLATFORM = $WATCHOS ]]; then
        FLAG="-mwatchos-version-min=${MIN_WATCHOS}"
    elif [[ $PLATFORM = $WATCHSIMULATOR ]]; then
        FLAG="-mwatchos-simulator-version-min=${MIN_WATCHOS}"
    elif [[ $PLATFORM = $TVOS ]]; then
        FLAG="-mtvos-version-min=${MIN_TVOS}"
    elif [[ $PLATFORM = $TVSIMULATOR ]]; then
        FLAG="-mtvos-simulator-version-min=${MIN_TVOS}"
    elif [[ $PLATFORM = $MACOS ]]; then
        FLAG="-mmacosx-version-min=${MIN_MACOS}"
    fi

    echo $FLAG
}


prepare()
{
    download_gmp()
    {
        GMP_VERSION="6.2.1"
        CURRENT_DIR=`pwd`

        if [ ! -s ${CURRENT_DIR}/gmp-${GMP_VERSION}.tar.bz2 ]; then
            curl -L -o ${CURRENT_DIR}/gmp-${GMP_VERSION}.tar.bz2 https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.bz2
        fi

        rm -rf gmp
        tar xfj "gmp-${GMP_VERSION}.tar.bz2"
        mv gmp-${GMP_VERSION} gmp
        GMP_DIR="`pwd`/gmp"
    }

    download_cmake_toolchain()
    {
        pushd contrib/relic

        if [ ! -s ios.toolchain.cmake ]; then
                SHA256_HASH="4fe55ef74f4e28ade4b2591b8cc61a73c8e1a6508a9108052fe40098e63d8e79"
                curl -o ios.toolchain.cmake https://raw.githubusercontent.com/leetal/ios-cmake/master/ios.toolchain.cmake
                DOWNLOADED_HASH=`shasum -a 256 ios.toolchain.cmake | cut -f 1 -d " "`
                if [ $SHA256_HASH != $DOWNLOADED_HASH ]; then
                  echo "Error: sha256 checksum of ios.toolchain.cmake mismatch" >&2
                  exit 1
                fi
            fi

        popd # contrib/relic
    }

    download_gmp
    download_cmake_toolchain

    rm -rf artefacts
    mkdir artefacts
}

build_gmp_arch()
{
    pushd gmp

    PLATFORM=$1
    ARCH=$2

    SDK=`xcrun --sdk $PLATFORM --show-sdk-path`
    PLATFORM_PATH=`xcrun --sdk $PLATFORM --show-sdk-platform-path`
    CLANG=`xcrun --sdk $PLATFORM --find clang`
    CURRENT_DIR=`pwd`
    DEVELOPER=`xcode-select --print-path`
    export PATH="${PLATFORM_PATH}/Developer/usr/bin:${DEVELOPER}/usr/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"

    make clean || true
    make distclean || true

    mkdir gmplib-${PLATFORM}-${ARCH}

    CFLAGS="-fembed-bitcode -arch ${ARCH} --sysroot=${SDK}"
    EXTRA_FLAGS="$(version_min_flag $PLATFORM)"

    CCARGS="${CLANG} ${CFLAGS}"
    CPPFLAGSARGS="${CFLAGS} ${EXTRA_FLAGS}"

    CONFIGURESCRIPT="gmp_configure_script.sh"

    cat >"$CONFIGURESCRIPT" << EOF
#!/bin/sh

./configure \
CC="$CCARGS" CPPFLAGS="$CPPFLAGSARGS" \
--disable-shared --enable-static --host=arm-apple-darwin --disable-assembly \
--prefix="${CURRENT_DIR}/gmplib-${PLATFORM}-${ARCH}"

EOF

    chmod a+x "$CONFIGURESCRIPT"
    sh "$CONFIGURESCRIPT"
    rm "$CONFIGURESCRIPT"

    make -j $LOGICALCPU_MAX &> "${CURRENT_DIR}/gmplib-${PLATFORM}-${ARCH}-build.log"
    make install &> "${CURRENT_DIR}/gmplib-${PLATFORM}-${ARCH}-install.log"

    cp -r gmplib-${PLATFORM}-${ARCH}/include .
    
    rm -rf lib
    mkdir lib

    cp gmplib-${PLATFORM}-${ARCH}/lib/libgmp.a lib/libgmp.a

    popd # gmp
}

build_relic_arch()
{
    pushd contrib/relic

    PLATFORM=$1
    ARCH=$2

    SDK=`xcrun --sdk $PLATFORM --show-sdk-path`

    BUILDDIR="relic-${PLATFORM}-${ARCH}"
    rm -rf $BUILDDIR
    mkdir $BUILDDIR
    pushd $BUILDDIR

    unset CC
    export CC=`xcrun --sdk ${PLATFORM} --find clang`

    WSIZE=0
    IOS_PLATFORM=""
    OPTIMIZATIONFLAGS=""
    DEPLOYMENT_TARGET=""

    if [[ $PLATFORM = $IPHONEOS ]]; then
        if [[ $ARCH = "arm64" ]] || [[ $ARCH = "arm64e" ]]; then
            IOS_PLATFORM=OS64
            DEPLOYMENT_TARGET=$MIN_IOS
            WSIZE=64
            OPTIMIZATIONFLAGS=-fomit-frame-pointer
        else
            IOS_PLATFORM=OS
            WSIZE=32
        fi
    elif [[ $PLATFORM = $IPHONESIMULATOR ]]; then
        if [[ $ARCH = "x86_64" ]]; then
            IOS_PLATFORM=SIMULATOR64
            DEPLOYMENT_TARGET=$MIN_IOS
            WSIZE=64
            OPTIMIZATIONFLAGS=-fomit-frame-pointer
        elif [[ $ARCH = "arm64" ]]; then
            IOS_PLATFORM=SIMULATORARM64
            DEPLOYMENT_TARGET=$MIN_IOS
            WSIZE=64
        else
            IOS_PLATFORM=SIMULATOR
            WSIZE=32
        fi
    elif [[ $PLATFORM = $WATCHOS ]]; then
        IOS_PLATFORM=WATCHOS
        DEPLOYMENT_TARGET=$MIN_WATCHOS
        WSIZE=32
    elif [[ $PLATFORM = $WATCHSIMULATOR ]]; then
        IOS_PLATFORM=SIMULATOR_WATCHOS
        DEPLOYMENT_TARGET=$MIN_WATCHOS
        WSIZE=32
    elif [[ $PLATFORM = $TVOS ]]; then
        IOS_PLATFORM=TVOS
        DEPLOYMENT_TARGET=$MIN_TVOS
        WSIZE=64
        OPTIMIZATIONFLAGS=-fomit-frame-pointer
    elif [[ $PLATFORM = $TVSIMULATOR ]]; then
        IOS_PLATFORM=SIMULATOR_TVOS
        #TODO
        if [[ $ARCH = "arm64" ]]
        then
            IOS_PLATFORM=OS64
        fi
        DEPLOYMENT_TARGET=$MIN_TVOS
        WSIZE=64
        OPTIMIZATIONFLAGS=-fomit-frame-pointer
    elif [[ $PLATFORM = $MACOS ]]; then
        WSIZE=64
        IOS_PLATFORM=MAC
        if [[ $ARCH = "arm64" ]]
        then
            IOS_PLATFORM=MAC_ARM64
        fi
        DEPLOYMENT_TARGET=$MIN_MACOS
        OPTIMIZATIONFLAGS=-fomit-frame-pointer
    fi
    
    COMPILER_ARGS=""
    if [[ $ARCH != "i386" ]]; then
        COMPILER_ARGS=$(version_min_flag $PLATFORM)
    fi
    
    EXTRA_ARGS="-DOPSYS=NONE -DIOS_PLATFORM=$IOS_PLATFORM -DPLATFORM=$IOS_PLATFORM -DDEPLOYMENT_TARGET=$DEPLOYMENT_TARGET -DCMAKE_TOOLCHAIN_FILE=../ios.toolchain.cmake"
    
    if [[ $ARCH = "i386" ]]; then
        EXTRA_ARGS+=" -DARCH=X86"
    elif [[ $ARCH = "x86_64" ]]; then
        EXTRA_ARGS+=" -DARCH=X64"
    else
        EXTRA_ARGS+=" -DARCH=ARM"
        if [[ $ARCH = "armv7s" ]]; then
            EXTRA_ARGS+=" -DIOS_ARCH=armv7s"
        elif [[ $ARCH = "armv7k" ]]; then
            EXTRA_ARGS+=" -DIOS_ARCH=armv7k"
        elif [[ $ARCH = "arm64_32" ]]; then
            EXTRA_ARGS+=" -DIOS_ARCH=arm64_32"
        fi
    fi

    CURRENT_DIR=`pwd`

    cmake -DCMAKE_PREFIX_PATH:PATH="${GMP_DIR}" -DTESTS=0 -DBENCH=0 -DCHECK=off -DARITH=gmp -DFP_PRIME=381 -DMULTI=PTHREAD \
    -DFP_QNRES=off -DFP_METHD="INTEG;INTEG;INTEG;MONTY;LOWER;SLIDE" -DFPX_METHD="INTEG;INTEG;LAZYR" -DPP_METHD="LAZYR;OATEP" \
    -DCOMP="-O3 -funroll-loops $OPTIMIZATIONFLAGS -isysroot $SDK -arch $ARCH -fembed-bitcode ${COMPILER_ARGS}" -DWSIZE=$WSIZE \
    -DVERBS=off -DSHLIB=off -DALLOC="AUTO" -DEP_PLAIN=off -DEP_SUPER=off -DPP_EXT="LAZYR" -DTIMER="HREAL" ${EXTRA_ARGS} ../

    make -j $LOGICALCPU_MAX

    popd # "$BUILDDIR"
    popd # contrib/relic
}

build_bls_arch()
{
    BLS_FILES=( "aggregationinfo" "bls" "chaincode" "extendedprivatekey" "extendedpublickey" "privatekey" "publickey" "signature" )
    ALL_BLS_OBJ_FILES=$(printf "%s.o " "${BLS_FILES[@]}")

    PLATFORM=$1
    ARCH=$2

    SDK=`xcrun --sdk $PLATFORM --show-sdk-path`

    BUILDDIR="bls-${PLATFORM}-${ARCH}"
    rm -rf $BUILDDIR
    mkdir $BUILDDIR
    pushd $BUILDDIR

    EXTRA_ARGS="$(version_min_flag $PLATFORM)"

    CURRENT_DIR=`pwd`

    for F in "${BLS_FILES[@]}"
    do
        clang -I"../contrib/relic/include" -I"../contrib/relic/relic-${PLATFORM}-${ARCH}/include" -I"../src/" -I"${GMP_DIR}/include" \
        -x c++ -std=c++14 -stdlib=libc++ -fembed-bitcode -arch "${ARCH}" -isysroot "${SDK}" ${EXTRA_ARGS} -c "../src/${F}.cpp" -o "${CURRENT_DIR}/${F}.o"
    done

    xcrun -sdk $PLATFORM ar -cvq libbls.a $ALL_BLS_OBJ_FILES

    popd # "$BUILDDIR"
}

build_all_arch()
{
    PLATFORM=$1
    ARCH=$2

    build_gmp_arch $PLATFORM $ARCH
    build_relic_arch $PLATFORM $ARCH
    build_bls_arch $PLATFORM $ARCH
}

build_all()
{
    SUFFIX=$1
    BUILD_IN=$2

    IFS='|' read -ra BUILD_PAIRS <<< "$BUILD_IN"
    for BUILD_PAIR in "${BUILD_PAIRS[@]}"
    do
        IFS=';' read -ra PARSED_PAIR <<< "$BUILD_PAIR"
        PLATFORM=${PARSED_PAIR[0]}
        ARCH=${PARSED_PAIR[1]}
        
        GMP_LIPOARGS=""
        RELIC_LIPOARGS=""
        BLS_LIPOARGS=""

        local NEED_LIPO=0
        IFS='+' read -ra ARCHS <<< "$ARCH"
        for i in "${!ARCHS[@]}"
        do
            local SINGLEARCH=${ARCHS[i]}
            
            # build for every platform+arch
            build_all_arch $PLATFORM $SINGLEARCH
            
            rm -rf "artefacts/${PLATFORM}-${SINGLEARCH}"
            mkdir "artefacts/${PLATFORM}-${SINGLEARCH}"

            mv gmp/lib/libgmp.a "artefacts/${PLATFORM}-${SINGLEARCH}/libgmp.a"
            mv "contrib/relic/relic-${PLATFORM}-${SINGLEARCH}/lib/librelic_s.a" "artefacts/${PLATFORM}-${SINGLEARCH}/librelic.a"
            mv "bls-${PLATFORM}-${SINGLEARCH}/libbls.a" "artefacts/${PLATFORM}-${SINGLEARCH}/libbls.a"    

            GMP_LIPOARGS+="artefacts/${PLATFORM}-${SINGLEARCH}/libgmp.a "
            RELIC_LIPOARGS+="artefacts/${PLATFORM}-${SINGLEARCH}/librelic.a "
            BLS_LIPOARGS+="artefacts/${PLATFORM}-${SINGLEARCH}/libbls.a "

            NEED_LIPO=i
        done

        # Do lipo if we need https://developer.apple.com/forums/thread/666335?answerId=645963022#645963022
        if [[ $NEED_LIPO -gt 0 ]]
        then
            rm -rf "artefacts/${PLATFORM}-fat"
            mkdir "artefacts/${PLATFORM}-fat"

            # lipo gmp
            xcrun lipo $GMP_LIPOARGS -create -output "artefacts/${PLATFORM}-fat/libgmp.a"

            # lipo relic
            xcrun lipo $RELIC_LIPOARGS -create -output "artefacts/${PLATFORM}-fat/librelic.a"
            
            # lipo bls
            xcrun lipo $BLS_LIPOARGS -create -output "artefacts/${PLATFORM}-fat/libbls.a" 

            # clean up
            for i in "${!ARCHS[@]}"
            do
                local SINGLEARCH=${ARCHS[i]}

                rm -rf "artefacts/${PLATFORM}-${SINGLEARCH}"
            done
        fi
    done
}

function make_relic_headers_universal()
{
    RELIC_TARGET_DIR=relic-iphoneos-arm64

    perl -p -e 's/#define WSIZE.*/#ifdef __LP64__\n#define WSIZE 64\n#else\n#define WSIZE 32\n#endif/' \
    "contrib/relic/${RELIC_TARGET_DIR}/include/relic_conf.h" \
    > "contrib/relic/${RELIC_TARGET_DIR}/include/relic_conf.h.new"

    rm "contrib/relic/${RELIC_TARGET_DIR}/include/relic_conf.h"
    mv "contrib/relic/${RELIC_TARGET_DIR}/include/relic_conf.h.new" "contrib/relic/${RELIC_TARGET_DIR}/include/relic_conf.h"   
}

function copy_headers()
{
    mkdir artefacts/include

    # Copy all headers we will need
    cp -rf src/*.hpp artefacts/include
    cp -rf gmp/include/gmp.h artefacts/include
    cp -rf contrib/relic/include/*.h artefacts/include
    cp -rf contrib/relic/include/low/*.h artefacts/include
    cp -rf contrib/relic/relic-iphoneos-arm64/include/*.h artefacts/include
    rm -rf artefacts/include/test-utils.hpp
}

function make_xcframework()
{
    pushd artefacts

    XCFRAMEWORK_ARGS=""

    for dir in */; do
        if [ -d "$dir" ]; then
            if [[ "$dir" != "include/" ]]; then
                libtool -static -o "${dir}libbls_combined.a" "${dir}libgmp.a" "${dir}librelic.a" "${dir}libbls.a"
    
                XCFRAMEWORK_ARGS+="-library ${dir}libbls_combined.a -headers include "
            fi
        fi
    done

    xcodebuild -create-xcframework $XCFRAMEWORK_ARGS -output "libbls.xcframework"
}

prepare

build_all "macos" "${MACOS};x86_64+arm64"
build_all "ios" "${IPHONEOS};arm64|${IPHONESIMULATOR};arm64+x86_64"
make_relic_headers_universal
copy_headers
make_xcframework
  CMD

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  s.library = 'c++'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_WARN_DOCUMENTATION_COMMENTS' => 'NO',
    'GCC_WARN_64_TO_32_BIT_CONVERSION' => 'NO',
    'GCC_WARN_INHIBIT_ALL_WARNINGS' => 'YES'
  }

  s.vendored_frameworks = 'artefacts/libbls.xcframework'
end