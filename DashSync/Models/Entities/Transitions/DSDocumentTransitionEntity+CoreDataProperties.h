//
//  DSDocumentTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSDocumentTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSDocumentTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSDocumentTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSObject *documents;
@property (nullable, nonatomic, retain) NSSet<DSContactEntity *> *contactProfileCreations;
@property (nullable, nonatomic, retain) NSSet<DSFriendRequestEntity *> *contactRequests;

@end

@interface DSDocumentTransitionEntity (CoreDataGeneratedAccessors)

- (void)addContactProfileCreationsObject:(DSContactEntity *)value;
- (void)removeContactProfileCreationsObject:(DSContactEntity *)value;
- (void)addContactProfileCreations:(NSSet<DSContactEntity *> *)values;
- (void)removeContactProfileCreations:(NSSet<DSContactEntity *> *)values;

- (void)addContactRequestsObject:(DSFriendRequestEntity *)value;
- (void)removeContactRequestsObject:(DSFriendRequestEntity *)value;
- (void)addContactRequests:(NSSet<DSFriendRequestEntity *> *)values;
- (void)removeContactRequests:(NSSet<DSFriendRequestEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
