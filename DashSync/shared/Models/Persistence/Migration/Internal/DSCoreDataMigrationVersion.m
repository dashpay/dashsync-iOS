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

#import "DSCoreDataMigrationVersion.h"

@implementation DSCoreDataMigrationVersion

+ (DSCoreDataMigrationVersionValue)current {
    return DSCoreDataMigrationVersionValue_11;
}

+ (NSString *)modelResourceForVersion:(DSCoreDataMigrationVersionValue)version {
    switch (version) { //!OCLINT
        case DSCoreDataMigrationVersionValue_1: return @"DashSync 1";
        case DSCoreDataMigrationVersionValue_2: return @"DashSync 2";
        case DSCoreDataMigrationVersionValue_3: return @"DashSync 3";
        case DSCoreDataMigrationVersionValue_4: return @"DashSync 4";
        case DSCoreDataMigrationVersionValue_5: return @"DashSync 5";
        case DSCoreDataMigrationVersionValue_6: return @"DashSync 6";
        case DSCoreDataMigrationVersionValue_7: return @"DashSync 7";
        case DSCoreDataMigrationVersionValue_8: return @"DashSync 8";
        case DSCoreDataMigrationVersionValue_9: return @"DashSync 9";
        case DSCoreDataMigrationVersionValue_10: return @"DashSync 10";
        case DSCoreDataMigrationVersionValue_11: return @"DashSync 11";
        default:
            return [NSString stringWithFormat:@"DashSync %ld", (long)version];
    }
}

+ (DSCoreDataMigrationVersionValue)nextVersionAfter:(DSCoreDataMigrationVersionValue)version {
    NSUInteger next = version + 1;
    if (next <= self.current) {
        return next;
    }
    return NSNotFound;
}

@end
