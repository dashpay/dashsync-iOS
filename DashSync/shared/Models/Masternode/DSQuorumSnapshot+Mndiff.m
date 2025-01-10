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

//#import "DSQuorumSnapshot+Mndiff.h"
//
//@implementation DSQuorumSnapshot (Mndiff)
//
//+ (instancetype)quorumSnapshotWith:(LLMQSnapshot *)quorumSnapshot forBlockHash:(UInt256)blockHash {
//    DSQuorumSnapshot *snapshot = [[DSQuorumSnapshot alloc] init];
//    NSUInteger memberListLength = quorumSnapshot->member_list_length;
//    NSData *memberList = [NSData dataWithBytes:quorumSnapshot->member_list length:memberListLength];
//    NSUInteger skipListLength = quorumSnapshot->skip_list_length;
//    NSMutableArray<NSNumber *> *skipList = [NSMutableArray arrayWithCapacity:skipListLength];
//    const int32_t *skip_list_bytes = quorumSnapshot->skip_list;
//    for (NSUInteger i = 0; i < skipListLength; i++) {
//        [skipList addObject:@(skip_list_bytes[i])];
//    }
//    [snapshot setMemberList:[memberList copy]];
//    [snapshot setSkipList:[skipList copy]];
//    [snapshot setSkipListMode:quorumSnapshot->skip_list_mode];
//    [snapshot setBlockHash:blockHash];
//    return snapshot;
//}
//
//- (LLMQSnapshot *)ffi_malloc {
//    LLMQSnapshot *entry = malloc(sizeof(LLMQSnapshot));
//    NSUInteger skipListCount = [self.skipList count];
//    int32_t *skipList = malloc(skipListCount * sizeof(int32_t));
//    NSUInteger i = 0;
//    for (NSNumber *skipMember in self.skipList) {
//        skipList[i] = skipMember.intValue;
//        i++;
//    }
//    entry->member_list = data_malloc(self.memberList);
//    entry->member_list_length = self.memberList.length;
//    entry->skip_list = skipList;
//    entry->skip_list_length = skipListCount;
//    entry->skip_list_mode = self.skipListMode;
//    return entry;
//}
//
//+ (void)ffi_free:(LLMQSnapshot *)entry {
//    free(entry->member_list);
//    free(entry->skip_list);
//    free(entry);
//}
//
//@end
