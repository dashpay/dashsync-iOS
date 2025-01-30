//
//  DSIdentity.h
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "BigIntTypes.h"
#import "DSDerivationPath.h"
#import "DSKeyManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class DSWallet, DSAccount, DSChain, DSDashpayUserEntity, DSPotentialOneWayFriendship, DSTransaction, DSFriendRequestEntity, DSPotentialContact, DSAssetLockTransaction, DSTransientDashpayUser, DSInvitation, DSAuthenticationKeysDerivationPath, UIImage;

typedef NS_ENUM(NSUInteger, DSIdentityRegistrationStep)
{
    DSIdentityRegistrationStep_None = 0,
    DSIdentityRegistrationStep_FundingTransactionCreation = 1,
    DSIdentityRegistrationStep_FundingTransactionAccepted = 2,
    DSIdentityRegistrationStep_LocalInWalletPersistence = 4,
    DSIdentityRegistrationStep_ProofAvailable = 8,
    DSIdentityRegistrationStep_L1Steps = DSIdentityRegistrationStep_FundingTransactionCreation | DSIdentityRegistrationStep_FundingTransactionAccepted | DSIdentityRegistrationStep_LocalInWalletPersistence | DSIdentityRegistrationStep_ProofAvailable,
    DSIdentityRegistrationStep_Identity = 16,
    DSIdentityRegistrationStep_RegistrationSteps = DSIdentityRegistrationStep_L1Steps | DSIdentityRegistrationStep_Identity,
    DSIdentityRegistrationStep_Username = 32,
    DSIdentityRegistrationStep_RegistrationStepsWithUsername = DSIdentityRegistrationStep_RegistrationSteps | DSIdentityRegistrationStep_Username,
    DSIdentityRegistrationStep_Profile = 64,
    DSIdentityRegistrationStep_RegistrationStepsWithUsernameAndDashpayProfile = DSIdentityRegistrationStep_RegistrationStepsWithUsername | DSIdentityRegistrationStep_Profile,
    DSIdentityRegistrationStep_All = DSIdentityRegistrationStep_RegistrationStepsWithUsernameAndDashpayProfile,
    DSIdentityRegistrationStep_Cancelled = 1 << 30
};

typedef NS_ENUM(NSUInteger, DSIdentityMonitorOptions)
{
    DSIdentityMonitorOptions_None = 0,
    DSIdentityMonitorOptions_AcceptNotFoundAsNotAnError = 1,
};

typedef NS_ENUM(NSUInteger, DSIdentityQueryStep)
{
    DSIdentityQueryStep_None = DSIdentityRegistrationStep_None,         //0
    DSIdentityQueryStep_Identity = DSIdentityRegistrationStep_Identity, //16
    DSIdentityQueryStep_Username = DSIdentityRegistrationStep_Username, //32
    DSIdentityQueryStep_Profile = DSIdentityRegistrationStep_Profile,   //64
    DSIdentityQueryStep_IncomingContactRequests = 128,
    DSIdentityQueryStep_OutgoingContactRequests = 256,
    DSIdentityQueryStep_ContactRequests = DSIdentityQueryStep_IncomingContactRequests | DSIdentityQueryStep_OutgoingContactRequests,
    DSIdentityQueryStep_AllForForeignIdentity = DSIdentityQueryStep_Identity | DSIdentityQueryStep_Username | DSIdentityQueryStep_Profile,
    DSIdentityQueryStep_AllForLocalIdentity = DSIdentityQueryStep_Identity | DSIdentityQueryStep_Username | DSIdentityQueryStep_Profile | DSIdentityQueryStep_ContactRequests,
    DSIdentityQueryStep_NoIdentity = 1 << 28,
    DSIdentityQueryStep_BadQuery = 1 << 29,
    DSIdentityQueryStep_Cancelled = 1 << 30
};

