//
//  Created by Sam Westrich
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "merk.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSPlatformTreeQuery : NSObject

@property (nonatomic, readonly) NSArray<NSData *> *platformQueryKeys;
@property (nonatomic, readonly) NSArray<NSArray<NSData *> *> *platformQueryKeyRanges;
@property (nonatomic, readonly) Keys *keys;

+ (DSPlatformTreeQuery *)platformTreeQueryForKeys:(NSArray<NSData *> *)keys;

+ (DSPlatformTreeQuery *)platformTreeQueryForRanges:(NSArray<NSArray<NSData *> *> *)keys;

+ (DSPlatformTreeQuery *)platformTreeQueryForKeys:(NSArray<NSData *> *)keys andRanges:(NSArray<NSArray<NSData *> *> *)keys;

@end

NS_ASSUME_NONNULL_END
