//
//  NSManagedObject+Sugar.h
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

#import "NSManagedObjectContext+DSSugar.h"
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSManagedObject (Sugar)

// create objects
+ (instancetype)managedObjectInBlockedContext:(NSManagedObjectContext *)context;
+ (instancetype)managedObjectInContext:(NSManagedObjectContext *)context;
+ (NSArray *)managedObjectArrayWithLength:(NSUInteger)length inContext:(NSManagedObjectContext *)context;

// fetch existing objects
+ (NSArray *)allObjectsInContext:(NSManagedObjectContext *)context;
+ (NSArray *)allObjectsWithPrefetch:(NSArray<NSString *> *)prefetchArray inContext:(NSManagedObjectContext *)context;
+ (NSArray *)objectsInContext:(NSManagedObjectContext *)context matching:(NSString *)predicateFormat, ...;
+ (instancetype)anyObjectInContext:(NSManagedObjectContext *)context matching:(NSString *)predicateFormat, ...;

+ (NSArray *)objectsForPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context;
+ (instancetype)anyObjectForPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context;

+ (NSArray *)objectsSortedBy:(NSString *)key ascending:(BOOL)ascending inContext:(NSManagedObjectContext *)context;
+ (NSArray *)objectsSortedBy:(NSString *)key ascending:(BOOL)ascending offset:(NSUInteger)offset limit:(NSUInteger)lim inContext:(NSManagedObjectContext *)context;

+ (NSArray *)fetchObjects:(NSFetchRequest *)request inContext:(NSManagedObjectContext *)context;

// count existing objects
+ (NSUInteger)countAllObjectsInContext:(NSManagedObjectContext *)context;
+ (NSUInteger)countObjectsInContext:(NSManagedObjectContext *)context matching:(NSString *)predicateFormat, ...;
+ (NSUInteger)countObjects:(NSFetchRequest *)request inContext:(NSManagedObjectContext *)context;
+ (NSUInteger)countObjectsMatchingInContext:(NSManagedObjectContext *)context withPredicate:(NSString *)predicateFormat, ...;

// delete objects
+ (NSUInteger)deleteAllObjectsInContext:(NSManagedObjectContext *)context;
+ (NSUInteger)deleteAllObjectsAndWaitInContext:(NSManagedObjectContext *)context;
+ (NSUInteger)deleteObjects:(NSArray *)objects inContext:(NSManagedObjectContext *)context;
+ (NSUInteger)deleteObjectsAndWait:(NSArray *)objects inContext:(NSManagedObjectContext *)context;

// set the fetchBatchSize to use when fetching objects, default is 100
+ (void)setFetchBatchSize:(NSUInteger)fetchBatchSize;

+ (NSString *)entityName; // override this if entity name differs from class name
+ (NSFetchRequest *)fetchReq;

- (id)objectForKeyedSubscript:(id<NSCopying>)key;               // id value = entity[@"key"]; thread safe valueForKey:
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key; // entity[@"key"] = value; thread safe setValue:forKey:
- (void)deleteObject;
- (void)deleteObjectAndWait;

@end

NS_ASSUME_NONNULL_END
