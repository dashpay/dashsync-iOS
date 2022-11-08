//  
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
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

#import "BigIntTypes.h"
#import "DSBloomFilter.h"
#import "DSGovernanceVotesSyncRequest.h"

@implementation DSGovernanceVotesSyncRequest

+ (instancetype)requestWithParentHash:(UInt256)parentHash {
    DSBloomFilter *bloomFilter = [[DSBloomFilter alloc] initWithFalsePositiveRate:0.01 forElementCount:20000 tweak:arc4random_uniform(10000) flags:1];
    return [[DSGovernanceVotesSyncRequest alloc] initWithParentHash:parentHash andBloomFilterData:[bloomFilter toData]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Governance Vote Sync"];
}

- (DSGovernanceRequestState)state {
    return DSGovernanceRequestState_GovernanceObjectVoteHashes;
}

@end
