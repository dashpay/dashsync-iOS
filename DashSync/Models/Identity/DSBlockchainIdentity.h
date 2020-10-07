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
@class DSWallet,DSBlockchainIdentityRegistrationTransition,DSBlockchainIdentityTopupTransition,DSBlockchainIdentityUpdateTransition,DSBlockchainIdentityCloseTransition,DSAccount,DSChain,DSTransition,DSDashpayUserEntity,DSPotentialOneWayFriendship,DSTransaction,DSFriendRequestEntity,DSPotentialContact,DSCreditFundingTransaction,DSDocumentTransition,DSKey,DPDocumentFactory;

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityRegistrationStep) {
    DSBlockchainIdentityRegistrationStep_None = 0,
    DSBlockchainIdentityRegistrationStep_FundingTransactionCreation = 1,
    DSBlockchainIdentityRegistrationStep_FundingTransactionPublishing = 2,
    DSBlockchainIdentityRegistrationStep_LocalInWalletPersistence = 4,
    DSBlockchainIdentityRegistrationStep_L1Steps = DSBlockchainIdentityRegistrationStep_FundingTransactionCreation | DSBlockchainIdentityRegistrationStep_FundingTransactionPublishing | DSBlockchainIdentityRegistrationStep_LocalInWalletPersistence,
    DSBlockchainIdentityRegistrationStep_Identity = 8,
    DSBlockchainIdentityRegistrationStep_RegistrationSteps = DSBlockchainIdentityRegistrationStep_L1Steps | DSBlockchainIdentityRegistrationStep_Identity,
    DSBlockchainIdentityRegistrationStep_Username = 16,
    DSBlockchainIdentityRegistrationStep_RegistrationStepsWithUsername = DSBlockchainIdentityRegistrationStep_RegistrationSteps | DSBlockchainIdentityRegistrationStep_Username,
    DSBlockchainIdentityRegistrationStep_Profile = 32,
    DSBlockchainIdentityRegistrationStep_RegistrationStepsWithUsernameAndDashpayProfile = DSBlockchainIdentityRegistrationStep_RegistrationStepsWithUsername | DSBlockchainIdentityRegistrationStep_Profile,
    DSBlockchainIdentityRegistrationStep_All = DSBlockchainIdentityRegistrationStep_RegistrationStepsWithUsernameAndDashpayProfile,
    DSBlockchainIdentityRegistrationStep_Cancelled = 1 << 30
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityMonitorOptions) {
    DSBlockchainIdentityMonitorOptions_None = 0,
    DSBlockchainIdentityMonitorOptions_AcceptNotFoundAsNotAnError = 1,
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityQueryStep) {
    DSBlockchainIdentityQueryStep_None = DSBlockchainIdentityRegistrationStep_None, //0
    DSBlockchainIdentityQueryStep_Identity = DSBlockchainIdentityRegistrationStep_Identity,
    DSBlockchainIdentityQueryStep_Username = DSBlockchainIdentityRegistrationStep_Username,
    DSBlockchainIdentityQueryStep_Profile = DSBlockchainIdentityRegistrationStep_Profile,
    DSBlockchainIdentityQueryStep_IncomingContactRequests = 64,
    DSBlockchainIdentityQueryStep_OutgoingContactRequests = 128,
    DSBlockchainIdentityQueryStep_ContactRequests = DSBlockchainIdentityQueryStep_IncomingContactRequests | DSBlockchainIdentityQueryStep_OutgoingContactRequests,
    DSBlockchainIdentityQueryStep_AllForForeignBlockchainIdentity = DSBlockchainIdentityQueryStep_Identity | DSBlockchainIdentityQueryStep_Username | DSBlockchainIdentityQueryStep_Profile,
    DSBlockchainIdentityQueryStep_AllForLocalBlockchainIdentity = DSBlockchainIdentityQueryStep_Identity | DSBlockchainIdentityQueryStep_Username | DSBlockchainIdentityQueryStep_Profile | DSBlockchainIdentityQueryStep_ContactRequests,
    DSBlockchainIdentityQueryStep_BadQuery = 1 << 29,
    DSBlockchainIdentityQueryStep_Cancelled = 1 << 30
};

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

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityFriendshipStatus) {
    DSBlockchainIdentityFriendshipStatus_Unknown = NSUIntegerMax,
    DSBlockchainIdentityFriendshipStatus_None = 0,
    DSBlockchainIdentityFriendshipStatus_Outgoing = 1,
    DSBlockchainIdentityFriendshipStatus_Incoming = 2,
    DSBlockchainIdentityFriendshipStatus_Friends = DSBlockchainIdentityFriendshipStatus_Outgoing | DSBlockchainIdentityFriendshipStatus_Incoming,
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityRetryDelayType) {
    DSBlockchainIdentityRetryDelayType_Linear = 0,
    DSBlockchainIdentityRetryDelayType_SlowingDown20Percent = 1,
    DSBlockchainIdentityRetryDelayType_SlowingDown50Percent = 2,
};

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityKeyStatus) {
    DSBlockchainIdentityKeyStatus_Unknown = 0,
    DSBlockchainIdentityKeyStatus_Registered = 1,
    DSBlockchainIdentityKeyStatus_Registering = 2,
    DSBlockchainIdentityKeyStatus_NotRegistered = 3,
    DSBlockchainIdentityKeyStatus_Revoked = 4,
};

