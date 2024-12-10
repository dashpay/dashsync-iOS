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

#import "DSSpecialTransactionEntity+CoreDataClass.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSAssetLockTransactionEntity : DSSpecialTransactionEntity
@end

@interface DSAssetLockTransactionEntity (CoreDataGeneratedAccessors)

- (void)insertObject:(DSTxOutputEntity *)value inCreditOutputsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromCreditOutputsAtIndex:(NSUInteger)idx;
- (void)insertCreditOutputs:(NSArray<DSTxOutputEntity *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeCreditOutputsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInCreditOutputsAtIndex:(NSUInteger)idx withObject:(DSTxOutputEntity *)value;
- (void)replaceCreditOutputsAtIndexes:(NSIndexSet *)indexes withOutputs:(NSArray<DSTxOutputEntity *> *)values;
- (void)addCreditOutputsObject:(DSTxOutputEntity *)value;
- (void)removeCreditOutputsObject:(DSTxOutputEntity *)value;
- (void)addCreditOutputs:(NSOrderedSet<DSTxOutputEntity *> *)values;
- (void)removeCreditOutputs:(NSOrderedSet<DSTxOutputEntity *> *)values;

@end

NS_ASSUME_NONNULL_END

#import "DSAssetLockTransactionEntity+CoreDataProperties.h"
