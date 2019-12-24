//
//  DSBlockchainIdentity.h
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import <Foundation/Foundation.h>
#import "DSDAPIClient.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN
@class DSWallet,DSBlockchainIdentityRegistrationTransition,DSBlockchainIdentityTopupTransition,DSBlockchainIdentityResetTransaction,DSBlockchainIdentityCloseTransaction,DSAccount,DSChain,DSTransition,DSContactEntity,DSPotentialFriendship,DSTransaction,DSFriendRequestEntity,DSPotentialContact;

@interface DSBlockchainIdentity : NSObject

@property (nonatomic,weak,readonly) DSWallet * wallet;
@property (nonatomic,readonly) NSString * uniqueIdentifier;
@property (nonatomic,readonly) UInt256 registrationTransactionHash;
@property (nonatomic,readonly) NSData * registrationTransactionHashData;
@property (nonatomic,readonly) NSString * registrationTransactionHashIdentifier;
@property (nonatomic,readonly) UInt256 lastTransitionHash;
@property (nonatomic,readonly) uint32_t index;
@property (nonatomic,readonly) NSString * username;
@property (nonatomic,readonly) NSString * dashpayBioString;
@property (nonatomic,readonly) uint64_t creditBalance;
@property (nonatomic,readonly) uint64_t syncHeight;
@property (nonatomic,readonly) NSArray<DSTransaction*>*allTransitions;

@property (nonatomic,readonly) DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction;

@property (nonatomic,readonly) DSContactEntity* ownContact;

-(instancetype)initWithUsername:(NSString* _Nonnull)username atIndex:(uint32_t)index inWallet:(DSWallet* _Nonnull)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithUsername:(NSString* _Nonnull)username atIndex:(uint32_t)index inWallet:(DSWallet* _Nonnull)wallet createdWithTransactionHash:(UInt256)registrationTransactionHash lastTransitionHash:(UInt256)lastTransitionHash inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithBlockchainIdentityRegistrationTransaction:(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransaction inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(void)generateBlockchainIdentityExtendedPublicKey:(void (^ _Nullable)(BOOL registered))completion;

-(void)registerInWallet;

-(void)registerInWalletForBlockchainIdentityRegistrationTransaction:(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransaction;

-(void)registrationTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction))completion;

-(void)topupTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction))completion;

-(void)resetTransactionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainIdentityResetTransaction * blockchainIdentityResetTransaction))completion;

-(void)updateWithTopupTransaction:(DSBlockchainIdentityTopupTransition*)blockchainIdentityTopupTransaction save:(BOOL)save;
-(void)updateWithResetTransaction:(DSBlockchainIdentityResetTransaction*)blockchainIdentityResetTransaction save:(BOOL)save;
-(void)updateWithCloseTransaction:(DSBlockchainIdentityCloseTransaction*)blockchainIdentityCloseTransaction save:(BOOL)save;
-(void)updateWithTransition:(DSTransition*)transition save:(BOOL)save;

-(DSTransition*)transitionForStateTransitionPacketHash:(UInt256)stateTransitionHash;

-(void)signStateTransition:(DSTransition*)transition withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion;

-(void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL))completion;

-(void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialFriendship*)potentialFriendship completion:(void (^)(BOOL))completion;

-(void)acceptFriendRequest:(DSFriendRequestEntity*)friendRequest completion:(void (^)(BOOL))completion;

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success))completion;

- (void)fetchIncomingContactRequests:(void (^)(BOOL success))completion;

- (void)fetchProfile:(void (^)(BOOL success))completion;

- (void)createOrUpdateProfileWithAboutMeString:(NSString*)aboutme avatarURLString:(NSString *)avatarURLString completion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
