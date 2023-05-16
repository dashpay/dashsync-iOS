# DashSync - iOS

![banner](Docs/github-dashsync-image.jpg)

[![Version](https://img.shields.io/cocoapods/v/DashSyncPod.svg?style=flat)](http://cocoapods.org/pods/DashSyncPod)
[![License](https://img.shields.io/github/license/dashpay/dashsync-iOS)](https://github.com/dashpay/dashsync-iOS/blob/master/LICENSE)
[![dashpay/dashsync-iOS](https://tokei.rs/b1/github/dashpay/dashsync-iOS?category=lines)](https://github.com/dashpay/dashsync-iOS)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)

| Branch | Tests                                                                                      | Coverage                                                                                                                             | Linting                                                                    |
|--------|--------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------|
| master | [![Tests](https://github.com/dashpay/dashsync-iOS/workflows/Tests/badge.svg?branch=master)](https://github.com/dashpay/dashsync-iOS/actions) | [![codecov](https://codecov.io/gh/dashevo/dashsync-iOS/branch/master/graph/badge.svg)](https://codecov.io/gh/dashevo/dashsync-iOS) | ![Lint](https://github.com/dashpay/dashsync-iOS/workflows/Lint/badge.svg) |

## Example

### Requirements

- Install last version of rust:
`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Install protobuf and grpc:
`brew install protobuf grpc`
- Install cmake and make sure it is located in one of the following folders: `${PLATFORM_PATH}/Developer/usr/bin, ${DEVELOPER}/usr/bin:/usr/local/bin, /usr/bin, /bin, /usr/sbin, /sbin, /opt/homebrew/bin`

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

DashSyncPod is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'DashSyncPod'
```

## Contributing

Please abide by the [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.

Before contributing to the project, please take a look at the [contributing guidelines](CONTRIBUTING.md)
and the [style guide](STYLE_GUIDE.md).

To get more active, join the Dash developer community (recommended) at [Discord](https://discord.com/channels/484546513507188745/614505310593351735) or jump onto the [Forum](https://www.dash.org/forum/).

Learn more by reading the code and our [specifications](https://dashcore.readme.io/docs) or go deeper by reading our [Dash Improvement Proposals](https://github.com/dashpay/dips).

## Author

quantumexplorer, quantum@dash.org

## License

DashSyncPod is available under the MIT license. See the LICENSE file for more info.