#define BLOCKCHAIN_USERNAME_STATUS @"BLOCKCHAIN_USERNAME_STATUS"
#define BLOCKCHAIN_USERNAME_PROPER @"BLOCKCHAIN_USERNAME_PROPER"
#define BLOCKCHAIN_USERNAME_DOMAIN @"BLOCKCHAIN_USERNAME_DOMAIN"
#define BLOCKCHAIN_USERNAME_SALT @"BLOCKCHAIN_USERNAME_SALT"

FOUNDATION_EXPORT NSString* const DSBlockchainIdentityDidUpdateNotification;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityDidUpdateUsernameStatusNotification;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityKey;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityUsernameKey;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityUsernameDomainKey;

FOUNDATION_EXPORT NSString* const DSBlockchainIdentityUpdateEvents;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityUpdateEventKeyUpdate;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityUpdateEventRegistration;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityUpdateEventCreditBalance;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityUpdateEventType;
FOUNDATION_EXPORT NSString* const DSBlockchainIdentityUpdateEventDashpaySyncronizationBlockHash;

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

/*! @brief This is if the blockchain identity is present in wallets or not. If this is false then the blockchain identity is known for example from being a dashpay friend. */
@property (nonatomic,readonly) BOOL isLocal;

/*! @brief This is TRUE if the blockchain identity is an effemeral identity returned when searching. */
@property (nonatomic,readonly) BOOL isTransient;

/*! @brief This is the bitwise steps that the identity has already performed in registration. */
@property (nonatomic,readonly) DSBlockchainIdentityRegistrationStep stepsCompleted;

/*! @brief This is the wallet holding the blockchain identity. There should always be a wallet associated to a blockchain identity if the blockchain identity is local, but never if it is not. */
@property (nonatomic,weak,readonly) DSWallet * wallet;

/*! @brief This is the index of the blockchain identity in the wallet. The index is the top derivation used to derive an extended set of keys for the identity. No two blockchain identities should be allowed to have the same index in a wallet. For example m/.../.../.../index/key */
@property (nonatomic,readonly) uint32_t index;

/*! @brief Related to DPNS. This is the list of usernames that are associated to the identity in the domain "dash". These usernames however might not yet be registered or might be invalid. This can be used in tandem with the statusOfUsername: method */
@property (nonatomic,readonly) NSArray <NSString *> * dashpayUsernames;

/*! @brief Related to DPNS. This is the list of usernames with their .dash domain that are associated to the identity in the domain "dash". These usernames however might not yet be registered or might be invalid. This can be used in tandem with the statusOfUsername: method */
@property (nonatomic,readonly) NSArray <NSString *> * dashpayUsernameFullPaths;

/*! @brief Related to DPNS. This is current and most likely username associated to the identity. It is not necessarily registered yet on L2 however so its state should be determined with the statusOfUsername: method
    @discussion There are situations where this is nil as it is not yet known or if no username has yet been set. */
@property (nullable,nonatomic,readonly) NSString * currentDashpayUsername;

/*! @brief Related to registering the identity. This is the address used to fund the registration of the identity. Dash sent to this address in the special credit funding transaction will be converted to L2 credits */
@property (nonatomic,readonly) NSString * registrationFundingAddress;

/*! @brief Related to Dashpay. This is the users status message */
@property (nonatomic,readonly) NSString * dashpayBioString;

/*! @brief The known balance in credits of the identity */
@property (nonatomic,readonly) uint64_t creditBalance;

/*! @brief The number of registered active keys that the blockchain identity has */
@property (nonatomic,readonly) uint32_t activeKeyCount;

/*! @brief The number of all keys that the blockchain identity has, registered, in registration, or inactive */
@property (nonatomic,readonly) uint32_t totalKeyCount;

