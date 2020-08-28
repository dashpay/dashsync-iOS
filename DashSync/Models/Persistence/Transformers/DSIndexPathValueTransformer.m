//  
//  Created by Andrew Podkovyrin
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

#import "DSIndexPathValueTransformer.h"

// see https://www.kairadiagne.com/2020/01/13/nssecurecoding-and-transformable-properties-in-core-data.html

@implementation DSIndexPathValueTransformer

+ (void)load {
    [NSValueTransformer setValueTransformer:DSIndexPathValueTransformer.new
                                    forName:@"DSIndexPathValueTransformer"];
}

+ (NSArray<Class> *)allowedTopLevelClasses {
    return @[NSIndexPath.class];
}

@end
