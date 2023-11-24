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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSCoreDataMigrationVersionValue)
{
    DSCoreDataMigrationVersionValue_1 = 1,
    DSCoreDataMigrationVersionValue_2 = 2,
    DSCoreDataMigrationVersionValue_3 = 3,
    DSCoreDataMigrationVersionValue_4 = 4,
    DSCoreDataMigrationVersionValue_5 = 5,
    DSCoreDataMigrationVersionValue_6 = 6,
    DSCoreDataMigrationVersionValue_7 = 7,
    DSCoreDataMigrationVersionValue_8 = 8,
    DSCoreDataMigrationVersionValue_9 = 9,
    DSCoreDataMigrationVersionValue_10 = 10,
    DSCoreDataMigrationVersionValue_11 = 11,
    DSCoreDataMigrationVersionValue_12 = 12,
    DSCoreDataMigrationVersionValue_13 = 13,
    DSCoreDataMigrationVersionValue_14 = 14,
    DSCoreDataMigrationVersionValue_15 = 15,
    DSCoreDataMigrationVersionValue_16 = 16,
    DSCoreDataMigrationVersionValue_17 = 17,
    DSCoreDataMigrationVersionValue_18 = 18,
    DSCoreDataMigrationVersionValue_19 = 19,
    DSCoreDataMigrationVersionValue_20 = 20,
};

@interface DSCoreDataMigrationVersion : NSObject

+ (DSCoreDataMigrationVersionValue)current;
+ (NSString *)modelResourceForVersion:(DSCoreDataMigrationVersionValue)version;

/// Returns `NSNotFound` if there's no next version
+ (DSCoreDataMigrationVersionValue)nextVersionAfter:(DSCoreDataMigrationVersionValue)version;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
