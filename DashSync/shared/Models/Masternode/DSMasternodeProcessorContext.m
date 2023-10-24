//
//  Created by Vladimir Pirogov
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSMasternodeProcessorContext.h"
#import "NSData+Dash.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSMasternodeManager.h"

@implementation DSMasternodeProcessorContext

- (NSString *)description {
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" {%@}: [%@: %@ (%u)] genesis: %@ protocol: %u, insight: %i, from_snapshot: %i, dip-24: %i}", self.chain.name, self.peer.location, self.peer.useragent, self.peer.version, uint256_hex(self.chain.genesisHash), self.chain.protocolVersion, self.useInsightAsBackup, self.isFromSnapshot, self.isDIP0024]];
}

- (BOOL)saveCLSignature:(UInt256)blockHash signature:(UInt768)signature {
    return [self.chain.chainManager.masternodeManager saveCLSignature:uint256_data(blockHash) signatureData:uint768_data(signature)];
}

- (void)blockUntilGetInsightForBlockHash:(UInt256)blockHash {
    [self.chain blockUntilGetInsightForBlockHash:blockHash];
}

@end
