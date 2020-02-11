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
@class DSWallet,DSBlockchainIdentityRegistrationTransition,DSBlockchainIdentityTopupTransition,DSBlockchainIdentityUpdateTransition,DSBlockchainIdentityCloseTransition,DSAccount,DSChain,DSTransition,DSContactEntity,DSPotentialFriendship,DSTransaction,DSFriendRequestEntity,DSPotentialContact,DSCreditFundingTransaction,DSDocumentTransition,DSKey,DPDocumentFactory;

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityRegistrationStatus) {
    DSBlockchainIdentityRegistrationStatus_Unknown = 0,
    DSBlockchainIdentityRegistrationStatus_Registered = 1,
    DSBlockchainIdentityRegistrationStatus_Registering = 2,
    DSBlockchainIdentityRegistrationStatus_NotRegistered = 3, //sent to DAPI, not yet confirmed
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityUsernameStatus) {
    DSBlockchainIdentityUsernameStatus_NotPresent = 0,
    DSBlockchainIdentityUsernameStatus_Initial = 1,
    DSBlockchainIdentityUsernameStatus_Preordered = 2,
    DSBlockchainIdentityUsernameStatus_RegistrationPending = 3, //sent to DAPI, not yet confirmed
    DSBlockchainIdentityUsernameStatus_Confirmed = 4,
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityType) {
    DSBlockchainIdentityType_Unknown = 0,
    DSBlockchainIdentityType_User = 1,
    DSBlockchainIdentityType_Application = 2,
};

@interface DSBlockchainIdentity : NSObject

@property (nonatomic,weak,readonly) DSWallet * wallet;
@property (nonatomic,readonly) NSString * uniqueIdString;
@property (nonatomic,readonly) UInt256 uniqueID;
@property (nonatomic,readonly) UInt256 registrationTransitionHash;
@property (nonatomic,readonly) NSData * uniqueIDData;
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
@property (nonatomic,readonly) DSBlockchainIdentityType type;

@property (nonatomic,readonly) NSArray <DSTransition*>* allTransitions;

@property (nonatomic,readonly) DSCreditFundingTransaction * registrationCreditFundingTransaction;

@property (nonatomic,readonly) DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition;

@property (nonatomic,readonly) DSContactEntity* ownContact;

@property (nonatomic,readonly) DPDocumentFactory* dashpayDocumentFactory;
@property (nonatomic,readonly) DPDocumentFactory* dpnsDocumentFactory;

@property (nonatomic,readonly) DSBlockchainIdentityRegistrationStatus registrationStatus;

@property (nonatomic,readonly) NSString * registrationStatusString;

@property (nonatomic,readonly,getter=isRegistered) BOOL registered;

@property (nonatomic,readonly) NSString * localizedBlockchainIdentityTypeString;

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithType:(DSBlockchainIdentityType)type withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameStatusDictionary:(NSDictionary <NSString *,NSNumber *> * _Nullable)usernameStatuses inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(void)addUsername:(NSString*)username save:(BOOL)save;

-(void)retrieveIdentityNetworkStateInformation;

-(void)fetchAndUpdateContract:(DPContract*)contract;

-(uint32_t)indexOfKey:(DSKey*)key;

-(DSBlockchainIdentityUsernameStatus)statusOfUsername:(NSString*)username;

-(void)generateBlockchainIdentityExtendedPublicKeys:(void (^ _Nullable)(BOOL registered))completion;

-(void)registerInWallet;

-(void)registerInWalletForRegistrationFundingTransaction:(DSCreditFundingTransaction*)fundingTransaction;

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

+ (NSString*)localizedBlockchainIdentityTypeStringForType:(DSBlockchainIdentityType)type;

@end

NS_ASSUME_NONNULL_END
