//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//  Copyright © 2015 Michal Zaborowski. All rights reserved.
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

NS_ASSUME_NONNULL_BEGIN

@class DSOperation;

@interface DSOperationConditionResult : NSObject

@property (nonatomic, readonly, assign, getter=isSuccees) BOOL success;
@property (nonatomic, readonly, nullable) NSError *error;

+ (DSOperationConditionResult *)satisfiedResult;
+ (DSOperationConditionResult *)failedResultWithError:(NSError *)error;

+ (void)evaluateConditions:(NSArray *)conditions operation:(DSOperation *)operation completion:(nullable void (^)(NSArray<NSError *> *_Nullable errors))completion;

@end

NS_ASSUME_NONNULL_END
