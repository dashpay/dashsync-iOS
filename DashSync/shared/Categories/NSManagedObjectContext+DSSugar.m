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

#import "DSDataController.h"
#import "DSLogger.h"
#import "NSManagedObjectContext+DSSugar.h"


@implementation NSManagedObjectContext (DSSugar)

// MARK: - context helpers

+ (NSManagedObjectContext *)viewContext {
    return [[DSDataController sharedInstance] viewContext];
}

+ (NSManagedObjectContext *)peerContext {
    return [[DSDataController sharedInstance] peerContext];
}

+ (NSManagedObjectContext *)chainContext {
    return [[DSDataController sharedInstance] chainContext];
}

+ (NSManagedObjectContext *)platformContext {
    return [[DSDataController sharedInstance] platformContext];
}

+ (NSManagedObjectContext *)masternodesContext {
    return [[DSDataController sharedInstance] masternodesContext];
}


- (instancetype)createChildContext {
    NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [childContext setParentContext:self];
    return childContext;
}

- (void)ds_saveInBlock {
    [self performBlock:^{
        [self ds_save];
    }];
}

- (NSError *)ds_saveInBlockAndWait {
    __block NSError *error = nil;
    [self performBlockAndWait:^{
        error = [self ds_save];
    }];
    return error;
}

- (NSError *)ds_save {
    if (!self.hasChanges) return nil;

    NSTimeInterval saveStart = [NSDate timeIntervalSince1970];
    NSUInteger insertedCount = self.insertedObjects.count;
    NSUInteger updatedCount = self.updatedObjects.count;
    NSUInteger deletedCount = self.deletedObjects.count;

#if TARGET_OS_IOS
    NSUInteger taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
    }];
#endif
    NSError *error = nil;
    if (![self save:&error]) { // persist changes
#if DEBUG
        abort();
#endif
    }
#if TARGET_OS_IOS
    [[UIApplication sharedApplication] endBackgroundTask:taskId];
#endif

    NSTimeInterval saveTime = ([NSDate timeIntervalSince1970] - saveStart) * 1000.0;
    DSLogInfo(@"CoreData", @"Save completed in %.1f ms (inserted: %lu, updated: %lu, deleted: %lu)",
              saveTime, (unsigned long)insertedCount, (unsigned long)updatedCount, (unsigned long)deletedCount);

    return error;
}

@end