typedef NS_ENUM(NSUInteger, DSIdentityRegistrationStatus)
{
    DSIdentityRegistrationStatus_Unknown = 0,
    DSIdentityRegistrationStatus_Registered = 1,
    DSIdentityRegistrationStatus_Registering = 2,
    DSIdentityRegistrationStatus_NotRegistered = 3, //sent to DAPI, not yet confirmed
};

typedef NS_ENUM(NSUInteger, DSIdentityUsernameStatus)
{
    DSIdentityUsernameStatus_NotPresent = 0,
    DSIdentityUsernameStatus_Initial = 1,
    DSIdentityUsernameStatus_PreorderRegistrationPending = 2,
    DSIdentityUsernameStatus_Preordered = 3,
    DSIdentityUsernameStatus_RegistrationPending = 4, //sent to DAPI, not yet confirmed
    DSIdentityUsernameStatus_Confirmed = 5,
    DSIdentityUsernameStatus_TakenOnNetwork = 6,
};

typedef NS_ENUM(NSUInteger, DSIdentityFriendshipStatus)
{
    DSIdentityFriendshipStatus_Unknown = NSUIntegerMax,
    DSIdentityFriendshipStatus_None = 0,
    DSIdentityFriendshipStatus_Outgoing = 1,
    DSIdentityFriendshipStatus_Incoming = 2,
    DSIdentityFriendshipStatus_Friends = DSIdentityFriendshipStatus_Outgoing | DSIdentityFriendshipStatus_Incoming,
};

typedef NS_ENUM(NSUInteger, DSIdentityRetryDelayType)
{
    DSIdentityRetryDelayType_Linear = 0,
    DSIdentityRetryDelayType_SlowingDown20Percent = 1,
    DSIdentityRetryDelayType_SlowingDown50Percent = 2,
};

typedef NS_ENUM(NSUInteger, DSIdentityKeyStatus)
{
    DSIdentityKeyStatus_Unknown = 0,
    DSIdentityKeyStatus_Registered = 1,
    DSIdentityKeyStatus_Registering = 2,
    DSIdentityKeyStatus_NotRegistered = 3,
    DSIdentityKeyStatus_Revoked = 4,
};

#define BLOCKCHAIN_USERNAME_STATUS @"BLOCKCHAIN_USERNAME_STATUS"
#define BLOCKCHAIN_USERNAME_PROPER @"BLOCKCHAIN_USERNAME_PROPER"
#define BLOCKCHAIN_USERNAME_DOMAIN @"BLOCKCHAIN_USERNAME_DOMAIN"
#define BLOCKCHAIN_USERNAME_SALT @"BLOCKCHAIN_USERNAME_SALT"

#define ERROR_MEM_ALLOC [NSError errorWithCode:500 localizedDescriptionKey:@"Internal memory allocation error"]
#define ERROR_MALFORMED_RESPONSE [NSError errorWithCode:501 localizedDescriptionKey:@"Malformed platform response"]

FOUNDATION_EXPORT NSString *const DSIdentityDidUpdateNotification;
FOUNDATION_EXPORT NSString *const DSIdentityDidUpdateUsernameStatusNotification;
FOUNDATION_EXPORT NSString *const DSIdentityKey;
FOUNDATION_EXPORT NSString *const DSIdentityUsernameKey;
FOUNDATION_EXPORT NSString *const DSIdentityUsernameDomainKey;

FOUNDATION_EXPORT NSString *const DSIdentityUpdateEvents;
FOUNDATION_EXPORT NSString *const DSIdentityUpdateEventKeyUpdate;
FOUNDATION_EXPORT NSString *const DSIdentityUpdateEventRegistration;
FOUNDATION_EXPORT NSString *const DSIdentityUpdateEventCreditBalance;
FOUNDATION_EXPORT NSString *const DSIdentityUpdateEventType;
FOUNDATION_EXPORT NSString *const DSIdentityUpdateEventDashpaySyncronizationBlockHash;

@interface DSIdentity : NSObject

