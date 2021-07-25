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

#import <XCTest/XCTest.h>

#import "BigIntTypes.h"
#import "DSAccount.h"
#import "DSBlockchainIdentity.h"
#import "DSChain.h"
#import "DSCreditFundingTransaction.h"
#import "DSWallet.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSAttackTests : XCTestCase

@end

@implementation DSAttackTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGrindingAttack {
    //    UInt256 randomNumber = uint256_random;
    //    UInt256 seed = uint256_random;
    //    NSUInteger maxDepth = 0;
    //    NSTimeInterval timeToRun = 360;
    //    NSDate * startTime = [NSDate date];
    //    uint32_t count = 0;
    //    //my computer can do 13841280000000 hashes per year
    //    //the probability to find something with 65 leading zeros is
    //    while ([startTime timeIntervalSinceNow] < timeToRun) {
    //        UInt256 hash = [[NSData dataWithUInt256:seed] blake2s];
    //        UInt256 xor = uint256_xor(randomNumber, hash);
    //        uint16_t depth = uint256_firstbits(xor);
    //        if (depth > maxDepth) {
    //            NSLog(@"found a new max %d %@",depth,uint256_bin(xor));
    //            maxDepth = depth;
    //        }
    //        if (count % 10000000 == 0) {
    //            NSTimeInterval timeSinceStart = [startTime timeIntervalSinceNow];
    //            NSLog(@"Speed %.2f/s",-(count/timeSinceStart));
    //        }
    //        if (depth > 30) {
    //            NSLog(@"looking for %@ (hex)",uint256_hex(randomNumber));
    //            NSLog(@"blake2s hash is %@ (hex) for %@ (hex)",uint256_hex(hash),uint256_hex(seed));
    //        }
    //        seed = uInt256AddOne(seed);
    //        count++;
    //    }
}

//- (void)testOMGImpossibleBlakeGrindingAttack {
//    UInt256 randomNumber = ((UInt256){.u32 = {1961109525, 1871706845, 2577990507, 2759128555, 819186663, 3239291074, 874001513, 2113717106}});
//    UInt256 seed = ((UInt256){.u32 = {4060203857, 3714963480, 1070954119, 554325067, 296905764, 3386621160, 1423567590, 2901719126}});
//    NSUInteger maxDepth = 0;
//    NSTimeInterval timeToRun = 360;
//    NSDate * startTime = [NSDate date];
//    uint32_t count = 120275227;
//    UInt256 r = ((UInt256) { .u64 = { count, 0, 0, 0 } });
//    seed = uInt256Add(seed, r);
//    //my computer can do 13841280000000 hashes per year
//    //the probability to find something with 65 leading zeros is
//    while ([startTime timeIntervalSinceNow] < timeToRun) {
//        UInt256 hash = [[NSData dataWithUInt256:seed] blake2s];
//        UInt256 xor = uint256_xor(randomNumber, hash);
//        uint16_t depth = uint256_firstbits(xor);
//        if (depth > maxDepth) {
//            NSLog(@"found a new max %d",depth);
//            maxDepth = depth;
//        }
//        if (count % 10000000 == 0) {
//            NSTimeInterval timeSinceStart = [startTime timeIntervalSinceNow];
//            NSLog(@"Speed %.2f/s",-(count/timeSinceStart));
//        }
//        if (depth > 30) {
//            NSLog(@"%@",uint256_bin(xor));
//            NSLog(@"looking for %@ (bin)",uint256_bin(randomNumber));
//            NSLog(@"blake2s hash is %@ (bin) for %@ (hex)",uint256_bin(hash),uint256_hex(seed));
//        }
//        seed = uInt256AddOne(seed);
//        count++;
//    }
//}

- (void)testIdentityGrindingAttack {
    //    DSChain * chain = [DSChain devnetWithIdentifier:@"devnet-mobile"];
    //
    //    //NSString * seedPhrase = @"burger second sausage shriff police accident bargain survey unhappy juice flag script";
    //
    //    DSWallet * wallet = [[chain wallets] objectAtIndex:0];
    //
    //    DSBlockchainIdentity * firstIdentity = [wallet defaultBlockchainIdentity];
    //
    //    //[DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];
    //
    //    UInt256 firstIdentityUniqueIDBlake2s = [uint256_data(firstIdentity.uniqueID) blake2s];
    //
    //    DSBlockchainIdentity * identity = [wallet createBlockchainIdentityOfType:DSBlockchainIdentityType_User];
    //
    //    NSUInteger maxDepth = 0;
    //    NSTimeInterval timeToRun = 360;
    //    uint32_t amount = 154215;
    //    NSDate * startTime = [NSDate date];
    //
    //    NSMutableData *script = [NSMutableData data];
    //
    //    [script appendCreditBurnScriptPubKeyForAddress:[identity registrationFundingAddress] forChain:chain];
    //    DSAccount * account = [wallet accountWithNumber:0];
    //
    //    DSECDSAKey * signingKey = [DSECDSAKey keyWithPrivateKey:@"cPjNYqR7hwygxzAPs2makWSbY96kJd5pA7PQxmcdWpFkvCobxMtw" onChain:chain];
    //
    //    DSCreditFundingTransaction *transaction = [[DSCreditFundingTransaction alloc] initOnChain:chain];
    //    [account updateTransaction:transaction forAmounts:@[@(amount)] toOutputScripts:@[script] withFee:1000 shuffleOutputOrder:NO];
    //    uint32_t changeAmount = [transaction.amounts[1] unsignedIntValue];
    //    while ([startTime timeIntervalSinceNow] < timeToRun) {
    //        transaction.amounts = [NSMutableArray arrayWithObjects:@(amount),@(changeAmount),nil];
    //        [transaction signWithPreorderedPrivateKeys:@[signingKey]];
    //        DSUTXO outpoint = { .hash = uint256_reverse(transaction.txHash), .n = 0 };
    //        UInt256 hash = [uint256_data([dsutxo_data(outpoint) SHA256_2]) blake2s];
    //        UInt256 xor = uint256_xor(firstIdentityUniqueIDBlake2s, hash);
    //        uint16_t depth = uint256_firstbits(xor);
    //        if (amount % 1000 == 0) {
    //            NSTimeInterval timeSinceStart = [startTime timeIntervalSinceNow];
    //            NSLog(@"Speed %.2f/s",-(amount/timeSinceStart));
    //        }
    //        if (depth > maxDepth) {
    //            NSLog(@"found a new max %d at %d/%d",depth,amount,changeAmount);
    //            maxDepth = depth;
    //            if (depth > 20) {
    //                NSLog(@"found it with transaction data %@",transaction.toData.hexString);
    //                ;
    //                NSLog(@"identity to attack was %@ (base58), blake2s is %@ (hex)",uint256_base58(firstIdentity.uniqueID), uint256_hex(firstIdentityUniqueIDBlake2s));
    //                NSLog(@"found identity is %@ (base58), blake2s is %@ (hex)",uint256_base58([dsutxo_data(outpoint) SHA256_2]), uint256_hex(hash));
    //            }
    //        }
    //        amount++;
    //        changeAmount--;
    //    }
}

@end
