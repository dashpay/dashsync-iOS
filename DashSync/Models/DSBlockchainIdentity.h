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
@class DSWallet,DSBlockchainIdentityRegistrationTransition,DSBlockchainIdentityTopupTransition,DSBlockchainIdentityUpdateTransition,DSBlockchainIdentityCloseTransition,DSAccount,DSChain,DSTransition,DSContactEntity,DSPotentialOneWayFriendship,DSTransaction,DSFriendRequestEntity,DSPotentialContact,DSCreditFundingTransaction,DSDocumentTransition,DSKey,DPDocumentFactory;

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityRegistrationStatus) {
    DSBlockchainIdentityRegistrationStatus_Unknown = 0,
    DSBlockchainIdentityRegistrationStatus_Registered = 1,
    DSBlockchainIdentityRegistrationStatus_Registering = 2,
    DSBlockchainIdentityRegistrationStatus_NotRegistered = 3, //sent to DAPI, not yet confirmed
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityUsernameStatus) {
    DSBlockchainIdentityUsernameStatus_NotPresent = 0,
    DSBlockchainIdentityUsernameStatus_Initial = 1,
    DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending = 2,
    DSBlockchainIdentityUsernameStatus_Preordered = 3,
    DSBlockchainIdentityUsernameStatus_RegistrationPending = 4, //sent to DAPI, not yet confirmed
    DSBlockchainIdentityUsernameStatus_Confirmed = 5,
    DSBlockchainIdentityUsernameStatus_TakenOnNetwork = 6,
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityType) {
    DSBlockchainIdentityType_Unknown = 0,
    DSBlockchainIdentityType_User = 1,
    DSBlockchainIdentityType_Application = 2,
};

#define BLOCKCHAIN_USERNAME_STATUS @"BLOCKCHAIN_USERNAME_STATUS"
#define BLOCKCHAIN_USERNAME_SALT @"BLOCKCHAIN_USERNAME_SALT"

FOUNDATION_EXPORT NSString* const DSBlockchainIdentitiesDidUpdateNotification;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityDidUpdateUsernameStatusNotification;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityKey;

@interface DSBlockchainIdentity : NSObject

/*! @brief This is the unique identifier representing the blockchain identity. It is derived from the credit funding transaction credit burn UTXO (as of dpp v10). Returned as a 256 bit number */
@property (nonatomic,readonly) UInt256 uniqueID;

/*! @brief This is the unique identifier representing the blockchain identity. It is derived from the credit funding transaction credit burn UTXO (as of dpp v10). Returned as a base 58 string of a 256 bit number */
@property (nonatomic,readonly) NSString * uniqueIdString;

/*! @brief This is the unique identifier representing the blockchain identity. It is derived from the credit funding transaction credit burn UTXO (as of dpp v10). Returned as a NSData of a 256 bit number */
@property (nonatomic,readonly) NSData * uniqueIDData;

/*! @brief This is the outpoint of the registration credit funding transaction. It is used to determine the unique ID by double SHA256 its value. Returned as a UTXO { .hash , .n } */
@property (nonatomic,readonly) DSUTXO lockedOutpoint;

/*! @brief This is the outpoint of the registration credit funding transaction. It is used to determine the unique ID by double SHA256 its value. Returned as an NSData of a UTXO { .hash , .n } */
@property (nonatomic,readonly) NSData * lockedOutpointData;

/*! @brief This is the wallet holding the blockchain identity. There should always be a wallet associated to a blockchain identity and hence this should never be nil. */
@property (nonatomic,weak,readonly) DSWallet * wallet;

/*! @brief This is the index of the blockchain identity in the wallet. The index is the top derivation used to derive an extended set of keys for the identity. No two blockchain identities should be allowed to have the same index in a wallet. For example m/.../.../.../index/key */
@property (nonatomic,readonly) uint32_t index;

/*! @brief Related to DPNS. This is the list of usernames that are associated to the identity. These usernames however might not yet be registered or might be invalid. This can be used in tandem with the statusOfUsername: method */
@property (nonatomic,readonly) NSArray <NSString *> * usernames;