/*! @brief This is the transaction on L1 that has an output that is used to fund the creation of this blockchain identity.
    @discussion There are situations where this is nil as it is not yet known ; if the blockchain identity is being retrieved from L2 or if we are resyncing the chain. */
@property (nullable,nonatomic,readonly) DSCreditFundingTransaction * registrationCreditFundingTransaction;

/*! @brief In our system a contact is a vue on a blockchain identity for Dashpay. A blockchain identity is therefore represented by a contact that will have relationships in the system. This is in the default backgroundContext. */
@property (nonatomic,readonly) DSDashpayUserEntity* matchingDashpayUserInViewContext;

/*! @brief This is the status of the registration of the identity. It starts off in an initial status, and ends in a confirmed status */
@property (nonatomic,readonly) DSBlockchainIdentityRegistrationStatus registrationStatus;

/*! @brief This is the localized status of the registration of the identity returned as a string. It starts off in an initial status, and ends in a confirmed status */
@property (nonatomic,readonly) NSString * localizedRegistrationStatusString;

/*! @brief This is a convenience method that checks to see if registrationStatus is confirmed */
@property (nonatomic,readonly,getter=isRegistered) BOOL registered;

/*! @brief This is a convenience factory to quickly make dashpay documents */
@property (nonatomic,readonly) DPDocumentFactory* dashpayDocumentFactory;

/*! @brief This is a convenience factory to quickly make dpns documents */
@property (nonatomic,readonly) DPDocumentFactory* dpnsDocumentFactory;

/*! @brief DashpaySyncronizationBlock represents the last L1 block height for which Dashpay would be synchronized, if this isn't at the end of the chain then we need to query L2 to make sure we don't need to update our bloom filter */
@property (nonatomic,readonly) uint32_t dashpaySyncronizationBlockHeight;

/*! @brief DashpaySyncronizationBlock represents the last L1 block hash for which Dashpay would be synchronized */
@property (nonatomic,readonly) UInt256 dashpaySyncronizationBlockHash;

// MARK: - Contracts

-(void)fetchAndUpdateContract:(DPContract*)contract;

// MARK: - Helpers

- (DSDashpayUserEntity*)matchingDashpayUserInContext:(NSManagedObjectContext*)context;

// MARK: - Identity

-(void)registerOnNetwork:(DSBlockchainIdentityRegistrationStep)steps withFundingAccount:(DSAccount*)account forTopupAmount:(uint64_t)topupDuffAmount stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion;

-(void)continueRegisteringOnNetwork:(DSBlockchainIdentityRegistrationStep)steps withFundingAccount:(DSAccount*)fundingAccount forTopupAmount:(uint64_t)topupDuffAmount stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion;

-(void)fundingTransactionForTopupAmount:(uint64_t)topupAmount toAddress:(NSString*)address fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSCreditFundingTransaction * fundingTransaction))completion;

-(void)fetchIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success, NSError * error))completion;

-(void)fetchAllNetworkStateInformationWithCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion;

-(void)fetchNeededNetworkStateInformationWithCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion;

-(void)signStateTransition:(DSTransition*)transition completion:(void (^ _Nullable)(BOOL success))completion;

-(void)signStateTransition:(DSTransition*)transition forKeyIndex:(uint32_t)keyIndex ofType:(DSKeyType)signingAlgorithm completion:(void (^ _Nullable)(BOOL success))completion;

-(BOOL)verifySignature:(NSData*)signature forKeyIndex:(uint32_t)keyIndex ofType:(DSKeyType)signingAlgorithm forMessageDigest:(UInt256)messageDigest;

-(BOOL)verifySignature:(NSData*)signature ofType:(DSKeyType)signingAlgorithm forMessageDigest:(UInt256)messageDigest;

-(void)createFundingPrivateKeyWithPrompt:(NSString*)prompt completion:(void (^ _Nullable)(BOOL success, BOOL cancelled))completion;

-(void)createAndPublishRegistrationTransitionWithCompletion:(void (^ _Nullable)(NSDictionary * _Nullable successInfo, NSError * _Nullable error))completion;



-(void)encryptData:(NSData*)data withKeyAtIndex:(uint32_t)index forRecipientKey:(DSKey*)recipientKey completion:(void (^ _Nullable)(NSData* encryptedData))completion;

/*! @brief Register the blockchain identity to its wallet. This should only be done once on the creation of the blockchain identity.
*/
-(void)registerInWallet;

