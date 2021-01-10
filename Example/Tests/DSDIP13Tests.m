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
#import "DSChain.h"
#import "DSDerivationPath.h"
#import "NSString+Bitcoin.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSBLSKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "NSMutableData+Dash.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSECDSAKey.h"
#import "NSData+Encryption.h"
#import "DSUInt256IndexPath.h"

@interface DSDIP13Tests : XCTestCase

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSWallet *wallet;
@property (strong, nonatomic) NSData *seed;

@end

@implementation DSDIP13Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain testnet];
    NSString * seedPhrase = @"birth kingdom trash renew flavor utility donkey gasp regular alert pave layer";
    
    self.seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    self.wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                               setCreationDate:0 forChain:self.chain storeSeedPhrase:NO isTransient:YES];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)test256BitPathECDSADerivation0 {
    /* m/0x775d3854c910b7dee436869c4724bed2fe0784e198b8a39f02bbb49d8ebcfc3b/0xf537439f36d04a15474ff7423e4b904a14373fafb37a41db74c84f1dbb5c89a6'/0x4c4592ca670c983fc43397dfd21a6f427fac9b4ac53cb4dcdc6522ec51e81e79/0
     */
    int length = 3;
    UInt256 index0 = @"775d3854c910b7dee436869c4724bed2fe0784e198b8a39f02bbb49d8ebcfc3b".hexToData.UInt256;
    UInt256 index1 = @"f537439f36d04a15474ff7423e4b904a14373fafb37a41db74c84f1dbb5c89a6".hexToData.UInt256;
    UInt256 index2 = @"4c4592ca670c983fc43397dfd21a6f427fac9b4ac53cb4dcdc6522ec51e81e79".hexToData.UInt256;
    UInt256 indexes[] = {index0, index1, index2};
    BOOL hardened1[] = {NO, YES, NO};
    
    DSDerivationPath * derivationPath = [DSDerivationPath derivationPathWithIndexes:indexes hardened:hardened1 length:length type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Unknown onChain:self.chain];
    
    DSECDSAKey * key = (DSECDSAKey *)[derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:0] fromSeed:self.seed];
    
    XCTAssertEqualObjects(key.secretKeyString,@"e8781fdef72862968cd9a4d2df34edaf9dcc5b17629ec505f0d2d1a8ed6f9f09",@"keys should match");
    
}

-(void)test256BitPathECDSADerivation1 {
    /* m/9'/5'/15'/0'/0x555d3854c910b7dee436869c4724bed2fe0784e198b8a39f02bbb49d8ebcfc3a'/0xa137439f36d04a15474ff7423e4b904a14373fafb37a41db74c84f1dbb5c89b5'/0
     */
    int length = 6;
    UInt256 index0 = @"555d3854c910b7dee436869c4724bed2fe0784e198b8a39f02bbb49d8ebcfc3a".hexToData.UInt256;
    UInt256 index1 = @"a137439f36d04a15474ff7423e4b904a14373fafb37a41db74c84f1dbb5c89b5".hexToData.UInt256;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE),uint256_from_long(5), uint256_from_long(FEATURE_PURPOSE_DASHPAY), uint256_from_long(0), index0, index1};
    BOOL hardened1[] = {YES, YES, YES, YES, YES, YES};
    
    DSDerivationPath * derivationPath = [DSDerivationPath derivationPathWithIndexes:indexes hardened:hardened1 length:length type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Unknown onChain:self.chain];
    
    DSECDSAKey * key = (DSECDSAKey *)[derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:0] fromSeed:self.seed];
    
    XCTAssertEqualObjects(key.secretKeyString,@"fac40790776d171ee1db90899b5eb2df2f7d2aaf35ad56f07ffb8ed2c57f8e60",@"keys should match");
    
}

@end
