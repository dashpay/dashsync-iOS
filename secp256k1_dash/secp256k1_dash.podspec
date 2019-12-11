#
# pod spec lint secp256k1_dash.podspec --no-clean --verbose --allow-warnings
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'secp256k1_dash'
  s.version          = '0.1.3-alpha.1'
  s.summary          = 'Optimized C library for EC operations on curve secp256k1'
  s.description      = <<-DESC
Optimized C library for EC operations on curve secp256k1.

Configured with following defines: `USE_BASIC_CONFIG`, `ENABLE_MODULE_RECOVERY`, `DETERMINISTIC` and `WORDS_BIGENDIAN`

* secp256k1 ECDSA signing/verification and key generation.
* Adding/multiplying private/public keys.
* Serialization/parsing of private keys, public keys, signatures.
* Constant time, constant memory access signing and pubkey generation.
* Derandomized DSA (via RFC6979 or with a caller provided function.)
* Very efficient implementation.

                       DESC

  s.homepage         = 'https://github.com/dashevo/dashsync-iOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Andrew Podkovyrin' => 'podkovyrin@gmail.com' }
  s.source           = { :git => 'https://github.com/bitcoin-core/secp256k1.git', :commit => '84973d393ac240a90b2e1a6538c5368202bc2224' }

  s.ios.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.libraries = 'c++'
  s.source_files = 'src/*.{h,c}', 'src/modules/**/*.h', 'include/*.h'
  s.exclude_files = 'src/bench*', 'src/test*', 'src/gen_context.c', 'src/libsecp256k1-config.h', 'src/**/test*'
  s.public_header_files = 'include/*.h'
  s.private_header_files = 'src/*.h'
  s.header_mappings_dir = '.'

  s.pod_target_xcconfig = { 
    'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/**',
    'CLANG_WARN_DOCUMENTATION_COMMENTS' => 'NO',
    'GCC_WARN_64_TO_32_BIT_CONVERSION' => 'NO',
    'GCC_WARN_INHIBIT_ALL_WARNINGS' => 'YES',
    'GCC_WARN_UNINITIALIZED_AUTOS' => 'NO',
    'GCC_WARN_UNUSED_FUNCTION' => 'NO',
    'GCC_WARN_UNUSED_LABEL' => 'NO',
    'GCC_WARN_UNUSED_PARAMETER' => 'NO',
    'GCC_WARN_UNUSED_VALUE' => 'NO',
    'GCC_WARN_UNUSED_VARIABLE' => 'NO'
  }
  s.prefix_header_contents = <<-PREFIX_HEADER_CONTENTS
  /* DASH specific secp256k1 configuration */
#define USE_BASIC_CONFIG 1
#define ENABLE_MODULE_RECOVERY 1
#define DETERMINISTIC          1
#if __BIG_ENDIAN__
#define WORDS_BIGENDIAN        1
#endif

#include <secp256k1_dash/src/basic-config.h>

PREFIX_HEADER_CONTENTS

end
