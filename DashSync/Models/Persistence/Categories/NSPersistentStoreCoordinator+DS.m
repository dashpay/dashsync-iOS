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

#import "NSPersistentStoreCoordinator+DS.h"

@implementation NSPersistentStoreCoordinator (DS)

+ (void)ds_destroyStoreAtURL:(NSURL *)url {
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:NSManagedObjectModel.new];
    NSError *error = nil;
    if (@available(iOS 9.0, *)) {
        [psc destroyPersistentStoreAtURL:url withType:NSSQLiteStoreType options:nil error:&error];
    }
    else {
        NSCAssert(NO, @"not supported");
    }
    NSCAssert(error == nil, @"Failed to destroy persistent store %@", error);
}

+ (void)ds_replaceStoreAt:(NSURL *)targetURL with:(NSURL *)sourceURL {
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:NSManagedObjectModel.new];
    NSError *error = nil;
    if (@available(iOS 9.0, *)) {
        [psc replacePersistentStoreAtURL:targetURL
                      destinationOptions:nil
              withPersistentStoreFromURL:sourceURL
                           sourceOptions:nil
                               storeType:NSSQLiteStoreType
                                   error:&error];
    } else {
        NSCAssert(NO, @"not supported");
    }
    NSCAssert(error == nil, @"Failed to replace persistent store %@", error);
}

+ (NSDictionary <NSString *, id> *)ds_metadataAt:(NSURL *)storeURL {
    NSError *error = nil;
   NSDictionary <NSString *, id> *result = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                                      URL:storeURL
                                                                                                  options:nil
                                                                                                    error:&error];
    return result;
}

- (NSPersistentStore *)ds_addPersistentStoreAt:(NSURL *)storeURL options:(NSDictionary *)options {
    NSError *error = nil;
   NSPersistentStore *store = [self addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error];
    NSCAssert(error == nil, @"Failed to add persistent store %@", error);
    return store;
}

@end
