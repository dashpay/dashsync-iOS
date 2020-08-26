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

#import "DSDeleteEntityMigrationPolicy.h"

@implementation DSDeleteEntityMigrationPolicy

//- (BOOL)beginEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError *__autoreleasing  _Nullable *)error {
//    if (@available(iOS 9.0, *)) {
//        NSString *entityName = mapping.sourceEntityName;
//        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
//        NSBatchDeleteRequest *request = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fetchRequest];
//        NSManagedObjectContext *context = manager.sourceContext;
//        NSError *deleteError = nil;
//        [context executeRequest:request error:&deleteError];
//        NSAssert(deleteError == nil, @"Failed to delete all entities %@", deleteError);
//    } else {
//        NSAssert(NO, @"not supported");
//    }
//
//    return [super beginEntityMapping:mapping manager:manager error:error];
//}

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance
                                      entityMapping:(NSEntityMapping *)mapping
                                            manager:(NSMigrationManager *)manager
                                              error:(NSError *__autoreleasing  _Nullable *)error {
    return YES;
}

- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)dInstance
                                    entityMapping:(NSEntityMapping *)mapping
                                          manager:(NSMigrationManager *)manager
                                            error:(NSError *__autoreleasing  _Nullable *)error {
    return YES;
}

- (BOOL)performCustomValidationForEntityMapping:(NSEntityMapping *)mapping
                                        manager:(NSMigrationManager *)manager
                                          error:(NSError *__autoreleasing  _Nullable *)error {
    return YES;
}

@end
