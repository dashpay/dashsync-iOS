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

#import "DSChain+Params.h"
#import "DSDashPlatform.h"
#import "DPContract.h"
#import "DSChain.h"

@interface DSDashPlatform ()

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic, null_resettable) NSMutableDictionary *knownContracts;
@property (strong, nonatomic) DPContract *dashPayContract;
@property (strong, nonatomic) DPContract *dpnsContract;
//@property (strong, nonatomic) DPContract *dashThumbnailContract;

@end

@implementation DSDashPlatform

- (instancetype)initWithChain:(DSChain *)chain {
    self = [super init];
    if (self) {
        _chain = chain; //must come first
    }
    return self;
}

static NSMutableDictionary *_platformChainDictionary = nil;
static dispatch_once_t platformChainToken = 0;

+ (instancetype)sharedInstanceForChain:(DSChain *)chain {
    NSParameterAssert(chain);

    dispatch_once(&platformChainToken, ^{
        _platformChainDictionary = [NSMutableDictionary dictionary];
    });
    DSDashPlatform *platformForChain = nil;
    @synchronized(self) {
        if (![_platformChainDictionary objectForKey:chain.uniqueID]) {
            platformForChain = [[DSDashPlatform alloc] initWithChain:chain];
            _platformChainDictionary[chain.uniqueID] = platformForChain;
        } else {
            platformForChain = [_platformChainDictionary objectForKey:chain.uniqueID];
        }
    }
    return platformForChain;
}

+ (NSString *)nameForContractWithIdentifier:(NSString *)identifier {
    if ([identifier hasPrefix:DASHPAY_CONTRACT]) {
        return @"DashPay";
    } else if ([identifier hasPrefix:DPNS_CONTRACT]) {
        return @"DPNS";
    } else if ([identifier hasPrefix:DASHTHUMBNAIL_CONTRACT]) {
        return @"DashThumbnail";
    }
    return @"Unnamed Contract";
}

- (NSMutableDictionary *)knownContracts {
    if (!_knownContracts) {
        _knownContracts = [NSMutableDictionary dictionaryWithObjects:@[[self dashPayContract], [self dpnsContract]/*, [self dashThumbnailContract]*/] forKeys:@[DASHPAY_CONTRACT, DPNS_CONTRACT/*, DASHTHUMBNAIL_CONTRACT*/]];
    }
    return _knownContracts;
}

- (DPContract *)dashPayContract {
    if (!_dashPayContract) {
        _dashPayContract = [DPContract localDashpayContractForChain:self.chain];
    }
    return _dashPayContract;
}

- (DPContract *)dpnsContract {
    if (!_dpnsContract) {
        _dpnsContract = [DPContract localDPNSContractForChain:self.chain];
    }
    return _dpnsContract;
}

//- (DPContract *)dashThumbnailContract {
//    if (!_dashThumbnailContract) {
//        _dashThumbnailContract = [DPContract localDashThumbnailContractForChain:self.chain];
//    }
//    return _dashThumbnailContract;
//}

@end
