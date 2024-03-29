//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSPlatformDocumentsRequest.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSPlatformTreeQuery;

typedef NS_ENUM(NSUInteger, NSPredicateCBORDataOptions)
{
    NSPredicateCBORDataOptions_None = 0,
    NSPredicateCBORDataOptions_DataToBase64 = 1
};

@interface NSPredicate (CBORData)

- (NSData *)dashPlatormWhereData;
- (NSData *)singleElementQueryKey;
- (NSArray<NSData *> *)multipleElementQueryKey;
- (DSPlatformTreeQuery *)platformTreeQuery;
- (NSData *)secondaryIndexPathForQueryType:(DSPlatformQueryType)queryType;

@end

NS_ASSUME_NONNULL_END
