//
//  DSContactEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSDashpayUserEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSDashpayUserEntity (CoreDataProperties)

+ (NSFetchRequest<DSDashpayUserEntity *> *)fetchRequest;

@property (nonatomic, assign) uint32_t profileDocumentRevision;
@property (nonatomic, assign) uint32_t contactRequestDocumentRevision;
@property (nullable, nonatomic, retain) NSData *encryptionPublicKey;
@property (nonatomic, assign) uint32_t encryptionPublicKeyType;
@property (nonatomic, assign) uint32_t encryptionPublicKeyIndex;
@property (nullable, nonatomic, copy) NSString *displayName;
@property (nullable, nonatomic, copy) NSString *avatarPath;
@property (nullable, nonatomic, retain) NSData *associatedBlockchainIdentityUniqueId;
@property (nullable, nonatomic, copy) NSString *publicMessage;
@property (nonatomic, assign) BOOL isRegistered;
@property (nullable, nonatomic, retain) DSBlockchainIdentityEntity *associatedBlockchainIdentity;
@property (nullable, nonatomic, retain) NSSet<DSFriendRequestEntity *> *outgoingRequests;
@property (nullable, nonatomic, retain) NSSet<DSFriendRequestEntity *> *incomingRequests;
@property (nullable, nonatomic, retain) NSSet<DSDashpayUserEntity *> *friends;
@property (nullable, nonatomic, retain) DSChainEntity *chain;

@end

@interface DSDashpayUserEntity (CoreDataGeneratedAccessors)


- (void)addFriendsObject:(DSDashpayUserEntity *)value;
- (void)removeFriendsObject:(DSDashpayUserEntity *)value;
- (void)addFriends:(NSSet<DSDashpayUserEntity *> *)values;
- (void)removeFriends:(NSSet<DSDashpayUserEntity *> *)values;

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
