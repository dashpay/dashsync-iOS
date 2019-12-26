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

#import "DashPlatformProtocol.h"

#import "DPContractFacade.h"
#import "DPDocumentFacade.h"
#import "DPSTPacketFacade.h"
#import "DPSTPacketHeaderFacade.h"

NS_ASSUME_NONNULL_BEGIN

@interface DashPlatformProtocol ()

@property (strong, nonatomic) DPContractFacade *contractFacade;
@property (strong, nonatomic) DPDocumentFacade *documentFacade;
@property (strong, nonatomic) DPSTPacketFacade *stPacketFacade;
@property (strong, nonatomic) DPSTPacketHeaderFacade *stPacketHeaderFacade;

@end

@implementation DashPlatformProtocol

- (instancetype)initWithBase58DataEncoder:(id<DPBase58DataEncoder>)base58DataEncoder
                          entropyProvider:(id<DPEntropyProvider>)entropyProvider
                      merkleRootOperation:(id<DPMerkleRootOperation>)merkleRootOperation {
    NSParameterAssert(base58DataEncoder);
    NSParameterAssert(entropyProvider);
    NSParameterAssert(merkleRootOperation);

    self = [super init];
    if (self) {
        _contractFacade = [[DPContractFacade alloc] initWithBase58DataEncoder:base58DataEncoder];
        _documentFacade = [[DPDocumentFacade alloc] initWithDPP:self
                                                entropyProvider:entropyProvider
                                              base58DataEncoder:base58DataEncoder];
        _stPacketFacade = [[DPSTPacketFacade alloc] initWithMerkleRootOperation:merkleRootOperation
                                                              base58DataEncoder:base58DataEncoder];
        _stPacketHeaderFacade = [[DPSTPacketHeaderFacade alloc] init];
    }
    return self;
}

- (id<DPContractFactory>)contractFactory {
    return self.contractFacade;
}

- (id<DPDocumentFactory>)documentFactory {
    return self.documentFacade;
}

- (id<DPSTPacketFactory>)stPacketFactory {
    return self.stPacketFacade;
}

- (id<DPSTPacketHeaderFactory>)stPacketHeaderFactory {
    return self.stPacketHeaderFacade;
}

@end

NS_ASSUME_NONNULL_END
