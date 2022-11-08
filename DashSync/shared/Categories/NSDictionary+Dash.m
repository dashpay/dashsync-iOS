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

#import "NSData+Dash.h"
#import "NSDictionary+Dash.h"
#import "NSMutableData+Dash.h"

@implementation NSDictionary (Dash)

- (NSDictionary *)transformToDictionaryOfHexStringsToHexStrings {
    NSMutableDictionary *mDictionary = [NSMutableDictionary dictionary];
    for (NSData *data in self) {
        mDictionary[[data hexString]] = [self[data] hexString];
    }
    return [mDictionary copy];
}

+ (NSDictionary *)mergeDictionary:(NSDictionary *_Nullable)dictionary1 withDictionary:(NSDictionary *)dictionary2 {
    if (!dictionary1 || [dictionary1 count] == 0) {
        return dictionary2;
    } else {
        NSMutableDictionary *mergedDictionary = [dictionary1 mutableCopy];
        [mergedDictionary addEntriesFromDictionary:dictionary2];
        return mergedDictionary;
    }
}

@end