/*! @brief This is the unique identifier representing the blockchain identity. It is derived from the credit funding transaction credit burn UTXO (as of dpp v10). Returned as a 256 bit number */
@property (nonatomic, readonly) UInt256 uniqueID;
/*! @brief This is the unique identifier representing the blockchain identity. It is derived from the credit funding transaction credit burn UTXO (as of dpp v10). Returned as a base 58 string of a 256 bit number */
@property (nonatomic, readonly) NSString *uniqueIdString;
/*! @brief This is the unique identifier representing the blockchain identity. It is derived from the credit funding transaction credit burn UTXO (as of dpp v10). Returned as a NSData of a 256 bit number */
@property (nonatomic, readonly) NSData *uniqueIDData;
/*! @brief This is the outpoint of the registration credit funding transaction. It is used to determine the unique ID by double SHA256 its value. Returned as a UTXO { .hash , .n } */
@property (nonatomic, readonly) DSUTXO lockedOutpoint;
/*! @brief This is the outpoint of the registration credit funding transaction. It is used to determine the unique ID by double SHA256 its value. Returned as an NSData of a UTXO { .hash , .n } */
@property (nonatomic, readonly) NSData *lockedOutpointData;
/*! @brief This is if the blockchain identity is present in wallets or not. If this is false then the blockchain identity is known for example from being a dashpay friend. */
@property (nonatomic, readonly) BOOL isLocal;
/*! @brief This is if the blockchain identity is made for being an invitation. All invitations should be marked as non local as well. */
@property (nonatomic, readonly) BOOL isOutgoingInvitation;
/*! @brief This is if the blockchain identity is made from an invitation we received. */
@property (nonatomic, readonly) BOOL isFromIncomingInvitation;
/*! @brief This is TRUE if the blockchain identity is an effemeral identity returned when searching. */
@property (nonatomic, readonly) BOOL isTransient;
/*! @brief This is TRUE only if the blockchain identity is contained within a wallet. It could be in a cleanup phase where it was removed from the wallet but still being help in memory by callbacks. */
@property (nonatomic, readonly) BOOL isActive;
/*! @brief This references transient Dashpay user info if on a transient blockchain identity. */
//@property (nonatomic, readonly, nullable) DMaybeTransientUser *transientDashpayUser;
@property (nonatomic, readonly) DSTransientDashpayUser *transientDashpayUser;
/*! @brief This is the bitwise steps that the identity has already performed in registration. */
@property (nonatomic, readonly) DSIdentityRegistrationStep stepsCompleted;
/*! @brief This is the wallet holding the blockchain identity. There should always be a wallet associated to a blockchain identity if the blockchain identity is local, but never if it is not. */
@property (nonatomic, weak, readonly) DSWallet *wallet;
/*! @brief This is invitation that is identity originated from. */
@property (nonatomic, weak, readonly) DSInvitation *associatedInvitation;
/*! @brief This is the index of the blockchain identity in the wallet. The index is the top derivation used to derive an extended set of keys for the identity. No two local blockchain identities should be allowed to have the same index in a wallet. For example m/.../.../.../index/key */
@property (nonatomic, readonly) uint32_t index;
/*! @brief Related to DPNS. This is current and most likely username associated to the identity. It is not necessarily registered yet on L2 however so its state should be determined with the statusOfUsername: method
    @discussion There are situations where this is nil as it is not yet known or if no username has yet been set. */
@property (nullable, nonatomic, readonly) NSString *currentDashpayUsername;
/*! @brief Related to registering the identity. This is the address used to fund the registration of the identity. Dash sent to this address in the special credit funding transaction will be converted to L2 credits */
@property (nonatomic, readonly) NSString *registrationFundingAddress;
/*! @brief The known balance in credits of the identity */
@property (nonatomic, readonly) uint64_t creditBalance;
/*! @brief The number of registered active keys that the blockchain identity has */
@property (nonatomic, readonly) uint32_t activeKeyCount;
/*! @brief The number of all keys that the blockchain identity has, registered, in registration, or inactive */
@property (nonatomic, readonly) uint32_t totalKeyCount;
/*! @brief This is the transaction on L1 that has an output that is used to fund the creation of this blockchain identity.
    @discussion There are situations where this is nil as it is not yet known ; if the blockchain identity is being retrieved from L2 or if we are resyncing the chain. */
