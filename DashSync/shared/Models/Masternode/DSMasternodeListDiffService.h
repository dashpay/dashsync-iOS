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

#import <Foundation/Foundation.h>
#import "DSMasternodeListService.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListDiffService : DSMasternodeListService

@property (nonatomic, readonly) NSOrderedSet<NSData *> *retrievalQueue;
@property (nonatomic, readonly) NSUInteger retrievalQueueCount;

- (NSUInteger)addToRetrievalQueue:(NSData *)masternodeBlockHashData;
- (NSUInteger)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData;
- (NSUInteger)addToRetrievalQueueArray:(NSArray<NSData *> *_Nonnull)masternodeBlockHashDataArray;

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion;

@end

NS_ASSUME_NONNULL_END
