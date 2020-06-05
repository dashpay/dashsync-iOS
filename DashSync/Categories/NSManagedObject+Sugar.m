//
//  NSManagedObject+Sugar.m
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 08/22/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//  Updated by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "NSManagedObject+Sugar.h"
#import <objc/runtime.h>
#import "DSTransaction.h"
#import "DSDataController.h"

static NSUInteger _fetchBatchSize = 100;

@implementation NSManagedObject (Sugar)

// MARK: - create objects

+ (instancetype)managedObject
{
    return [self managedObjectInContext:[NSManagedObjectContext viewContext]];
}

+ (instancetype)managedObjectInContext:(NSManagedObjectContext *)context
{
    __block NSEntityDescription *entity = nil;
    __block NSManagedObject *obj = nil;
    
    [context performBlockAndWait:^{
        entity = [NSEntityDescription entityForName:self.entityName inManagedObjectContext:context];
        obj = [[self alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
    }];
    
    return obj;
}


+ (instancetype)managedObjectInNewChildContextForParentContext:(NSManagedObjectContext *)context
{
    NSManagedObjectContext * childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [childContext setParentContext:context];
    __block NSEntityDescription *entity = nil;
    __block NSManagedObject *obj = nil;
    
    [childContext performBlockAndWait:^{
        entity = [NSEntityDescription entityForName:self.entityName inManagedObjectContext:context];
        obj = [[self alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
    }];
    
    return obj;
}

+ (NSArray *)managedObjectArrayWithLength:(NSUInteger)length inContext:(NSManagedObjectContext*)context
{
    __block NSEntityDescription *entity = nil;
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:length];
    
    [context performBlockAndWait:^{
        entity = [NSEntityDescription entityForName:self.entityName inManagedObjectContext:context];
        
        for (NSUInteger i = 0; i < length; i++) {
            [a addObject:[[self alloc] initWithEntity:entity insertIntoManagedObjectContext:context]];
        }
    }];
    
    return a;
}

// MARK: - fetch existing objects

+ (NSArray *)allObjects
{
    return [self fetchObjects:self.fetchReq inContext:[NSManagedObjectContext viewContext]];
}

+ (NSArray *)allObjectsInContext:(NSManagedObjectContext*)context
{
    return [self fetchObjects:self.fetchReq inContext:context];
}

+ (NSArray *)allObjectsWithPrefetch:(NSArray<NSString*> *)prefetchArray inContext:(NSManagedObjectContext*)context
{
    NSFetchRequest * fetchRequest = self.fetchReq;
    [fetchRequest setRelationshipKeyPathsForPrefetching:prefetchArray];
    return [self fetchObjects:fetchRequest inContext:context];
}

+ (NSArray *)objectsMatching:(NSString *)predicateFormat, ... {
    NSArray *a;
    va_list args;

    va_start(args, predicateFormat);
    a = [self objectsMatching:predicateFormat arguments:args inContext:[NSManagedObjectContext viewContext]];
    va_end(args);
    return a;
}

+ (NSArray *)objectsInContext:(NSManagedObjectContext *)context matching:(NSString *)predicateFormat, ...;
{
    NSArray *a;
    va_list args;

    va_start(args, predicateFormat);
    a = [self objectsMatching:predicateFormat arguments:args inContext:context];
    va_end(args);
    return a;
}

+ (instancetype)anyObjectMatching:(NSString *)predicateFormat, ...
{
    NSArray *a;
    va_list args;
    
    va_start(args, predicateFormat);
    a = [self objectsMatching:predicateFormat arguments:args];
    va_end(args);
    if ([a count]) {
        return [a objectAtIndex:0];
    } else return nil;
}

+ (instancetype)anyObjectInContext:(NSManagedObjectContext*)context matching:(NSString *)predicateFormat, ...
{
    NSArray *a;
    va_list args;
    
    va_start(args, predicateFormat);
    a = [self objectsMatching:predicateFormat arguments:args inContext:context];
    va_end(args);
    if ([a count]) {
        return [a objectAtIndex:0];
    } else return nil;
}

+ (instancetype)anyObjectMatchingInContext:(NSManagedObjectContext *)context withPredicate:(NSString *)predicateFormat, ...
{
    NSArray *a;
    va_list args;
    
    va_start(args, predicateFormat);
    a = [self objectsMatching:predicateFormat arguments:args inContext:context];
    va_end(args);
    if ([a count]) {
        return [a objectAtIndex:0];
    } else return nil;
}

+ (NSArray *)objectsMatching:(NSString *)predicateFormat arguments:(va_list)args 
{
    return [self objectsMatching:predicateFormat arguments:args inContext:[NSManagedObjectContext viewContext]];
}

+ (NSArray *)objectsMatching:(NSString *)predicateFormat arguments:(va_list)args inContext:(NSManagedObjectContext*)context
{
    return [self objectsForPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args] inContext:context];
}

+ (NSArray *)objectsForPredicate:(NSPredicate*)predicate inContext:(NSManagedObjectContext*)context
{
    NSFetchRequest *request = self.fetchReq;
    
    request.predicate = predicate;
    return [self fetchObjects:request inContext:context];
}

+ (instancetype)anyObjectMatching:(NSString *)predicateFormat arguments:(va_list)args
{
    return [self anyObjectMatching:predicateFormat arguments:args inContext:[NSManagedObjectContext viewContext]];
}

+ (instancetype)anyObjectMatching:(NSString *)predicateFormat arguments:(va_list)args inContext:(NSManagedObjectContext*)context
{
    NSArray * array = [self objectsMatching:predicateFormat arguments:args inContext:context];
    if ([array count]) {
        return [array objectAtIndex:0];
    } else return nil;
}

+ (instancetype)anyObjectForPredicate:(NSPredicate*)predicate inContext:(NSManagedObjectContext*)context
{
    NSFetchRequest *request = self.fetchReq;
    
    request.predicate = predicate;
    request.fetchLimit = 1;
    return [[self fetchObjects:request inContext:context] firstObject];
}

+ (NSArray *)objectsSortedBy:(NSString *)key ascending:(BOOL)ascending inContext:(NSManagedObjectContext*)context;
{
    return [self objectsSortedBy:key ascending:ascending offset:0 limit:0 inContext:context];
}

+ (NSArray *)objectsSortedBy:(NSString *)key ascending:(BOOL)ascending offset:(NSUInteger)offset limit:(NSUInteger)limit inContext:(NSManagedObjectContext*)context;
{
    NSFetchRequest *request = self.fetchReq;
    
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:key ascending:ascending]];
    request.fetchOffset = offset;
    request.fetchLimit = limit;
    return [self fetchObjects:request inContext:context];
}

