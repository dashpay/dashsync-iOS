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

#import "DSDirectionalKey.h"

@interface DSDirectionalKey ()

@property (nonatomic, strong) NSData *key;
@property (nonatomic, assign) bool ascending;

@end

@implementation DSDirectionalKey

- (instancetype)initWithKey:(NSData *)key ascending:(bool)ascending {
    self = [super init];
    if (self) {
        self.key = key;
        self.ascending = ascending;
    }
    return self;
}

@end
