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

#import "DSMessageRequest.h"

@implementation DSMessageRequest

+ (instancetype)requestWithType:(NSString *)type {
    return [[DSMessageRequest alloc] initWithType:type];
}

- (instancetype)initWithType:(NSString *)type {
    self = [super init];
    if (self) {
        _type = type;
    }
    return self;
}

- (NSData *)toData {
    return [NSData data];
}

- (BOOL)isEqual:(id)object {
    return [[self toData] isEqual:[object toData]];
}

// MARK: NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    return [super init];
}


// MARK: NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}



@end
