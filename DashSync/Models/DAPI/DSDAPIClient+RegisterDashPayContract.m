//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSDAPIClient+RegisterDashPayContract.h"

#import "DSDashPlatform.h"
#import "DSBlockchainIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSDAPIClient (RegisterDashPayContract)

+ (DPContract *)ds_currentDashPayContract {
    DSDashPlatform *dpp = [DSDashPlatform sharedInstance];
    if (dpp.contract) {
        return dpp.contract;
    }
    
    DPContract *contract = [self ds_localDashPayContract];
    dpp.contract = contract;
    
    return contract;
}

- (void)ds_registerDashPayContractForUser:(DSBlockchainIdentity*)blockchainIdentity completion:(void (^)(NSError *_Nullable error))completion {
    DPContract *contract = [self.class ds_currentDashPayContract];
    DSDashPlatform *dpp = [DSDashPlatform sharedInstance];
    dpp.userId = blockchainIdentity.registrationTransitionHashIdentifier;
    DPSTPacket *stPacket = [dpp.stPacketFactory packetWithContract:contract];
    [self sendPacket:stPacket forUser:blockchainIdentity completion:completion];
}

#pragma mark - Private

+ (DPContract *)ds_localDashPayContract {
    // TODO: read async'ly
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *path = [bundle pathForResource:@"dashpay-contract" ofType:@"json"];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&error];
    NSAssert(error == nil, @"Failed reading contract json");
    DPJSONObject *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    NSAssert(error == nil, @"Failed parsing json");
    
    DSDashPlatform *dpp = [DSDashPlatform sharedInstance];
    DPContract *contract = [dpp.contractFactory contractFromRawContract:jsonObject error:&error];
    NSAssert(error == nil, @"Failed building DPContract");
    
    return contract;
}

@end

NS_ASSUME_NONNULL_END
