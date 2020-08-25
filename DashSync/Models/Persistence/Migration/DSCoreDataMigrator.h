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

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/**
Responsible for handling Core Data model migrations.

The default Core Data model migration approach is to go from earlier version to all possible future versions.

So, if we have 4 model versions (1, 2, 3, 4), you would need to create the following mappings 1 to 4, 2 to 4 and 3 to 4.
Then when we create model version 5, we would create mappings 1 to 5, 2 to 5, 3 to 5 and 4 to 5. You can see that for each
new version we must create new mappings from all previous versions to the current version. This does not scale well, in the
above example 4 new mappings have been created. For each new version you must add n-1 new mappings.

Instead the solution below uses an iterative approach where we migrate mutliple times through a chain of model versions.

So, if we have 4 model versions (1, 2, 3, 4), you would need to create the following mappings 1 to 2, 2 to 3 and 3 to 4.
Then when we create model version 5, we only need to create one additional mapping 4 to 5. This greatly reduces the work
required when adding a new version.
*/
@interface DSCoreDataMigrator : NSObject

+ (BOOL)requiresMigration;
+ (void)performMigration:(void(^)(void))completion;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