/*! @brief Related to DPNS. This is current and most likely username associated to the identity. It is not necessarily registered yet on L2 however so its state should be determined with the statusOfUsername: method
    @discussion There are situations where this is nil as it is not yet known or if no username has yet been set. */
@property (nullable,nonatomic,readonly) NSString * currentUsername;

/*! @brief Related to registering the identity. This is the address used to fund the registration of the identity. Dash sent to this address in the special credit funding transaction will be converted to L2 credits */
@property (nonatomic,readonly) NSString * registrationFundingAddress;

/*! @brief Related to Dashpay. This is the users status message */
@property (nonatomic,readonly) NSString * dashpayBioString;

/*! @brief The known balance in credits of the identity */
@property (nonatomic,readonly) uint64_t creditBalance;

/*! @brief The number of active keys that the blockchain identity has */
@property (nonatomic,readonly) uint32_t activeKeys;

/*! @brief The type of the blockchain identity, it can be either an application or a user, with more potential types to come */
@property (nonatomic,assign) DSBlockchainIdentityType type;

/*! @brief This is the transaction on L1 that has an output that is used to fund the creation of this blockchain identity.
    @discussion There are situations where this is nil as it is not yet known ; if the blockchain identity is being retrieved from L2 or if we are resyncing the chain. */
@property (nullable,nonatomic,readonly) DSCreditFundingTransaction * registrationCreditFundingTransaction;

/*! @brief In our system a contact is a vue on a blockchain identity for Dashpay. A blockchain identity is therefore represented by a contact that will have relationships in the system */
@property (nonatomic,readonly) DSContactEntity* ownContact;

/*! @brief This is the status of the registration of the identity. It starts off in an initial status, and ends in a confirmed status */
@property (nonatomic,readonly) DSBlockchainIdentityRegistrationStatus registrationStatus;

/*! @brief This is the localized status of the registration of the identity returned as a string. It starts off in an initial status, and ends in a confirmed status */
@property (nonatomic,readonly) NSString * localizedRegistrationStatusString;

/*! @brief This is a convenience method that checks to see if registrationStatus is confirmed */
@property (nonatomic,readonly,getter=isRegistered) BOOL registered;

/*! @brief This is the localized type of the identity returned as a string. */
@property (nonatomic,readonly) NSString * localizedBlockchainIdentityTypeString;

-(void)addUsername:(NSString*)username save:(BOOL)save;

-(void)retrieveIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success))completion;

-(void)fetchAndUpdateContract:(DPContract*)contract;

-(uint32_t)indexOfKey:(DSKey*)key;

-(DSBlockchainIdentityUsernameStatus)statusOfUsername:(NSString*)username;

-(void)generateBlockchainIdentityExtendedPublicKeys:(void (^ _Nullable)(BOOL registered))completion;

-(void)registerInWallet;

-(BOOL)unregisterLocally;

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

-(void)encryptData:(NSData*)data withKeyAtIndex:(uint32_t)index forRecipientKey:(DSKey*)recipientKey withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(NSData* encryptedData))completion;

-(void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL))completion;

-(void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialOneWayFriendship*)potentialFriendship completion:(void (^)(BOOL))completion;

-(void)acceptFriendRequest:(DSFriendRequestEntity*)friendRequest completion:(void (^)(BOOL))completion;

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success))completion;

- (void)fetchIncomingContactRequests:(void (^)(BOOL success))completion;

- (void)fetchProfile:(void (^)(BOOL success))completion;

- (void)createOrUpdateProfileWithAboutMeString:(NSString*)aboutme avatarURLString:(NSString *)avatarURLString completion:(void (^)(BOOL success))completion;

+ (NSString*)localizedBlockchainIdentityTypeStringForType:(DSBlockchainIdentityType)type;

-(void)registerUsernames;

- (void)fetchUsernamesWithCompletion:(void (^)(BOOL))completion;

@end

NS_ASSUME_NONNULL_END
