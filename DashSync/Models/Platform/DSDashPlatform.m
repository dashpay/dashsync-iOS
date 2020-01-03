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

#import "DSDashPlatform.h"

#import "DPContractFacade.h"
#import "DPDocumentFacade.h"
#import "DPSTPacketFacade.h"
#import "DPSTPacketHeaderFacade.h"
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSDashPlatform ()

@property (strong, nonatomic) DPContractFacade *contractFacade;
@property (strong, nonatomic) DPDocumentFacade *documentFacade;
@property (strong, nonatomic) DSChain *chain;
//@property (strong, nonatomic) DPSTPacketFacade *stPacketFacade;
//@property (strong, nonatomic) DPSTPacketHeaderFacade *stPacketHeaderFacade;

@end

@implementation DSDashPlatform

- (instancetype)initWithChain:(DSChain*)chain {

    self = [super init];
    if (self) {
        _contractFacade = [[DPContractFacade alloc] init];
        _documentFacade = [[DPDocumentFacade alloc] initWithPlaform:self];
        _chain = chain;
//        _stPacketFacade = [[DPSTPacketFacade alloc] initWithMerkleRootOperation:merkleRootOperation
//                                                              base58DataEncoder:base58DataEncoder];
//        _stPacketHeaderFacade = [[DPSTPacketHeaderFacade alloc] init];
    }
    return self;
}

static NSMutableDictionary * _platformChainDictionary = nil;
static dispatch_once_t platformChainToken = 0;

+(instancetype)sharedInstanceForChain:(DSChain*)chain {
    
    NSParameterAssert(chain);
    
    dispatch_once(&platformChainToken, ^{
        _platformChainDictionary = [NSMutableDictionary dictionary];
    });
       DSDashPlatform * platformForChain = nil;
       @synchronized(self) {
           if (![_platformChainDictionary objectForKey:chain.uniqueID]) {
               platformForChain = [[DSDashPlatform alloc] initWithChain:chain];
               [_platformChainDictionary setObject:platformForChain forKey:chain.uniqueID];
           } else {
               platformForChain = [_platformChainDictionary objectForKey:chain.uniqueID];
           }
       }
    return platformForChain;
}

- (id<DPContractFactory>)contractFactory {
    return self.contractFacade;
}

- (id<DPDocumentFactory>)documentFactory {
    return self.documentFacade;
}

@end

NS_ASSUME_NONNULL_END
