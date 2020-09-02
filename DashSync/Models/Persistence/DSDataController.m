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
#import "DSTransaction.h"
#import "DSCoreDataMigrator.h"

@interface DSDataController()

@property (nonatomic, strong) NSPersistentContainer * persistentContainer;
@property (nonatomic, strong) NSManagedObjectContext * peerContext;
@property (nonatomic, strong) NSManagedObjectContext * chainContext;
@property (nonatomic, strong) NSManagedObjectContext * platformContext;

@end

@implementation DSDataController

+(NSURL*)storeURL {
    static NSURL * storeURL = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSURL *docURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].lastObject;
        NSString *fileName = @"DashSync.sqlite";
        storeURL = [docURL URLByAppendingPathComponent:fileName];
    });
    return storeURL;
}

+(NSURL*)storeWALURL {
    static NSURL * storeURL = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSURL *docURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].lastObject;
        NSString *fileName = @"DashSync.sqlite-wal";
        storeURL = [docURL URLByAppendingPathComponent:fileName];
    });
    return storeURL;
}

+(NSURL*)storeSHMURL {
    static NSURL * storeURL = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSURL *docURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].lastObject;
        NSString *fileName = @"DashSync.sqlite-shm";
        storeURL = [docURL URLByAppendingPathComponent:fileName];
    });
    return storeURL;
}



- (id)init
{
    self = [super init];
    if (!self) return nil;
    
    if ([DSCoreDataMigrator requiresMigration]) {
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [DSCoreDataMigrator performMigration:^{
            dispatch_semaphore_signal(sem);
        }];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    }
    
    [self loadPersistentContainer];
    
    return self;
}

-(void)loadPersistentContainer {
        NSBundle *frameworkBundle = [NSBundle bundleForClass:[DSTransaction class]];
        NSURL *bundleURL = [[frameworkBundle resourceURL] URLByAppendingPathComponent:@"DashSync.bundle"];
        NSBundle *resourceBundle = [NSBundle bundleWithURL:bundleURL];
        NSURL *modelURL = [resourceBundle URLsForResourcesWithExtension:@"momd" subdirectory:nil].lastObject;
        
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        
        self.persistentContainer = [[NSPersistentContainer alloc] initWithName:@"DashSync" managedObjectModel:model];
        
        [self.persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *description, NSError *error) {
            if (error != nil) {
                DSDLog(@"Failed to load Core Data stack: %@", error);
    #if (DEBUG && 1)
                abort();
    #else
                NSURL * storeURL = [self.class storeURL];
                // if this is a not a debug build, attempt to delete and create a new persisent data store before crashing
                if (! [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error]) {
                    DSDLog(@"%s: %@", __func__, error);
                }
                
                [self.persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *description, NSError *error) {
                    if (error != nil) {
                        DSDLog(@"Failed to load Core Data stack again: %@", error);
                        abort();
                    }
                }];
    #endif
            }
        }];
}

-(NSManagedObjectContext*)viewContext {
    static dispatch_once_t onceViewToken;
    dispatch_once(&onceViewToken, ^{
        [self.persistentContainer.viewContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [self.persistentContainer.viewContext setAutomaticallyMergesChangesFromParent:YES];
    });
    return self.persistentContainer.viewContext;
}

-(NSManagedObjectContext*)peerContext {
    static dispatch_once_t oncePeerToken;
    dispatch_once(&oncePeerToken, ^{
        _peerContext = [self.persistentContainer newBackgroundContext];
        [_peerContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    });
    return _peerContext;
}

-(NSManagedObjectContext*)chainContext {
    static dispatch_once_t onceChainToken;
    dispatch_once(&onceChainToken, ^{
        _chainContext = [self.persistentContainer newBackgroundContext];
        [_chainContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    });
    return _chainContext;
}

-(NSManagedObjectContext*)platformContext {
    static dispatch_once_t oncePlatformToken;
    dispatch_once(&oncePlatformToken, ^{
        _platformContext = [self.persistentContainer newBackgroundContext];
        [_platformContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    });
    return _platformContext;
}

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

@end
