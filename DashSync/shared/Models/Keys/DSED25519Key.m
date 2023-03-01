//  
//  Created by Vladimir Pirogov
//  Copyright © 2023 Dash Core Group. All rights reserved.
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

#import "DSED25519Key.h"
#import "NSData+Dash.h"

@interface DSED25519Key ()

@property (nonatomic, assign) UInt256 seckey;
@property (nonatomic, strong) NSData *pubkey;
//@property (nonatomic, assign) BOOL compressed;
@property (nonatomic, assign) UInt256 chaincode;
@property (nonatomic, assign) uint32_t fingerprint;
@property (nonatomic, assign) BOOL isExtended;

@end

@implementation DSED25519Key

// TODO: rust bindings for ed25519

//- (instancetype)initWithSeedData:(NSData *)seedData {
//    if (!(self = [self init])) return nil;
//
//    UInt512 I;
//
//    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seedData.bytes, seedData.length);
//
//    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
//    _seckey = secret;
////    _compressed = YES;
//    _chaincode = chain;
//    NoTimeLog(@"DSED25519Key.init_with_seed_data: %@: %@ %@", seedData.hexString, uint256_hex(secret), uint256_hex(chain));
//
//    //return (secp256k1_ec_seckey_verify(_ctx, _seckey.u8)) ? self : nil;
//}

@end
