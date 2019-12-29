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
@class DSWallet,DSBlockchainIdentityRegistrationTransition,DSBlockchainIdentityTopupTransition,DSBlockchainIdentityResetTransition,DSBlockchainIdentityCloseTransition,DSAccount,DSChain,DSTransition,DSContactEntity,DSPotentialFriendship,DSTransaction,DSFriendRequestEntity,DSPotentialContact;

typedef NS_ENUM(NSUInteger, DSBlockchainIdentitySigningType) {
    DSBlockchainIdentitySigningType_ECDSA = 0,
    DSBlockchainIdentitySigningType_BLS = 1,
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityUsernameStatus) {
    DSBlockchainIdentityUsernameStatus_NotPresent = 0,
    DSBlockchainIdentityUsernameStatus_Initial = 1,
    DSBlockchainIdentityUsernameStatus_RegistrationPending = 2, //sent to DAPI, not yet confirmed
    DSBlockchainIdentityUsernameStatus_Confirmed = 3,
};

@interface DSBlockchainIdentity : NSObject

@property (nonatomic,weak,readonly) DSWallet * wallet;
@property (nonatomic,readonly) NSString * uniqueIdentifier;
@property (nonatomic,readonly) UInt256 registrationTransitionHash;
@property (nonatomic,readonly) NSData * registrationTransitionHashData;
@property (nonatomic,readonly) NSString * registrationTransitionHashIdentifier;
@property (nonatomic,readonly) UInt256 lastTransitionHash;
@property (nonatomic,readonly) uint32_t index;
@property (nonatomic,readonly) NSArray <NSString *> * usernames;
@property (nonatomic,readonly) NSString * dashpayBioString;
@property (nonatomic,readonly) uint64_t creditBalance;
@property (nonatomic,readonly) uint64_t syncHeight;

@property (nonatomic,readonly) DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition;

@property (nonatomic,readonly) DSContactEntity* ownContact;

-(instancetype)initAtIndex:(uint32_t)index inWallet:(DSWallet* _Nonnull)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initAtIndex:(uint32_t)index inWallet:(DSWallet* _Nonnull)wallet createdWithTransitionHash:(UInt256)registrationTransitionHash inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithBlockchainIdentityRegistrationTransition:(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransaction inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(void)addUsername:(NSString*)username;

-(DSBlockchainIdentityUsernameStatus)statusOfUsername:(NSString*)username;

-(void)generateBlockchainIdentityExtendedPublicKey:(void (^ _Nullable)(BOOL registered))completion;

-(void)registerInWallet;

-(void)registerInWalletForBlockchainIdentityRegistrationTransaction:(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransaction;

-(void)fundingTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSTransaction * fundingTransaction))completion;

-(void)registrationTransitionForFundingTransaction:(DSTransaction*)fundingTransaction completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition))completion;

-(void)topupTransitionForForFundingTransaction:(DSTransaction*)fundingTransaction completion:(void (^ _Nullable)(DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransition))completion;

-(void)resetTransactionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainIdentityResetTransition * blockchainIdentityResetTransaction))completion;

-(void)updateWithTopupTransition:(DSBlockchainIdentityTopupTransition*)blockchainIdentityTopupTransaction save:(BOOL)save;
-(void)updateWithResetTransaction:(DSBlockchainIdentityResetTransition*)blockchainIdentityResetTransaction save:(BOOL)save;
-(void)updateWithCloseTransaction:(DSBlockchainIdentityCloseTransition*)blockchainIdentityCloseTransaction save:(BOOL)save;
-(void)updateWithTransition:(DSTransition*)transition save:(BOOL)save;

-(DSTransition*)transitionForStateTransitionPacketHash:(UInt256)stateTransitionHash;

-(void)signStateTransition:(DSTransition*)transition withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion;

-(BOOL)verifySignature:(NSData*)signature ofType:(DSBlockchainIdentitySigningType)blockchainIdentitySigningType forMessageDigest:(UInt256)messageDigest;

-(void)encryptData:(NSData*)data forRecipientKey:(UInt384)recipientKey withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(NSData* encryptedData))completion;

-(void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL))completion;

-(void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialFriendship*)potentialFriendship completion:(void (^)(BOOL))completion;

-(void)acceptFriendRequest:(DSFriendRequestEntity*)friendRequest completion:(void (^)(BOOL))completion;

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success))completion;

- (void)fetchIncomingContactRequests:(void (^)(BOOL success))completion;

- (void)fetchProfile:(void (^)(BOOL success))completion;

- (void)createOrUpdateProfileWithAboutMeString:(NSString*)aboutme avatarURLString:(NSString *)avatarURLString completion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