+ (NSArray *)fetchObjects:(NSFetchRequest *)request
{
    return [self fetchObjects:request inContext:[NSManagedObjectContext viewContext]];
}

+ (NSArray *)fetchObjects:(NSFetchRequest *)request inContext:(NSManagedObjectContext*)context
{
    __block NSArray *a = nil;
    __block NSError *error = nil;
    
    [context performBlockAndWait:^{
        a = [context executeFetchRequest:request error:&error];
        if (error) DSDLog(@"%s: %@", __func__, error);
    }];
    
    return a;
}

// MARK: - count exising objects

+ (NSUInteger)countAllObjectsInContext:(NSManagedObjectContext *)context
{
    return [self countObjects:self.fetchReq inContext:context];
}


+ (NSUInteger)countAllObjects
{
    return [self countObjects:self.fetchReq];
}

+ (NSUInteger)countObjectsInContext:(NSManagedObjectContext*)context matching:(NSString *)predicateFormat, ...
{
    NSUInteger count;
    va_list args;
    
    va_start(args, predicateFormat);
    count = [self countObjectsMatching:predicateFormat arguments:args inContext:context];
    va_end(args);
    return count;
}

+ (NSUInteger)countObjectsMatching:(NSString *)predicateFormat, ...
{
    NSUInteger count;
    va_list args;
    
    va_start(args, predicateFormat);
    count = [self countObjectsMatching:predicateFormat arguments:args];
    va_end(args);
    return count;
}