@property (nullable, nonatomic, readonly) DSAssetLockTransaction *registrationAssetLockTransaction;
/*! @brief This is the hash of the transaction on L1 that has an output that is used to fund the creation of this blockchain identity.
    @discussion There are situations where this is nil as it is not yet known ; if the blockchain identity is being retrieved from L2 or if we are resyncing the chain. */
@property (nonatomic, readonly) UInt256 registrationAssetLockTransactionHash;
/*! @brief In our system a contact is a vue on a blockchain identity for Dashpay. A blockchain identity is therefore represented by a contact that will have relationships in the system. This is in the default backgroundContext. */
@property (nonatomic, readonly) DSDashpayUserEntity *matchingDashpayUserInViewContext;
/*! @brief This is the status of the registration of the identity. It starts off in an initial status, and ends in a confirmed status */
@property (nonatomic, readonly) DSIdentityRegistrationStatus registrationStatus;
/*! @brief This is the localized status of the registration of the identity returned as a string. It starts off in an initial status, and ends in a confirmed status */
@property (nonatomic, readonly) NSString *localizedRegistrationStatusString;
/*! @brief This is a convenience method that checks to see if registrationStatus is confirmed */
@property (nonatomic, readonly, getter=isRegistered) BOOL registered;
/*! @brief DashpaySyncronizationBlock represents the last L1 block height for which Dashpay would be synchronized, if this isn't at the end of the chain then we need to query L2 to make sure we don't need to update our bloom filter */
@property (nonatomic, readonly) uint32_t dashpaySyncronizationBlockHeight;
/*! @brief DashpaySyncronizationBlock represents the last L1 block hash for which Dashpay would be synchronized */
@property (nonatomic, readonly) UInt256 dashpaySyncronizationBlockHash;

// MARK: - Contracts

- (void)fetchAndUpdateContract:(DPContract *)contract;

// MARK: - Helpers

- (DSDashpayUserEntity *)matchingDashpayUserInContext:(NSManagedObjectContext *)context;

// MARK: - Identity

- (void)registerOnNetwork:(DSIdentityRegistrationStep)steps
       withFundingAccount:(DSAccount *)account
           forTopupAmount:(uint64_t)topupDuffAmount
                pinPrompt:(NSString *)prompt
           stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
               completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion;

- (void)continueRegisteringOnNetwork:(DSIdentityRegistrationStep)steps
                  withFundingAccount:(DSAccount *)fundingAccount
                      forTopupAmount:(uint64_t)topupDuffAmount
                           pinPrompt:(NSString *)prompt
                      stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                          completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion;

- (void)continueRegisteringIdentityOnNetwork:(DSIdentityRegistrationStep)steps
                              stepsCompleted:(DSIdentityRegistrationStep)stepsAlreadyCompleted
                              stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                                  completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion;

- (void)fetchIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success, BOOL found, NSError *error))completion;
- (void)fetchAllNetworkStateInformationWithCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion;
- (void)fetchNeededNetworkStateInformationWithCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion;
//- (BOOL)signStateTransition:(DSTransition *)transition;
//- (BOOL)signStateTransition:(DSTransition *)transition
//                forKeyIndex:(uint32_t)keyIndex
//                     ofType:(DKeyKind *)signingAlgorithm;
//- (void)signMessageDigest:(UInt256)digest
//              forKeyIndex:(uint32_t)keyIndex
//                   ofType:(DKeyKind *)signingAlgorithm
//               completion:(void (^_Nullable)(BOOL success, NSData *signature))completion;
- (BOOL)verifySignature:(NSData *)signature
            forKeyIndex:(uint32_t)keyIndex
                 ofType:(DKeyKind *)signingAlgorithm
       forMessageDigest:(UInt256)messageDigest;
