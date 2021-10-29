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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSDirectionalKey;

@interface DSDirectionalRange : NSObject

@property (nonatomic, readonly) DSDirectionalKey *key; //also includes if values should be returned ascending or descending
@property (nonatomic, readonly, nullable) NSData *lowerBoundsValue;
@property (nonatomic, readonly, nullable) NSData *upperBoundsValue;
@property (nonatomic, readonly) bool lowerBoundsIncluded;
@property (nonatomic, readonly) bool upperBoundsIncluded;

- (instancetype)initForKey:(NSData *)data withLowerBounds:(NSData *)lowerBoundsValue upperBounds:(NSData *)upperBoundsValue ascending:(bool)orderAscending includeLowerBounds:(bool)includeLowerBounds includeUpperBounds:(bool)includeUpperBounds;
- (instancetype)initForKey:(NSData *)data withLowerBounds:(NSData *)lowerBoundsValue ascending:(bool)orderAscending includeLowerBounds:(bool)includeLowerBounds;
- (instancetype)initForKey:(NSData *)data withUpperBounds:(NSData *)upperBoundsValue ascending:(bool)orderAscending includeUpperBounds:(bool)includeUpperBounds;

@end

NS_ASSUME_NONNULL_END
