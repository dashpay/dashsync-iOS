//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#define MAINNET_STANDARD_PORT 9999
#define TESTNET_STANDARD_PORT 19999
#define DEVNET_STANDARD_PORT 20001

#define MAINNET_DEFAULT_HEADERS_MAX_AMOUNT 2000
#define TESTNET_DEFAULT_HEADERS_MAX_AMOUNT 2000
#define DEVNET_DEFAULT_HEADERS_MAX_AMOUNT 2000

#define MAINNET_DAPI_JRPC_STANDARD_PORT 3000
#define TESTNET_DAPI_JRPC_STANDARD_PORT 3000
#define DEVNET_DAPI_JRPC_STANDARD_PORT 3000

#define MAINNET_DAPI_GRPC_STANDARD_PORT 3010
#define TESTNET_DAPI_GRPC_STANDARD_PORT 3010
#define DEVNET_DAPI_GRPC_STANDARD_PORT 3010

#define PROTOCOL_VERSION_MAINNET 70232
#define DEFAULT_MIN_PROTOCOL_VERSION_MAINNET 70228

#define PROTOCOL_VERSION_TESTNET 70232
#define DEFAULT_MIN_PROTOCOL_VERSION_TESTNET 70228

#define PROTOCOL_VERSION_DEVNET 70232
#define DEFAULT_MIN_PROTOCOL_VERSION_DEVNET 70228

#define PLATFORM_PROTOCOL_VERSION_MAINNET 1
#define DEFAULT_MIN_PLATFORM_PROTOCOL_VERSION_MAINNET 1

#define PLATFORM_PROTOCOL_VERSION_TESTNET 1
#define DEFAULT_MIN_PLATFORM_PROTOCOL_VERSION_TESTNET 1

#define PLATFORM_PROTOCOL_VERSION_DEVNET 1
#define DEFAULT_MIN_PLATFORM_PROTOCOL_VERSION_DEVNET 1

#define DEFAULT_CHECKPOINT_PROTOCOL_VERSION 70218

#define MAX_VALID_MIN_PROTOCOL_VERSION 70228
#define MIN_VALID_MIN_PROTOCOL_VERSION 70228

#define MAX_TARGET_PROOF_OF_WORK_MAINNET 0x1e0fffffu // highest value for difficulty target (higher values are less difficult)
#define MAX_TARGET_PROOF_OF_WORK_TESTNET 0x1e0fffffu
#define MAX_TARGET_PROOF_OF_WORK_DEVNET 0x207fffffu

#define MAX_PROOF_OF_WORK_MAINNET @"00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".hexToData.reverse.UInt256 // highest value for difficulty target (higher values are less difficult)
#define MAX_PROOF_OF_WORK_TESTNET @"00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".hexToData.reverse.UInt256
#define MAX_PROOF_OF_WORK_DEVNET @"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".hexToData.reverse.UInt256

#define SPORK_PUBLIC_KEY_MAINNET @"04549ac134f694c0243f503e8c8a9a986f5de6610049c40b07816809b0d1d06a21b07be27b9bb555931773f62ba6cf35a25fd52f694d4e1106ccd237a7bb899fdd"

#define SPORK_PUBLIC_KEY_TESTNET @"046f78dcf911fbd61910136f7f0f8d90578f68d0b3ac973b5040fb7afb501b5939f39b108b0569dca71488f5bbf498d92e4d1194f6f941307ffd95f75e76869f0e"


#define SPORK_ADDRESS_MAINNET @"Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh"
#define SPORK_ADDRESS_TESTNET @"yjPtiKh2uwk3bDutTEA2q9mCtXyiZRWn55"

#define MAINNET_DASHPAY_CONTRACT_ID @""
#define MAINNET_DPNS_CONTRACT_ID @""

#define TESTNET_DASHPAY_CONTRACT_ID @"Bwr4WHCPz5rFVAD87RqTs3izo4zpzwsEdKPWUT1NS1C7"
#define TESTNET_DPNS_CONTRACT_ID @"GWRSAVFMjXx8HpQFaNJMqBV7MBgMK4br5UESsB4S31Ec"


#define DEFAULT_FEE_PER_B TX_FEE_PER_B
#define MIN_FEE_PER_B TX_FEE_PER_B // minimum relay fee on a 191byte tx
#define MAX_FEE_PER_B 1000         // slightly higher than a 1000bit fee on a 191byte tx

#define HEADER_WINDOW_BUFFER_TIME (WEEK_TIME_INTERVAL / 2) //This is about the time if we consider a block every 10 mins (for 500 blocks)
