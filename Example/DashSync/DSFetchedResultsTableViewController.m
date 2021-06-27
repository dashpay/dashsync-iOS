//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSFetchedResultsTableViewController.h"
#import <DashSync/NSManagedObject+Sugar.h>
#import <DashSync/NSPredicate+DSUtils.h>

NS_ASSUME_NONNULL_BEGIN

static NSUInteger FETCH_BATCH_SIZE = 20;

@implementation DSFetchedResultsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self dynamicUpdate]) {
        //todo fix this with new core data stack
        //        [[NSNotificationCenter defaultCenter] addObserver:self
        //                                                 selector:@selector(backgroundManagedObjectContextDidSaveNotification:)
        //                                                     name:NSManagedObjectContextDidSaveNotification object:self.context];
    }
    [self fetchedResultsController];
    [self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.fetchedResultsController = nil;
    if ([self dynamicUpdate]) {
        //        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:[NSManagedObjectContext context]];
    }
}

- (void)backgroundManagedObjectContextDidSaveNotification:(NSNotification *)notification {
    BOOL (^objectsHaveChanged)(NSSet *) = ^BOOL(NSSet *objects) {
        NSSet *foundObjects = [objects filteredSetUsingPredicate:[self fullPredicateInContext]];
        if (foundObjects.count) return TRUE;
        return FALSE;
    };

    BOOL (^objectsHaveChangedInverted)(NSSet *) = ^BOOL(NSSet *objects) {
        if (![self requiredInvertedPredicate]) return FALSE;
        NSSet *foundObjects = [objects filteredSetUsingPredicate:[self fullInvertedPredicateInContext]];
        if (foundObjects.count) return TRUE;
        return FALSE;
    };


    NSSet<NSManagedObject *> *insertedObjects = notification.userInfo[NSInsertedObjectsKey];
    NSSet<NSManagedObject *> *updatedObjects = notification.userInfo[NSUpdatedObjectsKey];
    NSSet<NSManagedObject *> *deletedObjects = notification.userInfo[NSDeletedObjectsKey];
    BOOL inserted = FALSE;
    BOOL updated = FALSE;
    BOOL deleted = FALSE;
    BOOL insertedInverted = FALSE;
    BOOL deletedInverted = FALSE;
    if ((inserted = objectsHaveChanged(insertedObjects)) ||
        (updated = objectsHaveChanged(updatedObjects)) ||
        (deleted = objectsHaveChanged(deletedObjects)) ||
        (insertedInverted = objectsHaveChangedInverted(insertedObjects)) ||
        (deletedInverted = objectsHaveChangedInverted(deletedObjects))) {
        if (inserted || updated || deleted) {
            insertedInverted = objectsHaveChangedInverted(insertedObjects);
            deletedInverted = objectsHaveChangedInverted(deletedObjects);
        }
        [self.context mergeChangesFromContextDidSaveNotification:notification];
        if (insertedInverted || deletedInverted) {
            self.fetchedResultsController = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}


- (NSManagedObjectContext *)context {
    return [NSManagedObjectContext viewContext];
}

- (NSString *)entityName {
    NSAssert(NO, @"Method should be overriden");
    return @"";
}

- (BOOL)dynamicUpdate {
    return TRUE;
}

- (BOOL)requiredInvertedPredicate {
    return FALSE;
}

- (NSPredicate *)classPredicate {
    return [NSPredicate predicateWithFormat:@"self isKindOfClass: %@", NSClassFromString([self entityName])];
}

- (NSPredicate *)predicateInContext {
    return [[self predicate] predicateInContext:self.context];
}

- (NSPredicate *)invertedPredicateInContext {
    return [[self invertedPredicate] predicateInContext:self.context];
}

- (NSPredicate *)fullPredicateInContext {
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[[self classPredicate], [self predicateInContext]]];
}

- (NSPredicate *)fullInvertedPredicateInContext {
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[[self classPredicate], [self invertedPredicateInContext]]];
}

- (NSPredicate *)predicate {
    NSAssert(NO, @"Method should be overriden");
    return [NSPredicate predicateWithValue:YES];
}

- (NSPredicate *)invertedPredicate {
    NSAssert(NO, @"Method should be overriden");
    return [NSPredicate predicateWithValue:YES];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors {
    return @[];
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }

    NSManagedObjectContext *context = self.context;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:self.entityName
                                              inManagedObjectContext:context];
    [fetchRequest setEntity:entity];

    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:FETCH_BATCH_SIZE];

    // Edit the sort key as appropriate.
    NSArray *sortDescriptors = self.sortDescriptors;
    [fetchRequest setSortDescriptors:sortDescriptors];

    NSPredicate *filterPredicate = self.predicate;
    [fetchRequest setPredicate:filterPredicate];

    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController =
        [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                            managedObjectContext:context
                                              sectionNameKeyPath:nil
                                                       cacheName:nil];
    _fetchedResultsController = aFetchedResultsController;
    aFetchedResultsController.delegate = self;
    NSError *error = nil;
    if (![aFetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }

    return _fetchedResultsController;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    NSAssert(NO, @"Method should be overriden");
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.fetchedResultsController.sections[section].numberOfObjects;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(nullable NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(nullable NSIndexPath *)newIndexPath {
    UITableView *tableView = self.tableView;

    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
        case NSFetchedResultsChangeDelete: {
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
        case NSFetchedResultsChangeMove: {
            [tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
            break;
        }
        case NSFetchedResultsChangeUpdate: {
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:indexPath];
            break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

@end

NS_ASSUME_NONNULL_END