- (BOOL)verifySignature:(NSData *)signature
                 ofType:(DKeyKind *)signingAlgorithm
       forMessageDigest:(UInt256)messageDigest;
- (void)createFundingPrivateKeyWithPrompt:(NSString *)prompt
                               completion:(void (^_Nullable)(BOOL success, BOOL cancelled))completion;
- (void)createFundingPrivateKeyForInvitationWithPrompt:(NSString *)prompt
                                            completion:(void (^_Nullable)(BOOL success, BOOL cancelled))completion;
- (void)createAndPublishRegistrationTransitionWithCompletion:(void (^_Nullable)(BOOL success, NSError *_Nullable error))completion;


- (void)encryptData:(NSData *)data withKeyAtIndex:(uint32_t)index
    forRecipientKey:(DOpaqueKey *)recipientKey
         completion:(void (^_Nullable)(NSData *encryptedData))completion;

/*! @brief Register the blockchain identity to its wallet. This should only be done once on the creation of the blockchain identity.
*/
- (void)registerInWallet;

/*! @brief Unregister the blockchain identity from the wallet. This should only be used if the blockchain identity is not yet registered or if a progressive wallet wipe is happening.
    @discussion When a blockchain identity is registered on the network it is automatically retrieved from the L1 chain on resync. If a client wallet wishes to change their default blockchain identity in a wallet it should be done by marking the default blockchain identity index in the wallet. Clients should not try to delete a registered blockchain identity from a wallet.
 */
- (BOOL)unregisterLocally;

/*! @brief Register the blockchain identity to its wallet from a credit funding registration transaction. This should only be done once on the creation of the blockchain identity.
    @param fundingTransaction The funding transaction used to initially fund the blockchain identity.
*/
- (void)registerInWalletForAssetLockTransaction:(DSAssetLockTransaction *)fundingTransaction;

// MARK: - Keys

/*! @brief Register the blockchain identity to its wallet from a credit funding registration transaction. This should only be done once on the creation of the blockchain identity.
*/

- (void)generateIdentityExtendedPublicKeysWithPrompt:(NSString *)prompt
                                          completion:(void (^_Nullable)(BOOL registered))completion;
- (BOOL)setExternalFundingPrivateKey:(DMaybeOpaqueKey *)privateKey;
- (BOOL)hasIdentityExtendedPublicKeys;
- (DSIdentityKeyStatus)statusOfKeyAtIndex:(NSUInteger)index;
- (DKeyKind *)typeOfKeyAtIndex:(NSUInteger)index;
- (DMaybeOpaqueKey *_Nullable)keyAtIndex:(NSUInteger)index;
- (uint32_t)keyCountForKeyType:(DKeyKind *)keyType;
+ (NSString *)localizedStatusOfKeyForIdentityKeyStatus:(DSIdentityKeyStatus)status;
- (NSString *)localizedStatusOfKeyAtIndex:(NSUInteger)index;
- (DMaybeOpaqueKey *_Nullable)createNewKeyOfType:(DKeyKind *)type
                                         saveKey:(BOOL)saveKey
                                     returnIndex:(uint32_t *)rIndex;
- (DMaybeOpaqueKey *)keyOfType:(DKeyKind *)type atIndex:(uint32_t)rIndex;
+ (DSAuthenticationKeysDerivationPath *_Nullable)derivationPathForType:(DKeyKind *)type
                                                             forWallet:(DSWallet *)wallet;
+ (DMaybeOpaqueKey *_Nullable)keyFromKeyDictionary:(NSDictionary *)dictionary
                                             rType:(uint32_t *)rType
                                            rIndex:(uint32_t *)rIndex;
//+ (DMaybeOpaqueKey *_Nullable)firstKeyInIdentityDictionary:(NSDictionary *)identityDictionary;

- (BOOL)activePrivateKeysAreLoadedWithFetchingError:(NSError **)error;
- (BOOL)verifyKeysForWallet:(DSWallet *)wallet;



@end

NS_ASSUME_NONNULL_END