+ (NSUInteger)countObjectsMatchingInContext:(NSManagedObjectContext *)context withPredicate:(NSString *)predicateFormat, ...
{
    NSUInteger count;
    va_list args;
    
    va_start(args, predicateFormat);
    count = [self countObjectsMatching:predicateFormat arguments:args inContext:context];
    va_end(args);
    return count;
}

+ (NSUInteger)countObjectsMatching:(NSString *)predicateFormat arguments:(va_list)args
{
    return [self countObjectsMatching:predicateFormat arguments:args inContext:[NSManagedObjectContext viewContext]];
}

+ (NSUInteger)countObjectsMatching:(NSString *)predicateFormat arguments:(va_list)args inContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = self.fetchReq;
    
    request.predicate = [NSPredicate predicateWithFormat:predicateFormat arguments:args];
    return [self countObjects:request inContext:context];
}

+ (NSUInteger)countObjects:(NSFetchRequest *)request
{
    return [self countObjects:request inContext:[NSManagedObjectContext viewContext]];
}

+ (NSUInteger)countObjects:(NSFetchRequest *)request inContext:(NSManagedObjectContext *)context
{
    __block NSUInteger count = 0;
    __block NSError *error = nil;
    
    [context performBlockAndWait:^{
        count = [context countForFetchRequest:request error:&error];
        if (error) DSDLog(@"%s: %@", __func__, error);
    }];
    
    return count;
}

// MARK: - delete objects

+ (NSUInteger)deleteObjects:(NSArray *)objects inContext:(NSManagedObjectContext*)context {
    [context performBlock:^{
        for (NSManagedObject *obj in objects) {
            [context deleteObject:obj];
        }
    }];
    
    return objects.count;
}

+ (NSUInteger)deleteObjectsAndWait:(NSArray *)objects inContext:(NSManagedObjectContext*)context {
    [context performBlockAndWait:^{
        for (NSManagedObject *obj in objects) {
            [context deleteObject:obj];
        }
    }];
    
    return objects.count;
}

+ (NSUInteger)deleteAllObjectsInContext:(NSManagedObjectContext *)context {
    return [self deleteObjects:[self allObjects] inContext:context];
}

+ (NSUInteger)deleteAllObjectsAndWaitInContext:(NSManagedObjectContext *)context {
    return [self deleteObjectsAndWait:[self allObjects] inContext:context];
}

// MARK: - core data stack

// set the fetchBatchSize to use when fetching objects, default is 100
+ (void)setFetchBatchSize:(NSUInteger)fetchBatchSize
{
    _fetchBatchSize = fetchBatchSize;
}

+(NSURL*)storeURL {
    static NSURL * storeURL = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSURL *docURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
        NSString *fileName = @"DashSync.sqlite";
        storeURL = [docURL URLByAppendingPathComponent:fileName];
    });
    return storeURL;
}

//+(void)createContexts {
//    static dispatch_once_t onceToken = 0;
//    
//    dispatch_once(&onceToken, ^{
//        DSDataController * dataController = [DSDataController sharedInstance];
//            [NSManagedObject setContext:dataController.chainContext];
//            
//            NSManagedObjectContext *mainObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
//            mainObjectContext.parentContext = objectContext;
//            
//            objc_setAssociatedObject([NSManagedObject class], &_storeURLKey, storeURL,
//                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//            [NSManagedObject setMainContext:mainObjectContext];
//            
//
////            [[NSNotificationCenter defaultCenter]
////             addObserverForName:NSManagedObjectContextDidSaveNotification
////             object:objectContext
////             queue:nil
////             usingBlock:^(NSNotification * _Nonnull note) {
////                 [mainObjectContext performBlock:^{
////                     [mainObjectContext mergeChangesFromContextDidSaveNotification:note];
////                 }];
////            }];
//            
//            // this will save changes to the persistent store before the application terminates
//            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification object:nil
//                                                               queue:nil usingBlock:^(NSNotification *note) {
//                                                                   [self saveContext];
//                                                               }];
//        }
//    });
//}

