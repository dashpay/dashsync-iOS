//
//  DSContactEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSContactEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSContactEntity (CoreDataProperties)

+ (NSFetchRequest<DSContactEntity *> *)fetchRequest;

@property (nonatomic, assign) uint32_t blockHeight;
@property (nonatomic, assign) uint32_t documentRevision;
@property (nullable, nonatomic, retain) NSData *encryptionPublicKey;
@property (nullable, nonatomic, copy) NSString *documentScopeID;
@property (nullable, nonatomic, copy) NSString *username;
@property (nullable, nonatomic, copy) NSString *avatarPath;
@property (nullable, nonatomic, retain) NSData *associatedBlockchainUserRegistrationHash;
@property (nullable, nonatomic, copy) NSString *publicMessage;
@property (nullable, nonatomic, retain) DSBlockchainUserRegistrationTransactionEntity *associatedBlockchainUserRegistrationTransaction;
@property (nullable, nonatomic, retain) NSSet<DSFriendRequestEntity *> *outgoingRequests;
@property (nullable, nonatomic, retain) NSSet<DSFriendRequestEntity *> *incomingRequests;
@property (nullable, nonatomic, retain) NSSet<DSContactEntity *> *friends;
@property (nullable, nonatomic, retain) DSTransitionEntity *profileTransition;
@property (nullable, nonatomic, retain) DSChainEntity *chain;

@end

@interface DSContactEntity (CoreDataGeneratedAccessors)


- (void)addFriendsObject:(DSContactEntity *)value;
- (void)removeFriendsObject:(DSContactEntity *)value;
- (void)addFriends:(NSSet<DSContactEntity *> *)values;
- (void)removeFriends:(NSSet<DSContactEntity *> *)values;

- (void)addOutgoingRequestsObject:(DSFriendRequestEntity *)value;
- (void)removeOutgoingRequestsObject:(DSFriendRequestEntity *)value;
- (void)addOutgoingRequests:(NSSet<DSFriendRequestEntity *> *)values;
- (void)removeOutgoingRequests:(NSSet<DSFriendRequestEntity *> *)values;

- (void)addIncomingRequestsObject:(DSFriendRequestEntity *)value;
- (void)removeIncomingRequestsObject:(DSFriendRequestEntity *)value;
- (void)addIncomingRequests:(NSSet<DSFriendRequestEntity *> *)values;
- (void)removeIncomingRequests:(NSSet<DSFriendRequestEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
