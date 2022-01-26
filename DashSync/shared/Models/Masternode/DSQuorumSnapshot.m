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

#import "DSQuorumSnapshot.h"

@implementation DSQuorumSnapshot

+ (instancetype)quorumSnapshotWith:(QuorumSnapshot *)quorumSnapshot {
    DSQuorumSnapshot *snapshot = [[DSQuorumSnapshot alloc] init];
    NSMutableOrderedSet<NSNumber *> *memberList = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < quorumSnapshot->member_list_length; i++) {
        [memberList addObject:[NSNumber numberWithInteger:quorumSnapshot->member_list[i]]];
    }
    NSMutableOrderedSet<NSNumber *> *skipList = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < quorumSnapshot->skip_list_length; i++) {
        [skipList addObject:[NSNumber numberWithInteger:quorumSnapshot->skip_list[i]]];
    }
    snapshot.memberList = memberList;
    snapshot.skipList = skipList;
    snapshot.skipListMode = quorumSnapshot->skip_list_mode;
    return snapshot;
}

@end
