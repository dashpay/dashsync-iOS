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

typedef NS_ENUM(NSInteger, DSCoreDataMigrationVersionValue) {
    DSCoreDataMigrationVersionValue_1 = 1,
    DSCoreDataMigrationVersionValue_2,
    DSCoreDataMigrationVersionValue_3,
    DSCoreDataMigrationVersionValue_4,
    DSCoreDataMigrationVersionValue_5,
    DSCoreDataMigrationVersionValue_6,
    DSCoreDataMigrationVersionValue_7,
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
