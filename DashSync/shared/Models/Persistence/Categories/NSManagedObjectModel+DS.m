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

#import "NSManagedObjectModel+DS.h"

#import "DSTransaction.h"

@implementation NSManagedObjectModel (DS)

+ (NSManagedObjectModel *)ds_managedObjectModelForResource:(NSString *)resource {
    NSBundle *resourceBundle = [[DSEnvironment sharedInstance] resourceBundle];
    NSParameterAssert(resourceBundle);

    NSString *subdirectory = @"DashSync.momd";
    NSURL *omoURL = [resourceBundle URLForResource:resource
                                     withExtension:@"omo"
                                      subdirectory:subdirectory];
    NSURL *momURL = [resourceBundle URLForResource:resource
                                     withExtension:@"mom"
                                      subdirectory:subdirectory];

    NSAssert(omoURL || momURL, @"unable to find model");

    NSURL *url = omoURL ?: momURL;
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    NSParameterAssert(model);

    return model;
}

+ (NSManagedObjectModel *)ds_compatibleModelForStoreMetadata:(NSDictionary<NSString *, id> *)metadata {
    NSBundle *resourceBundle = [[DSEnvironment sharedInstance] resourceBundle];
    return [NSManagedObjectModel mergedModelFromBundles:@[resourceBundle] forStoreMetadata:metadata];
}

@end
