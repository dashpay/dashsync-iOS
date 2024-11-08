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

#import "DSAssetLockTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSAssetLockTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSAssetLockTransactionEntity *> *)fetchRequest;

@property (nonatomic, retain) NSOrderedSet<DSTxOutputEntity *> *creditOutputs;

@end

NS_ASSUME_NONNULL_END
