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

#import "DSCoreDataMigrator.h"

#import "NSPersistentStoreCoordinator+DS.h"
#import "NSManagedObjectModel+DS.h"
#import "DSCoreDataMigrationStep.h"
#import "DSDataController.h"
#import "DSCoreDataMigrationVersion.h"

@implementation DSCoreDataMigrationVersion (DSMigrator)

+ (DSCoreDataMigrationVersionValue)compatibleVersionForStoreMetadata:(NSDictionary <NSString *, id> *)metadata {
    for (NSUInteger version = DSCoreDataMigrationVersionValue_1; version <= self.current; version++) {
        NSString *resource = [self modelResourceForVersion:version];
        NSManagedObjectModel *model = [NSManagedObjectModel ds_managedObjectModelForResource:resource];
        if ([model isConfiguration:nil compatibleWithStoreMetadata:metadata]) {
            return version;
        }
    }
    return NSNotFound;
}

@end

@implementation DSCoreDataMigrator

+(NSURL*)documentsStoreURL {
    static NSURL * storeURL = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSURL *docURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
        NSString *fileName = @"DashSync.sqlite";
        storeURL = [docURL URLByAppendingPathComponent:fileName];
    });
    return storeURL;
}

+(NSURL*)documentsWALURL {
    static NSURL * storeURL = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSURL *docURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
        NSString *fileName = @"DashSync.sqlite-wal";
        storeURL = [docURL URLByAppendingPathComponent:fileName];
    });
    return storeURL;
}

+(NSURL*)documentsSHMURL {
    static NSURL * storeURL = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSURL *docURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
        NSString *fileName = @"DashSync.sqlite-shm";
        storeURL = [docURL URLByAppendingPathComponent:fileName];
    });
    return storeURL;
}

+ (BOOL)requiresMigration {
    NSURL *storeURL = [DSDataController storeURL];
    NSDictionary *metadata = [NSPersistentStoreCoordinator ds_metadataAt:storeURL];
    if (metadata == nil) {
        storeURL = [self documentsStoreURL];
    }
    DSCoreDataMigrationVersionValue version = DSCoreDataMigrationVersion.current;
    return [self requiresMigrationAtStoreURL:storeURL version:version];
}

+ (void)performMigrationWithCompletionQueue:(dispatch_queue_t)completionQueue completion:(void(^)(void))completion {
    NSAssert([NSThread isMainThread], @"Main thread is assumed here");
    
    __block NSURL *storeURL = [DSDataController storeURL];
    NSDictionary *metadata = [NSPersistentStoreCoordinator ds_metadataAt:storeURL];
    __block BOOL shouldRemoveDocumentsCopy = FALSE;
    if (metadata == nil) {
        metadata = [NSPersistentStoreCoordinator ds_metadataAt:[self documentsStoreURL]];
        if (metadata != nil) {
            //Move to Application Support
            [[NSFileManager defaultManager] copyItemAtURL:[self documentsStoreURL] toURL:[DSDataController storeURL] error:nil];
            [[NSFileManager defaultManager] copyItemAtURL:[self documentsWALURL] toURL:[DSDataController storeWALURL] error:nil];
            [[NSFileManager defaultManager] copyItemAtURL:[self documentsSHMURL] toURL:[DSDataController storeSHMURL] error:nil];
            shouldRemoveDocumentsCopy = TRUE;
        }
    }
    __block DSCoreDataMigrationVersionValue version = DSCoreDataMigrationVersion.current;
    if ([self requiresMigrationAtStoreURL:storeURL version:version]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [self migrateStoreAtURL:storeURL toVersion:version];
            if (shouldRemoveDocumentsCopy) {
                [[NSFileManager defaultManager] removeItemAtURL:[self documentsStoreURL] error:nil];
                [[NSFileManager defaultManager] removeItemAtURL:[self documentsWALURL] error:nil];
                [[NSFileManager defaultManager] removeItemAtURL:[self documentsSHMURL] error:nil];
            }
            dispatch_async(completionQueue, ^{
                if (completion) {
                    completion();
                }
            });
        });
    }
    else {
        dispatch_async(completionQueue, ^{
            if (completion) {
                completion();
            }
        });
    }
}

#pragma mark - Private

+ (BOOL)requiresMigrationAtStoreURL:(NSURL *)storeURL version:(DSCoreDataMigrationVersionValue)version {
    NSDictionary *metadata = [NSPersistentStoreCoordinator ds_metadataAt:storeURL];
    if (metadata == nil) {
        return NO;
    }
    
    return ([DSCoreDataMigrationVersion compatibleVersionForStoreMetadata:metadata] != version);
}