//// returns the managed object context for the application, or if the context doesn't already exist, creates it and binds
//// it to the persistent store coordinator for the application
//+ (NSManagedObjectContext *)context
//{
//    [self createContexts];
//
//    NSManagedObjectContext *context = objc_getAssociatedObject(self, &_contextKey);
//
//    if (! context && self != [NSManagedObject class]) {
//        context = [NSManagedObject context];
//        [self setContext:context];
//    }
//
//    return (context == (id)[NSNull null]) ? nil : context;
//}

//+ (NSManagedObjectContext *)mainContext
//{
//    [self createContexts];
//
//    NSManagedObjectContext *context = objc_getAssociatedObject(self, &_mainContextKey);
//
//    if (! context && self != [NSManagedObject class]) {
//        context = [NSManagedObject mainContext];
//        [self setMainContext:context];
//    }
//
//    return (context == (id)[NSNull null]) ? nil : context;
//}
//
//// sets a different context for NSManagedObject+Sugar methods to use for this type of entity
//+ (void)setContext:(NSManagedObjectContext *)context
//{
//    objc_setAssociatedObject(self, &_contextKey, (context ? context : [NSNull null]),
//                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//}
//
//// sets a different main context for NSManagedObject+Sugar methods to use for this type of entity
//+ (void)setMainContext:(NSManagedObjectContext *)context
//{
//    objc_setAssociatedObject(self, &_mainContextKey, (context ? context : [NSNull null]),
//                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//}
//
//// persists changes (this is called automatically for the main context when the app terminates)
//+ (NSError*)saveContext
//{
//    if (! self.context.hasChanges) return nil;
//    __block NSError * error = nil;
//    [self.context performBlockAndWait:^{
//        if (self.context.hasChanges) {
//            @autoreleasepool {
//                NSUInteger taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
//
//                // this seems to fix unreleased temporary object IDs
//                [self.context obtainPermanentIDsForObjects:self.context.registeredObjects.allObjects error:nil];
//
//                if (! [self.context save:&error]) { // persist changes
//                    DSDLog(@"%s: %@", __func__, error);
//#if DEBUG
//                    abort();
//#endif
//                }
//
//                [[UIApplication sharedApplication] endBackgroundTask:taskId];
//            }
//        }
//    }];
//
//    return error;
//}

//// persists changes (this is called automatically for the main context when the app terminates)
//+ (NSError*)saveMainContext
//{
//    if (! self.mainContext.hasChanges) return nil;
//    __block NSError * error = nil;
//    [self.mainContext performBlockAndWait:^{
//        if (self.mainContext.hasChanges) {
//            @autoreleasepool {
//                NSUInteger taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
//                
//                // this seems to fix unreleased temporary object IDs
//                [self.mainContext obtainPermanentIDsForObjects:self.mainContext.registeredObjects.allObjects error:nil];
//                
//                if (! [self.mainContext save:&error]) { // persist changes
//                    DSDLog(@"%s: %@", __func__, error);
//#if DEBUG
//                    abort();
//#endif
//                }
//                
//                [self saveContext];
//                
//                [[UIApplication sharedApplication] endBackgroundTask:taskId];
//            }
//        }
//    }];
//    
//    return error;
//}

// MARK: - entity methods

// override this if entity name differs from class name
+ (NSString *)entityName
{
    return NSStringFromClass([self class]);
}

+ (NSFetchRequest *)fetchReq
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:self.entityName];

    request.fetchBatchSize = _fetchBatchSize;
    request.returnsObjectsAsFaults = NO;
    return request;
}

// id value = entity[@"key"]; thread safe valueForKey:
- (id)objectForKeyedSubscript:(id<NSCopying>)key
{
    __block id obj = nil;

    [self.managedObjectContext performBlockAndWait:^{
        obj = [self valueForKey:(NSString *)key];
    }];

    return obj;
}

// entity[@"key"] = value; thread safe setValue:forKey:
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key
{
    [self.managedObjectContext performBlockAndWait:^{
        [self setValue:obj forKey:(NSString *)key];
    }];
}

- (void)deleteObject
{
    [self.managedObjectContext performBlock:^{
        [self.managedObjectContext deleteObject:self];
    }];
}

- (void)deleteObjectAndWait
{
    [self.managedObjectContext performBlockAndWait:^{
        [self.managedObjectContext deleteObject:self];
    }];
}

@end