/*! @brief Unregister the blockchain identity from the wallet. This should only be used if the blockchain identity is not yet registered or if a progressive wallet wipe is happening.
    @discussion When a blockchain identity is registered on the network it is automatically retrieved from the L1 chain on resync. If a client wallet wishes to change their default blockchain identity in a wallet it should be done by marking the default blockchain identity index in the wallet. Clients should not try to delete a registered blockchain identity from a wallet.
 */
-(BOOL)unregisterLocally;

/*! @brief Register the blockchain identity to its wallet from a credit funding registration transaction. This should only be done once on the creation of the blockchain identity.
    @param fundingTransaction The funding transaction used to initially fund the blockchain identity.
*/
-(void)registerInWalletForRegistrationFundingTransaction:(DSCreditFundingTransaction*)fundingTransaction;

// MARK: - Keys

/*! @brief Register the blockchain identity to its wallet from a credit funding registration transaction. This should only be done once on the creation of the blockchain identity.
*/
-(void)generateBlockchainIdentityExtendedPublicKeysWithPrompt:(NSString*)prompt completion:(void (^ _Nullable)(BOOL registered))completion;

-(BOOL)hasBlockchainIdentityExtendedPublicKeys;

-(DSBlockchainIdentityKeyStatus)statusOfKeyAtIndex:(NSUInteger)index;

-(DSKeyType)typeOfKeyAtIndex:(NSUInteger)index;

-(DSKey* _Nullable)keyAtIndex:(NSUInteger)index;

-(uint32_t)keyCountForKeyType:(DSKeyType)keyType;

+(NSString*)localizedStatusOfKeyForBlockchainIdentityKeyStatus:(DSBlockchainIdentityKeyStatus)status;

-(NSString*)localizedStatusOfKeyAtIndex:(NSUInteger)index;

-(DSKey* _Nullable)createNewKeyOfType:(DSKeyType)type saveKey:(BOOL)saveKey returnIndex:(uint32_t *)rIndex;

-(DSKey* _Nullable)keyOfType:(DSKeyType)type atIndex:(uint32_t)rIndex;

// MARK: - Dashpay

- (void)sendNewFriendRequestToBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity completion:(void (^)(BOOL success, NSArray<NSError *> * _Nullable errors))completion;

- (void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^ _Nullable)(BOOL success, NSArray<NSError *> * errors))completion;

- (void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialOneWayFriendship*)potentialFriendship completion:(void (^ _Nullable)(BOOL success, NSArray<NSError *> * errors))completion;


- (void)acceptFriendRequestFromBlockchainIdentity:(DSBlockchainIdentity*)otherBlockchainIdentity completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion;

- (void)acceptFriendRequest:(DSFriendRequestEntity*)friendRequest completion:(void (^ _Nullable)(BOOL success, NSArray<NSError *> * errors))completion;

- (BOOL)activePrivateKeysAreLoadedWithFetchingError:(NSError**)error;

- (void)fetchContactRequests:(void (^ _Nullable)(BOOL success, NSArray<NSError *> *errors))completion;

- (void)fetchOutgoingContactRequests:(void (^ _Nullable)(BOOL success, NSArray<NSError *> *errors))completion;

- (void)fetchIncomingContactRequests:(void (^ _Nullable)(BOOL success, NSArray<NSError *> *errors))completion;

- (void)fetchProfileWithCompletion:(void (^ _Nullable)(BOOL success, NSError * error))completion;

- (void)updateDashpayProfileWithDisplayName:(NSString*)displayName publicMessage:(NSString*)publicMessage avatarURLString:(NSString *)avatarURLString;

- (void)signedProfileDocumentTransitionInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(DSTransition * transition, BOOL cancelled, NSError * error))completion;

- (void)signAndPublishProfileWithCompletion:(void (^)(BOOL success, BOOL cancelled, NSError * error))completion;

// MARK: - Dashpay Friendship Helpers

- (DSBlockchainIdentityFriendshipStatus)friendshipStatusForRelationshipWithBlockchainIdentity:(DSBlockchainIdentity*)otherBlockchainIdentity;

// MARK: - DPNS

-(void)addDashpayUsername:(NSString*)username save:(BOOL)save;

-(void)addUsername:(NSString*)username inDomain:(NSString*)domain save:(BOOL)save;

-(DSBlockchainIdentityUsernameStatus)statusOfUsername:(NSString*)username inDomain:(NSString*)domain;

-(DSBlockchainIdentityUsernameStatus)statusOfDashpayUsername:(NSString*)username;

-(void)registerUsernamesWithCompletion:(void (^ _Nullable)(BOOL success, NSError * error))completion;

- (void)fetchUsernamesWithCompletion:(void (^ _Nullable)(BOOL success, NSError * error))completion;

@end

NS_ASSUME_NONNULL_END
