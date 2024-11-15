//
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSAssetUnlockTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSAssetUnlockTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSAssetUnlockTransactionEntity *> *)fetchRequest;

@property (nonatomic, assign) uint64_t index;
@property (nonatomic, assign) uint32_t fee;
@property (nonatomic, assign) uint32_t requestedHeight;
@property (nullable, nonatomic, retain) NSData *quorumHash;
@property (nullable, nonatomic, retain) NSData *quorumSignature;

@end

NS_ASSUME_NONNULL_END
