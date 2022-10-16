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

#import "DSQuorumSnapshot+Mndiff.h"

@implementation DSQuorumSnapshot (Mndiff)

+ (instancetype)quorumSnapshotWith:(LLMQSnapshot *)quorumSnapshot forBlockHash:(UInt256)blockHash {
    DSQuorumSnapshot *snapshot = [[DSQuorumSnapshot alloc] init];
    NSUInteger memberListLength = quorumSnapshot->member_list_length;
    NSMutableOrderedSet<NSNumber *> *memberList = [NSMutableOrderedSet orderedSetWithCapacity:memberListLength];
    NSUInteger i = 0;
    for (i = 0; i < memberListLength; i++) {
        [memberList addObject:[NSNumber numberWithUnsignedChar:quorumSnapshot->member_list[i]]];
    }
    NSUInteger skipListLength = quorumSnapshot->skip_list_length;
    NSMutableOrderedSet<NSNumber *> *skipList = [NSMutableOrderedSet orderedSetWithCapacity:skipListLength];
    for (i = 0; i < skipListLength; i++) {
        [skipList addObject:[NSNumber numberWithInteger:quorumSnapshot->skip_list[i]]];
    }
    [snapshot setMemberList:[memberList copy]];
    [snapshot setSkipList:[skipList copy]];
    [snapshot setSkipListMode:quorumSnapshot->skip_list_mode];
    [snapshot setBlockHash:blockHash];
    return snapshot;
}

- (LLMQSnapshot *)ffi_malloc {
    LLMQSnapshot *entry = malloc(sizeof(LLMQSnapshot));
    NSUInteger i = 0;
    NSUInteger memberCount = [self.memberList count];
    uint8_t *members = malloc(memberCount * sizeof(uint8_t));
    for (NSNumber *member in self.memberList) {
        members[i] = (uint8_t) member.unsignedCharValue;
        i++;
    }
    entry->member_list = members;
    entry->member_list_length = memberCount;
    NSUInteger skipListCount = [self.skipList count];
    int32_t *skipList = malloc(skipListCount * sizeof(int32_t));
    i = 0;
    for (NSNumber *skipMember in self.memberList) {
        skipList[i] = (int32_t) skipMember.integerValue;
        i++;
    }
    entry->skip_list = skipList;
    entry->skip_list_length = skipListCount;
    entry->skip_list_mode = self.skipListMode;
    return entry;
}

+ (void)ffi_free:(LLMQSnapshot *)entry {
    free(entry->member_list);
    free(entry->skip_list);
    free(entry);
}

@end
