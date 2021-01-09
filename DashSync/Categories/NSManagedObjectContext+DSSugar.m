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
    NSUInteger taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
    }];
    NSError *error = nil;
    if (![self save:&error]) { // persist changes
        DSLog(@"%s: %@", __func__, error);
#if DEBUG
        abort();
#endif
    }
    [[UIApplication sharedApplication] endBackgroundTask:taskId];
    return error;
}

@end
