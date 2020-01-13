//
//  DSBlockchainIdentity.h
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import <Foundation/Foundation.h>
#import "DSDAPIClient.h"
#import "BigIntTypes.h"
#import "DSDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN
@class DSWallet,DSBlockchainIdentityRegistrationTransition,DSBlockchainIdentityTopupTransition,DSBlockchainIdentityUpdateTransition,DSBlockchainIdentityCloseTransition,DSAccount,DSChain,DSTransition,DSContactEntity,DSPotentialFriendship,DSTransaction,DSFriendRequestEntity,DSPotentialContact,DSCreditFundingTransaction,DSDocumentTransition,DSKey;

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityUsernameStatus) {
    DSBlockchainIdentityUsernameStatus_NotPresent = 0,
    DSBlockchainIdentityUsernameStatus_Initial = 1,
    DSBlockchainIdentityUsernameStatus_RegistrationPending = 2, //sent to DAPI, not yet confirmed
    DSBlockchainIdentityUsernameStatus_Confirmed = 3,
};

@interface DSBlockchainIdentity : NSObject

@property (nonatomic,weak,readonly) DSWallet * wallet;
@property (nonatomic,readonly) NSString * uniqueIdString;
@property (nonatomic,readonly) UInt256 uniqueId;
@property (nonatomic,readonly) UInt256 registrationTransitionHash;
@property (nonatomic,readonly) NSData * uniqueIdData;
@property (nonatomic,readonly) NSData * lockedOutpointData;
@property (nonatomic,readonly) NSString * registrationTransitionHashIdentifier;
@property (nullable,nonatomic,readonly) NSString * currentUsername;
@property (nonatomic,readonly) UInt256 lastTransitionHash;
@property (nonatomic,readonly) uint32_t index;
@property (nonatomic,readonly) NSString * registrationFundingAddress;
@property (nonatomic,readonly) NSArray <NSString *> * usernames;
@property (nonatomic,readonly) NSString * dashpayBioString;
@property (nonatomic,readonly) uint64_t creditBalance;
@property (nonatomic,readonly) uint64_t syncHeight;

@property (nonatomic,readonly) NSArray <DSTransition*>* allTransitions;

@property (nonatomic,readonly) DSCreditFundingTransaction * creditFundingTransaction;

@property (nonatomic,readonly) DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition;

@property (nonatomic,readonly) DSContactEntity* ownContact;

@property (nonatomic,readonly,getter=isRegistered) BOOL registered;

-(instancetype)initAtIndex:(uint32_t)index inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initAtIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithFundingTransaction:(DSCreditFundingTransaction*)creditFundingTransaction inWallet:(DSWallet* _Nonnull)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(void)addUsername:(NSString*)username;

-(uint32_t)indexOfKey:(DSKey*)key;

-(DSBlockchainIdentityUsernameStatus)statusOfUsername:(NSString*)username;

-(void)generateBlockchainIdentityExtendedPublicKeys:(void (^ _Nullable)(BOOL registered))completion;

-(void)registerInWallet;

-(void)registerInWalletForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId;

-(void)fundingTransactionForTopupAmount:(uint64_t)topupAmount toAddress:(NSString*)address fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSCreditFundingTransaction * fundingTransaction))completion;

-(void)registrationTransitionWithCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition))completion;

-(void)topupTransitionForForFundingTransaction:(DSTransaction*)fundingTransaction completion:(void (^ _Nullable)(DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransition))completion;

-(void)updateTransitionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainIdentityUpdateTransition * blockchainIdentityUpdateTransition))completion;

-(void)createAndPublishRegistrationTransitionWithCompletion:(void (^ _Nullable)(NSDictionary * _Nullable successInfo, NSError * _Nullable error))completion;

-(void)updateWithTopupTransition:(DSBlockchainIdentityTopupTransition*)blockchainIdentityTopupTransaction save:(BOOL)save;
-(void)updateWithUpdateTransition:(DSBlockchainIdentityUpdateTransition*)blockchainIdentityResetTransaction save:(BOOL)save;
-(void)updateWithCloseTransition:(DSBlockchainIdentityCloseTransition*)blockchainIdentityCloseTransaction save:(BOOL)save;
-(void)updateWithDocumentTransition:(DSDocumentTransition*)transition save:(BOOL)save;

-(DSKey*)createNewKeyOfType:(DSDerivationPathSigningAlgorith)type returnIndex:(uint32_t *)rIndex;

-(void)signStateTransition:(DSTransition*)transition forKeyIndex:(uint32_t)keyIndex ofType:(DSDerivationPathSigningAlgorith)signingAlgorithm withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion;

-(void)signStateTransition:(DSTransition*)transition withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion;

-(BOOL)verifySignature:(NSData*)signature ofType:(DSDerivationPathSigningAlgorith)signingAlgorithm forMessageDigest:(UInt256)messageDigest;

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
