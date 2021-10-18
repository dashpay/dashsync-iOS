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

#import "DSDirectionalRange.h"
#import "DSDirectionalKey.h"

@interface DSDirectionalRange ()

@property (nonatomic, strong) DSDirectionalKey *key;
@property (nonatomic, strong) NSData *lowerBoundsValue;
@property (nonatomic, strong) NSData *upperBoundsValue;
@property (nonatomic, assign) bool lowerBoundsIncluded;
@property (nonatomic, assign) bool upperBoundsIncluded;

@end

@implementation DSDirectionalRange

- (instancetype)initForKey:(NSData *)key withLowerBounds:(NSData *)lowerBoundsValue upperBounds:(NSData *)upperBoundsValue ascending:(bool)orderAscending includeLowerBounds:(bool)includeLowerBounds includeUpperBounds:(bool)includeUpperBounds {
    self = [super init];
    if (self) {
        self.key = [[DSDirectionalKey alloc] initWithKey:key ascending:orderAscending];
        self.lowerBoundsValue = lowerBoundsValue;
        self.upperBoundsValue = upperBoundsValue;
        self.lowerBoundsIncluded = includeLowerBounds;
        self.upperBoundsIncluded = includeUpperBounds;
    }
    return self;
}

- (instancetype)initForKey:(NSData *)key withLowerBounds:(NSData *)lowerBoundsValue ascending:(bool)orderAscending includeLowerBounds:(bool)includeLowerBounds {
    self = [super init];
    if (self) {
        self.key = [[DSDirectionalKey alloc] initWithKey:key ascending:orderAscending];
        self.lowerBoundsValue = lowerBoundsValue;
        self.upperBoundsValue = nil;
        self.lowerBoundsIncluded = includeLowerBounds;
        self.upperBoundsIncluded = NO;
    }
    return self;
}
- (instancetype)initForKey:(NSData *)key withUpperBounds:(NSData *)upperBoundsValue ascending:(bool)orderAscending includeUpperBounds:(bool)includeUpperBounds {
    self = [super init];
    if (self) {
        self.key = [[DSDirectionalKey alloc] initWithKey:key ascending:orderAscending];
        self.lowerBoundsValue = nil;
        self.upperBoundsValue = upperBoundsValue;
        self.lowerBoundsIncluded = NO;
        self.upperBoundsIncluded = includeUpperBounds;
    }
    return self;
}

@end