+ (void)migrateStoreAtURL:(NSURL *)storeURL toVersion:(DSCoreDataMigrationVersionValue)version {
    [self forceWALCheckpointingForStoreAtURL:storeURL];
    
    NSURL *currentURL = storeURL;
    NSArray <DSCoreDataMigrationStep *> *migrationSteps = [self migrationStepsForStoreAtURL:storeURL toVersion:version];
    
    for (DSCoreDataMigrationStep *step in migrationSteps) {
        NSMigrationManager *manager = [[NSMigrationManager alloc] initWithSourceModel:step.sourceModel
                                                                     destinationModel:step.destinationModel];
        NSURL *destinationURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
                                  URLByAppendingPathComponent:[NSUUID UUID].UUIDString] URLByAppendingPathExtension:@"sqlite"];
        NSError *error = nil;
        [manager migrateStoreFromURL:currentURL
                                type:NSSQLiteStoreType
                             options:nil
                    withMappingModel:step.mappingModel
                    toDestinationURL:destinationURL
                     destinationType:NSSQLiteStoreType
                  destinationOptions:nil error:&error];
        NSAssert(error == nil, @"failed attempting to migrate from %@ to %@, error %@",
                 step.sourceModel, step.destinationModel, error);
        
        if ([currentURL isEqual:storeURL] == NO) {
            [NSPersistentStoreCoordinator ds_destroyStoreAtURL:currentURL];
        }
        
        currentURL = destinationURL;
    }
    
    [NSPersistentStoreCoordinator ds_replaceStoreAt:storeURL with:currentURL];
    
    if ([currentURL isEqual:storeURL] == NO) {
        [NSPersistentStoreCoordinator ds_destroyStoreAtURL:currentURL];
    }
}

+ (NSArray <DSCoreDataMigrationStep *> *)migrationStepsForStoreAtURL:(NSURL *)storeURL
                                                           toVersion:(DSCoreDataMigrationVersionValue)destinationVersion {
    NSDictionary <NSString *, id> *metadata = [NSPersistentStoreCoordinator ds_metadataAt:storeURL];
    if (metadata == nil) {
        NSAssert(NO, @"unknown store version at URL %@", storeURL);
        return @[];
    }
    DSCoreDataMigrationVersionValue sourceVersion = [DSCoreDataMigrationVersion compatibleVersionForStoreMetadata:metadata];
    if (sourceVersion == NSNotFound) {
        DSDLog(@"unknown source version at URL %@", storeURL);
        return @[];
    }
    
    return [self migrationStepsFromSourceVersion:sourceVersion destinationVersion:destinationVersion];
}

+ (NSArray <DSCoreDataMigrationStep *> *)migrationStepsFromSourceVersion:(DSCoreDataMigrationVersionValue)sourceVersion
    destinationVersion:(DSCoreDataMigrationVersionValue)destinationVersion {
    NSMutableArray <DSCoreDataMigrationStep *> *steps = [NSMutableArray array];
    
    while (sourceVersion != destinationVersion && [DSCoreDataMigrationVersion nextVersionAfter:sourceVersion] != NSNotFound) {
        DSCoreDataMigrationVersionValue nextVersion = [DSCoreDataMigrationVersion nextVersionAfter:sourceVersion];
        DSCoreDataMigrationStep *step = [[DSCoreDataMigrationStep alloc] initWithSourceVersion:sourceVersion destinationVersion:nextVersion];
        [steps addObject:step];
        
        sourceVersion = nextVersion;
    }
    
    return steps;
}

+ (void)forceWALCheckpointingForStoreAtURL:(NSURL *)storeURL {
    NSDictionary <NSString *, id> *metadata = [NSPersistentStoreCoordinator ds_metadataAt:storeURL];
    if (metadata == nil) {
        return;
    }
    NSManagedObjectModel *currentModel = [NSManagedObjectModel ds_compatibleModelForStoreMetadata:metadata];
    if (currentModel == nil) {
        return;
    }
    
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:currentModel];
    NSDictionary *options = @{ NSSQLitePragmasOption: @{ @"journal_mode": @"DELETE" }, };
    NSPersistentStore *store = [psc ds_addPersistentStoreAt:storeURL options:options];
    NSError *error = nil;
    [psc removePersistentStore:store error:&error];
    NSAssert(error == nil, @"failed to force WAL checkpointing %@", error);
}

@end
