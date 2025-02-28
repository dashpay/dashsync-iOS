//
//  DSIdentity.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//
#import "DSIdentity.h"
#import "DPContract+Protected.h"
#import "DSAccount.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSAssetLockDerivationPath.h"
#import "DSAssetLockTransaction.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSAuthenticationManager.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Transaction.h"
#import "DSChain+Wallet.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSIdentitiesManager+Protected.h"
#import "DSIdentitiesManager+CoreData.h"
#import "DSIdentity+ContactRequest.h"
#import "DSIdentity+Profile.h"
#import "DSIdentity+Protected.h"
#import "DSIdentity+Username.h"
#import "DSInstantSendTransactionLock.h"
#import "DSInvitation+Protected.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSOptionsManager.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSWallet+Identity.h"
#import "NSData+Encryption.h"
#import "NSDate+Utils.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSIndexPath+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSObject+Notification.h"

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"
#define DEFAULT_FETCH_IDENTITY_RETRY_COUNT 5

#define ERROR_REGISTER_KEYS_BEFORE_IDENTITY [NSError errorWithCode:500 localizedDescriptionKey:@"The blockchain identity extended public keys need to be registered before you can register a identity."]
#define ERROR_FUNDING_TX_CREATION [NSError errorWithCode:500 localizedDescriptionKey:@"Funding transaction could not be created"]
#define ERROR_FUNDING_TX_SIGNING [NSError errorWithCode:500 localizedDescriptionKey:@"Transaction could not be signed"]
#define ERROR_FUNDING_TX_TIMEOUT [NSError errorWithCode:500 localizedDescriptionKey:@"Timeout while waiting for funding transaction to be accepted by network"]
#define ERROR_FUNDING_TX_ISD_TIMEOUT [NSError errorWithCode:500 localizedDescriptionKey:@"Timeout while waiting for funding transaction to acquire an instant send lock"]
#define ERROR_REG_TRANSITION [NSError errorWithCode:501 localizedDescriptionKey:@"Unable to register registration transition"]
#define ERROR_REG_TRANSITION_CREATION [NSError errorWithCode:501 localizedDescriptionKey:@"Unable to create registration transition"]
#define ERROR_ATTEMPT_QUERY_WITHOUT_KEYS [NSError errorWithCode:501 localizedDescriptionKey:@"Attempt to query DAPs for identity with no active keys"]
#define ERROR_NO_FUNDING_PRV_KEY [NSError errorWithCode:500 localizedDescriptionKey:@"The blockchain identity funding private key should be first created with createFundingPrivateKeyWithCompletion"]
#define ERROR_FUNDING_TX_NOT_MINED [NSError errorWithCode:500 localizedDescriptionKey:@"The registration credit funding transaction has not been mined yet and has no instant send lock"]
#define ERROR_NO_IDENTITY [NSError errorWithCode:500 localizedDescriptionKey:@"Platform returned no identity when one was expected"]

typedef NS_ENUM(NSUInteger, DSIdentityKeyDictionary) {
    DSIdentityKeyDictionary_Key = 0,
    DSIdentityKeyDictionary_KeyType = 1,
    DSIdentityKeyDictionary_KeyStatus = 2,
};

NSString * DSRegistrationStepsDescription(DSIdentityRegistrationStep step) {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_None))
        [components addObject:@"None"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_FundingTransactionCreation))
        [components addObject:@"FundingTransactionCreation"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_FundingTransactionAccepted))
        [components addObject:@"FundingTransactionAccepted"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_LocalInWalletPersistence))
        [components addObject:@"LocalInWalletPersistence"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_ProofAvailable))
        [components addObject:@"ProofAvailable"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_L1Steps))
        [components addObject:@"L1Steps"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_Identity))
        [components addObject:@"Identity"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_RegistrationSteps))
        [components addObject:@"RegistrationSteps"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_Username))
        [components addObject:@"Username"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_RegistrationStepsWithUsername))
        [components addObject:@"RegistrationStepsWithUsername"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_Profile))
        [components addObject:@"Profile"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_RegistrationStepsWithUsernameAndDashpayProfile))
        [components addObject:@"RegistrationStepsWithUsernameAndDashpayProfile"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_All))
        [components addObject:@"All"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_Cancelled))
        [components addObject:@"Cancelled"];
    return [components componentsJoinedByString:@" | "];
}

NSString * DSIdentityQueryStepsDescription(DSIdentityQueryStep step) {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_None))
        [components addObject:@"None"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_Identity))
        [components addObject:@"Identity"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_Username))
        [components addObject:@"Username"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_Profile))
        [components addObject:@"Profile"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_IncomingContactRequests))
        [components addObject:@"IncomingContactRequests"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_OutgoingContactRequests))
        [components addObject:@"OutgoingContactRequests"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_ContactRequests))
        [components addObject:@"ContactRequests"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_AllForForeignIdentity))
        [components addObject:@"AllForForeignIdentity"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_AllForLocalIdentity))
        [components addObject:@"AllForLocalIdentity"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_NoIdentity))
        [components addObject:@"NoIdentity"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_BadQuery))
        [components addObject:@"BadQuery"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_Cancelled))
        [components addObject:@"Cancelled"];
    return [components componentsJoinedByString:@" | "];
}

@interface DSIdentity ()

@property (nonatomic, assign) UInt256 uniqueID;
@property (nonatomic, assign) BOOL isOutgoingInvitation;
@property (nonatomic, assign) BOOL isFromIncomingInvitation;
@property (nonatomic, assign) DSUTXO lockedOutpoint;
@property (nonatomic, assign) uint32_t index;
@property (nonatomic, assign) DSIdentityRegistrationStatus registrationStatus;
@property (nonatomic, assign) uint64_t creditBalance;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDictionary *> *keyInfoDictionaries;
@property (nonatomic, strong) DSDashpayUserEntity *matchingDashpayUserInViewContext;
@property (nonatomic, strong) DSDashpayUserEntity *matchingDashpayUserInPlatformContext;
@property (nonatomic, assign) DMaybeOpaqueKey *internalRegistrationFundingPrivateKey;
@property (nonatomic, assign) DMaybeOpaqueKey *internalTopupFundingPrivateKey;
@property (nonatomic, assign) UInt256 dashpaySyncronizationBlockHash;
@property (nonatomic, strong) DSAssetLockTransaction *registrationAssetLockTransaction;
@property (nonatomic, assign) uint64_t lastCheckedUsernamesTimestamp;
@property (nonatomic, assign) uint64_t lastCheckedProfileTimestamp;

@end

@implementation DSIdentity

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [Identity: %@] ", self.chain.name, uint256_hex(self.uniqueID)];
}

- (void)dealloc {
    if (_internalRegistrationFundingPrivateKey != NULL)
        DMaybeOpaqueKeyDtor(_internalRegistrationFundingPrivateKey);
    if (_internalTopupFundingPrivateKey != NULL)
        DMaybeOpaqueKeyDtor(_internalTopupFundingPrivateKey);
}
// MARK: - Initialization

- (instancetype)initWithUniqueId:(UInt256)uniqueId
                     isTransient:(BOOL)isTransient
                         onChain:(DSChain *)chain {
    //this is the initialization of a non local blockchain identity
    if (!(self = [super init])) return nil;
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    _uniqueID = uniqueId;
    _isLocal = FALSE;
    _isTransient = isTransient;
    _keysCreated = 0;
    _currentMainKeyIndex = 0;
    _currentMainKeyType = DKeyKindECDSA();
    [self setupUsernames];
    self.keyInfoDictionaries = [NSMutableDictionary dictionary];
    _registrationStatus = DSIdentityRegistrationStatus_Registered;
    self.chain = chain;
    return self;
}

- (instancetype)initWithUniqueId:(UInt256)uniqueId isTransient:(BOOL)isTransient withCredits:(uint32_t)credits onChain:(DSChain *)chain {
    //this is the initialization of a non local blockchain identity
    if (!(self = [self initWithUniqueId:uniqueId isTransient:isTransient onChain:chain])) return nil;
    _creditBalance = credits;
    return self;
}

- (void)saveProfileTimestamp {
    [self.platformContext performBlockAndWait:^{
        self.lastCheckedProfileTimestamp = [NSDate timeIntervalSince1970];
        //[self saveInContext:self.platformContext];
    }];
}

- (void)registerKeyFromKeyPathEntity:(DSBlockchainIdentityKeyPathEntity *)entity {
    DKeyKind *keyType = dash_spv_crypto_keys_key_key_kind_from_index(entity.keyType);
    DMaybeOpaqueKey *key = dash_spv_crypto_keys_key_KeyKind_key_with_public_key_data(keyType, slice_ctor(entity.publicKeyData));
    [self registerKey:key withStatus:entity.keyStatus atIndex:entity.keyID ofType:keyType];

}
- (void)applyIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity {
    [self applyUsernameEntitiesFromIdentityEntity:identityEntity];
    _creditBalance = identityEntity.creditBalance;
    _registrationStatus = identityEntity.registrationStatus;
    _lastCheckedProfileTimestamp = identityEntity.lastCheckedProfileTimestamp;
    _lastCheckedUsernamesTimestamp = identityEntity.lastCheckedUsernamesTimestamp;
    _lastCheckedIncomingContactsTimestamp = identityEntity.lastCheckedIncomingContactsTimestamp;
    _lastCheckedOutgoingContactsTimestamp = identityEntity.lastCheckedOutgoingContactsTimestamp;
    
    self.dashpaySyncronizationBlockHash = identityEntity.dashpaySyncronizationBlockHash.UInt256;
    for (DSBlockchainIdentityKeyPathEntity *keyPathEntity in identityEntity.keyPaths) {
        NSIndexPath *keyIndexPath = (NSIndexPath *)[keyPathEntity path];
        
        DKeyKind *keyType = dash_spv_crypto_keys_key_key_kind_from_index(keyPathEntity.keyType);
        if (keyIndexPath) {
            BOOL success = [self registerKeyWithStatus:keyPathEntity.keyStatus atIndexPath:[keyIndexPath softenAllItems] ofType:keyType];
            if (!success)
                [self registerKeyFromKeyPathEntity:keyPathEntity];
        } else {
            [self registerKeyFromKeyPathEntity:keyPathEntity];
        }
    }
    if (self.isLocal || self.isOutgoingInvitation) {
        if (identityEntity.registrationFundingTransaction) {
            self.registrationAssetLockTransactionHash = identityEntity.registrationFundingTransaction.transactionHash.txHash.UInt256;
            DSLog(@"%@: AssetLockTX: Entity Attached: txHash: %@: entity: %@", self.logPrefix, uint256_hex(self.registrationAssetLockTransactionHash), identityEntity.registrationFundingTransaction);
        } else {
            NSData *transactionHashData = uint256_data(uint256_reverse(self.lockedOutpoint.hash));
            DSLog(@"%@: AssetLockTX: Load: lockedOutpoint: %@: %lu %@", self.logPrefix, uint256_hex(self.lockedOutpoint.hash), self.lockedOutpoint.n, transactionHashData.hexString);
            DSAssetLockTransactionEntity *assetLockEntity = [DSAssetLockTransactionEntity anyObjectInContext:identityEntity.managedObjectContext matching:@"transactionHash.txHash == %@", transactionHashData];
            if (assetLockEntity) {
                self.registrationAssetLockTransactionHash = assetLockEntity.transactionHash.txHash.UInt256;
                DSLog(@"%@: AssetLockTX: Found: txHash: %@: entity: %@", self.logPrefix, uint256_hex(self.registrationAssetLockTransactionHash), assetLockEntity);

                DSAssetLockTransaction *registrationAssetLockTransaction = (DSAssetLockTransaction *)[assetLockEntity transactionForChain:self.chain];
                BOOL correctIndex = self.isOutgoingInvitation ?
                    [registrationAssetLockTransaction checkInvitationDerivationPathIndexForWallet:self.wallet isIndex:self.index] :
                    [registrationAssetLockTransaction checkDerivationPathIndexForWallet:self.wallet isIndex:self.index];
                if (!correctIndex) {
                    DSLog(@"%@: AssetLockTX: IncorrectIndex %u (%@)", self.logPrefix, self.index, registrationAssetLockTransaction.toData.hexString);
                    //NSAssert(FALSE, @"We should implement this");
                }
            }
        }
    }
}

- (instancetype)initWithIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initWithUniqueId:entity.uniqueID.UInt256 isTransient:FALSE onChain:entity.chain.chain])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initAtIndex:index withLockedOutpoint:lockedOutpoint inWallet:wallet])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
               withUniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initAtIndex:index withUniqueId:uniqueId inWallet:wallet])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity
     associatedToInvitation:(DSInvitation *)invitation {
    if (!(self = [self initAtIndex:index withLockedOutpoint:lockedOutpoint inWallet:wallet])) return nil;
    [self setAssociatedInvitation:invitation];
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
                   inWallet:(DSWallet *)wallet {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isLocal = YES;
    self.isOutgoingInvitation = NO;
    self.isTransient = FALSE;
    _keysCreated = 0;
    self.currentMainKeyIndex = 0;
    self.currentMainKeyType = DKeyKindECDSA();
    self.index = index;
    self.keyInfoDictionaries = [NSMutableDictionary dictionary];
    self.registrationStatus = DSIdentityRegistrationStatus_Unknown;
    [self setupUsernames];
    self.chain = wallet.chain;
    return self;
}

- (void)setAssociatedInvitation:(DSInvitation *)associatedInvitation {
    _associatedInvitation = associatedInvitation;
    // It was created locally, we are sending the invite
    if (associatedInvitation.createdLocally) {
        self.isOutgoingInvitation = TRUE;
        self.isFromIncomingInvitation = FALSE;
        self.isLocal = FALSE;
    } else {
        // It was created on another device, we are receiving the invite
        self.isOutgoingInvitation = FALSE;
        self.isFromIncomingInvitation = TRUE;
        self.isLocal = TRUE;
    }
}

- (instancetype)initAtIndex:(uint32_t)index
               withUniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet {
    if (!(self = [self initAtIndex:index inWallet:wallet])) return nil;
    self.uniqueID = uniqueId;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet {
    if (!(self = [self initAtIndex:index inWallet:wallet])) return nil;
    NSAssert(dsutxo_hash_is_not_zero(lockedOutpoint), @"utxo must not be nil");

    self.lockedOutpoint = lockedOutpoint;
    self.uniqueID = [dsutxo_data(lockedOutpoint) SHA256_2];
    DSLog(@"%@: initAtIndex: %u lockedOutpoint: %@: %lu", self.logPrefix, index, uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
                   inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [self initAtIndex:index withLockedOutpoint:transaction.lockedOutpoint inWallet:wallet])) return nil;
    self.registrationAssetLockTransaction = transaction;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
     withUsernameDictionary:(NSDictionary<NSString *, NSDictionary *> *)usernameDictionary
                   inWallet:(DSWallet *)wallet {
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [self initAtIndex:index withAssetLockTransaction:transaction inWallet:wallet])) return nil;
    if (usernameDictionary) {
        NSMutableDictionary *usernameSalts = [NSMutableDictionary dictionary];
        for (NSString *username in usernameDictionary) {
            NSDictionary *subDictionary = usernameDictionary[username];
            NSData *salt = subDictionary[BLOCKCHAIN_USERNAME_SALT];
            if (salt)
                usernameSalts[username] = salt;
        }
        [self setupUsernames:[usernameDictionary mutableCopy] salts:usernameSalts];
    }
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
                   uniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isLocal = YES;
    self.isOutgoingInvitation = NO;
    self.isTransient = FALSE;
    _keysCreated = 0;
    self.currentMainKeyIndex = 0;
    self.currentMainKeyType = DKeyKindECDSA();
    self.uniqueID = uniqueId;
    self.keyInfoDictionaries = [NSMutableDictionary dictionary];
    self.registrationStatus = DSIdentityRegistrationStatus_Registered;
    [self setupUsernames];
    self.chain = wallet.chain;
    self.index = index;
    return self;
}

- (dispatch_queue_t)identityQueue {
    if (_identityQueue) return _identityQueue;
    _identityQueue = self.chain.chainManager.identitiesManager.identityQueue;
    return _identityQueue;
}

// MARK: - Full Registration agglomerate

- (DSIdentityRegistrationStep)stepsCompleted {
    DSIdentityRegistrationStep stepsCompleted = DSIdentityRegistrationStep_None;
    if (self.isRegistered) {
        stepsCompleted = DSIdentityRegistrationStep_RegistrationSteps;
        if ([self usernameFullPathsWithStatus:DSIdentityUsernameStatus_Confirmed].count)
            stepsCompleted |= DSIdentityRegistrationStep_Username;
    } else if (self.registrationAssetLockTransaction) {
        stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionCreation;
        DSAccount *account = [self.chain firstAccountThatCanContainTransaction:self.registrationAssetLockTransaction];
        if (self.registrationAssetLockTransaction.blockHeight != TX_UNCONFIRMED || [account transactionIsVerified:self.registrationAssetLockTransaction])
            stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionAccepted;
        if ([self isRegisteredInWallet])
            stepsCompleted |= DSIdentityRegistrationStep_LocalInWalletPersistence;
        if (self.registrationAssetLockTransaction.instantSendLockAwaitingProcessing)
            stepsCompleted |= DSIdentityRegistrationStep_ProofAvailable;
    }
    return stepsCompleted;
}

- (void)continueRegisteringProfileOnNetwork:(DSIdentityRegistrationStep)steps
                             stepsCompleted:(DSIdentityRegistrationStep)stepsAlreadyCompleted
                             stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                                 completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion {
    __block DSIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    if (!(steps & DSIdentityRegistrationStep_Profile)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    //todo:we need to still do profile
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
}

- (void)continueRegisteringUsernamesOnNetwork:(DSIdentityRegistrationStep)steps
                               stepsCompleted:(DSIdentityRegistrationStep)stepsAlreadyCompleted
                               stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                                   completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion {
    __block DSIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    
    if (!(steps & DSIdentityRegistrationStep_Username)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    [self registerUsernamesWithCompletion:^(BOOL success, NSError *_Nonnull error) {
        if (!success) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, error); });
            return;
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_Username); });
        stepsCompleted |= DSIdentityRegistrationStep_Username;
        [self continueRegisteringProfileOnNetwork:steps
                                   stepsCompleted:stepsCompleted
                                   stepCompletion:stepCompletion
                                       completion:completion];
    }];
}

- (void)continueRegisteringIdentityOnNetwork:(DSIdentityRegistrationStep)steps
                              stepsCompleted:(DSIdentityRegistrationStep)stepsAlreadyCompleted
                              stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                                  completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion {
    __block DSIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    if (!(steps & DSIdentityRegistrationStep_Identity)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    [self createAndPublishRegistrationTransitionWithCompletion:^(BOOL success, NSError *_Nullable error) {
        if (error) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, error); });
            return;
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_Identity); });
        stepsCompleted |= DSIdentityRegistrationStep_Identity;
        [self continueRegisteringUsernamesOnNetwork:steps
                                     stepsCompleted:stepsCompleted
                                     stepCompletion:stepCompletion
                                         completion:completion];
    }];
}

- (void)continueRegisteringOnNetwork:(DSIdentityRegistrationStep)steps
                  withFundingAccount:(DSAccount *)fundingAccount
                      forTopupAmount:(uint64_t)topupDuffAmount
                           pinPrompt:(NSString *)prompt
                      stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                          completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion {
    [self continueRegisteringOnNetwork:steps
                    withFundingAccount:fundingAccount
                        forTopupAmount:topupDuffAmount
                             pinPrompt:prompt
                             inContext:self.platformContext
                        stepCompletion:stepCompletion
                            completion:completion];
}

- (void)continueRegisteringOnNetwork:(DSIdentityRegistrationStep)steps
                  withFundingAccount:(DSAccount *)fundingAccount
                      forTopupAmount:(uint64_t)topupDuffAmount
                           pinPrompt:(NSString *)prompt
                           inContext:(NSManagedObjectContext *)context
                      stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                          completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion {
    if (!self.registrationAssetLockTransaction) {
        [self registerOnNetwork:steps
             withFundingAccount:fundingAccount
                 forTopupAmount:topupDuffAmount
                      pinPrompt:prompt
                 stepCompletion:stepCompletion
                     completion:completion];
    } else if (self.registrationStatus != DSIdentityRegistrationStatus_Registered) {
        [self continueRegisteringIdentityOnNetwork:steps
                                    stepsCompleted:DSIdentityRegistrationStep_L1Steps
                                    stepCompletion:stepCompletion
                                        completion:completion];
    } else if ([self.unregisteredUsernameFullPaths count]) {
        [self continueRegisteringUsernamesOnNetwork:steps
                                     stepsCompleted:DSIdentityRegistrationStep_L1Steps | DSIdentityRegistrationStep_Identity
                                     stepCompletion:stepCompletion
                                         completion:completion];
    } else if ([self matchingDashpayUserInContext:context].remoteProfileDocumentRevision < 1) {
        [self continueRegisteringProfileOnNetwork:steps
                                   stepsCompleted:DSIdentityRegistrationStep_L1Steps | DSIdentityRegistrationStep_Identity
                                   stepCompletion:stepCompletion
                                       completion:completion];
    }
}

- (void)submitAssetLockTransactionAndWaitForInstantSendLock:(DSAssetLockTransaction *)assetLockTransaction
                                         withFundingAccount:(DSAccount *)fundingAccount
                                                registrator:(BOOL (^_Nullable)(DSAssetLockTransaction *assetLockTransaction))registrator
                                                  pinPrompt:(NSString *)prompt
                                       completion:(void (^_Nullable)(BOOL success, BOOL cancelled, NSError *error))completion {
    [fundingAccount signTransaction:assetLockTransaction
                         withPrompt:prompt
                         completion:^(BOOL signedTransaction, BOOL cancelled) {
        if (!signedTransaction) {
            if (completion)
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, cancelled, cancelled ? nil : ERROR_FUNDING_TX_SIGNING);
                });
            return;
        }
        BOOL canContinue = registrator(assetLockTransaction);
        if (!canContinue)
            return;

    }];
}

- (void)publishTransactionAndWait:(DSAssetLockTransaction *)transaction
                       completion:(void (^_Nullable)(BOOL published, DSInstantSendTransactionLock *_Nullable instantSendLock, NSError *_Nullable error))completion {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL transactionSuccessfullyPublished = FALSE;
    __block DSInstantSendTransactionLock *instantSendLock = nil;
    __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                            object:nil
                                                                             queue:nil
                                                                        usingBlock:^(NSNotification *note) {
        DSTransaction *tx = [note.userInfo objectForKey:DSTransactionManagerNotificationTransactionKey];
        if ([tx isEqual:transaction]) {
            NSDictionary *changes = [note.userInfo objectForKey:DSTransactionManagerNotificationTransactionChangesKey];
            if (changes) {
                NSNumber *accepted = changes[DSTransactionManagerNotificationTransactionAcceptedStatusKey];
                NSNumber *lockVerified = changes[DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey];
                DSInstantSendTransactionLock *lock = changes[DSTransactionManagerNotificationInstantSendTransactionLockKey];
                if ([lockVerified boolValue] && lock != nil) {
                    instantSendLock = lock;
                    transactionSuccessfullyPublished = TRUE;
                    dispatch_semaphore_signal(sem);
                } else if ([accepted boolValue]) {
                    transactionSuccessfullyPublished = TRUE;
                }
            }
        }
    }];
    [self.chain.chainManager.transactionManager publishTransaction:transaction completion:^(NSError *_Nullable error) {
        if (error) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
            completion(NO, nil, error);
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_SEC));
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
            completion(transactionSuccessfullyPublished, instantSendLock, nil);
        });
    }];

}

- (void)registerOnNetwork:(DSIdentityRegistrationStep)steps
       withFundingAccount:(DSAccount *)fundingAccount
           forTopupAmount:(uint64_t)topupDuffAmount
                pinPrompt:(NSString *)prompt
           stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
               completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion {
    DSLog(@"%@: registerOnNetwork: %@", self.logPrefix, DSRegistrationStepsDescription(steps));
    __block DSIdentityRegistrationStep stepsCompleted = DSIdentityRegistrationStep_None;
    if (![self hasIdentityExtendedPublicKeys]) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, ERROR_REGISTER_KEYS_BEFORE_IDENTITY); });
        return;
    }
    if (!(steps & DSIdentityRegistrationStep_FundingTransactionCreation)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    NSString *assetLockRegistrationAddress = [self registrationFundingAddress];
    
    
    
    DSAssetLockTransaction *assetLockTransaction = [fundingAccount assetLockTransactionFor:topupDuffAmount
                                                                                        to:assetLockRegistrationAddress
                                                                                   withFee:YES];
    if (!assetLockTransaction) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, ERROR_FUNDING_TX_CREATION); });
        return;
    }
    [fundingAccount signTransaction:assetLockTransaction
                         withPrompt:prompt
                         completion:^(BOOL signedTransaction, BOOL cancelled) {
        if (!signedTransaction) {
            if (completion)
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (cancelled) stepsCompleted |= DSIdentityRegistrationStep_Cancelled;
                    completion(stepsCompleted, cancelled ? nil : ERROR_FUNDING_TX_SIGNING);
                });
            return;
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_FundingTransactionCreation); });
        stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionCreation;
        
        //In wallet registration occurs now
        
        if (!(steps & DSIdentityRegistrationStep_LocalInWalletPersistence)) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
            return;
        }
        if (self.isOutgoingInvitation) {
            [self.associatedInvitation registerInWalletForAssetLockTransaction:assetLockTransaction];
        } else {
            [self registerInWalletForAssetLockTransaction:assetLockTransaction];
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_LocalInWalletPersistence); });
        stepsCompleted |= DSIdentityRegistrationStep_LocalInWalletPersistence;
        if (!(steps & DSIdentityRegistrationStep_FundingTransactionAccepted)) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
            return;
        }

        [self publishTransactionAndWait:assetLockTransaction completion:^(BOOL published, DSInstantSendTransactionLock *_Nullable instantSendLock, NSError *_Nullable error) {
            if (!published) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, ERROR_FUNDING_TX_TIMEOUT); });
                return;
            }
            if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_FundingTransactionAccepted); });
            stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionAccepted;
            if (!instantSendLock) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, ERROR_FUNDING_TX_ISD_TIMEOUT); });
                return;
            }
            if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_ProofAvailable); });
            stepsCompleted |= DSIdentityRegistrationStep_ProofAvailable;
            [self continueRegisteringIdentityOnNetwork:steps
                                        stepsCompleted:stepsCompleted
                                        stepCompletion:stepCompletion
                                            completion:completion];

        }];
    }];
}

// MARK: - Local Registration and Generation

- (BOOL)hasIdentityExtendedPublicKeys {
    NSAssert(_isLocal || _isOutgoingInvitation, @"This should not be performed on a non local identity (but can be done for an invitation)");
    if (!_isLocal && !_isOutgoingInvitation) return FALSE;
    if (_isLocal) {
        DSAuthenticationKeysDerivationPath *derivationPathBLS = [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:self.wallet];
        DSAuthenticationKeysDerivationPath *derivationPathECDSA = [[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:self.wallet];
        DSAssetLockDerivationPath *derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:self.wallet];
        DSAssetLockDerivationPath *derivationPathTopupFunding = [[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:self.wallet];
        return [derivationPathBLS hasExtendedPublicKey]
            && [derivationPathECDSA hasExtendedPublicKey]
            && [derivationPathRegistrationFunding hasExtendedPublicKey]
            && [derivationPathTopupFunding hasExtendedPublicKey];
    }
    if (_isOutgoingInvitation) {
        DSAssetLockDerivationPath *derivationPathInvitationFunding = [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet];
        return [derivationPathInvitationFunding hasExtendedPublicKey];
    }
    return NO;
}

- (void)generateIdentityExtendedPublicKeysWithPrompt:(NSString *)prompt
                                          completion:(void (^_Nullable)(BOOL registered))completion {
    NSAssert(_isLocal || _isOutgoingInvitation, @"This should not be performed on a non local identity (but can be done for an invitation)");
    if (!_isLocal && !_isOutgoingInvitation) return;
    if ([self hasIdentityExtendedPublicKeys]) {
        if (completion) completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt
                                                   forWallet:self.wallet
                                                   forAmount:0
                                         forceAuthentication:NO
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
        if (!seed) {
            if (completion) completion(NO);
            return;
        }
        if (self->_isLocal) {
            DSAuthenticationKeysDerivationPath *derivationPathBLS = [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:self.wallet];
            DSAuthenticationKeysDerivationPath *derivationPathECDSA = [[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:self.wallet];
            
            [derivationPathBLS generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
            [derivationPathECDSA generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
            if (!self->_isFromIncomingInvitation) {
                DSAssetLockDerivationPath *derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:self.wallet];
                DSAssetLockDerivationPath *derivationPathTopupFunding = [[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:self.wallet];
                [derivationPathRegistrationFunding generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
                [derivationPathTopupFunding generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
            }
        }
        if (self->_isOutgoingInvitation) {
            DSAssetLockDerivationPath *derivationPathInvitationFunding = [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet];
            [derivationPathInvitationFunding generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
        }
        if (completion) completion(YES);
    }];
}

- (void)registerInWalletForAssetLockTransaction:(DSAssetLockTransaction *)transaction {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    self.registrationAssetLockTransactionHash = transaction.txHash;
    DSUTXO lockedOutpoint = transaction.lockedOutpoint;
    UInt256 creditBurnIdentityIdentifier = transaction.creditBurnIdentityIdentifier;
    DSLog(@"%@: registerInWalletForAssetLockTransaction: txHash: %@: creditBurnIdentityID: %@, creditBurnPublicKeyHash: %@, lockedOutpoint: %@: %lu", self.logPrefix, uint256_hex(transaction.txHash), uint256_hex(creditBurnIdentityIdentifier), uint160_hex(transaction.creditBurnPublicKeyHash), uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
    self.lockedOutpoint = lockedOutpoint;
    [self registerInWalletForIdentityUniqueId:creditBurnIdentityIdentifier];
    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [transaction markAddressAsUsedInWallet:self.wallet];
}

- (void)registerInWalletForAssetLockTopupTransaction:(DSAssetLockTransaction *)transaction {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    [self.topupAssetLockTransactionHashes addObject:uint256_data(transaction.txHash)];

    DSUTXO lockedOutpoint = transaction.lockedOutpoint;
    UInt256 creditBurnIdentityIdentifier = transaction.creditBurnIdentityIdentifier;
    DSLog(@"%@: registerInWalletForAssetLockTopupTransaction: txHash: %@: creditBurnIdentityID: %@, creditBurnPublicKeyHash: %@, lockedOutpoint: %@: %lu", self.logPrefix, uint256_hex(transaction.txHash), uint256_hex(creditBurnIdentityIdentifier), uint160_hex(transaction.creditBurnPublicKeyHash), uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
//    self.lockedOutpoint = lockedOutpoint;
    [self registerInWalletForIdentityUniqueId:creditBurnIdentityIdentifier];
    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [transaction markAddressAsUsedInWallet:self.wallet];
}

- (void)registerInWalletForIdentityUniqueId:(UInt256)identityUniqueId {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    self.uniqueID = identityUniqueId;
    [self registerInWallet];
}

- (BOOL)isRegisteredInWallet {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return FALSE;
    if (!self.wallet) return FALSE;
    return [self.wallet containsIdentity:self];
}

- (void)registerInWallet {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    [self.wallet registerIdentity:self];
    [self saveInitial];
}

- (BOOL)unregisterLocally {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return FALSE;
    if (self.isRegistered) return FALSE; //if it is already registered we can not unregister it from the wallet
    [self.wallet unregisterIdentity:self];
    [self deletePersistentObjectAndSave:YES inContext:self.platformContext];
    return TRUE;
}

- (void)setInvitationUniqueId:(UInt256)uniqueId {
    NSAssert(_isOutgoingInvitation, @"This can only be done on an invitation");
    if (!_isOutgoingInvitation) return;
    self.uniqueID = uniqueId;
}

- (void)setInvitationAssetLockTransaction:(DSAssetLockTransaction *)transaction {
    NSParameterAssert(transaction);
    NSAssert(_isOutgoingInvitation, @"This can only be done on an invitation");
    if (!_isOutgoingInvitation) return;
    self.registrationAssetLockTransaction = transaction;
    self.lockedOutpoint = transaction.lockedOutpoint;

}

// MARK: - Read Only Property Helpers

- (BOOL)isActive {
    if (self.isLocal) {
        if (!self.wallet) return NO;
        return self.wallet.identities[self.uniqueIDData] != nil;
    } else {
        return [self.chain.chainManager.identitiesManager foreignIdentityWithUniqueId:self.uniqueID] != nil;
    }
}

- (DSAssetLockTransaction *)registrationAssetLockTransaction {
    if (!_registrationAssetLockTransaction) {
        _registrationAssetLockTransaction = (DSAssetLockTransaction *)[self.chain transactionForHash:self.registrationAssetLockTransactionHash];
    }
    return _registrationAssetLockTransaction;
}

- (NSData *)uniqueIDData {
    return uint256_data(self.uniqueID);
}

- (NSData *)lockedOutpointData {
    return dsutxo_data(self.lockedOutpoint);
}

- (NSString *)currentDashpayUsername {
    return [self.dashpayUsernames firstObject];
}

- (NSArray<DSDerivationPath *> *)derivationPaths {
    if (!_isLocal) return nil;
    return [[DSDerivationPathFactory sharedInstance] unloadedSpecializedDerivationPathsForWallet:self.wallet];
}

- (NSString *)uniqueIdString {
    return [uint256_data(self.uniqueID) base58String];
}

- (dispatch_queue_t)networkingQueue {
    return self.chain.networkingQueue;
}

- (NSManagedObjectContext *)platformContext {
    //    NSAssert(![NSThread isMainThread], @"We should not be on main thread");
    return [NSManagedObjectContext platformContext];
}

- (DSIdentitiesManager *)identitiesManager {
    return self.chain.chainManager.identitiesManager;
}

// ECDSA
- (DMaybeOpaqueKey *)registrationFundingPrivateKey {
    return self.internalRegistrationFundingPrivateKey;
}
- (DMaybeOpaqueKey *)topupFundingPrivateKey {
    return self.internalTopupFundingPrivateKey;
}

- (void)setDashpaySyncronizationBlockHash:(UInt256)dashpaySyncronizationBlockHash {
    _dashpaySyncronizationBlockHash = dashpaySyncronizationBlockHash;
    if (uint256_is_zero(_dashpaySyncronizationBlockHash)) {
        _dashpaySyncronizationBlockHeight = 0;
    } else {
        _dashpaySyncronizationBlockHeight = [self.chain heightForBlockHash:_dashpaySyncronizationBlockHash];
        if (_dashpaySyncronizationBlockHeight == UINT32_MAX) {
            _dashpaySyncronizationBlockHeight = 0;
        }
    }
}


// MARK: - Keys

- (BOOL)createFundingPrivateKeyWithSeed:(NSData *)seed
                        isForInvitation:(BOOL)isForInvitation {
    DSAssetLockDerivationPath *path = isForInvitation ?
        [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet] :
        [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:self.wallet];
    self.internalRegistrationFundingPrivateKey = [path privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];
    BOOL ok = self.internalRegistrationFundingPrivateKey;
    return ok;
}
- (BOOL)createTopupFundingPrivateKeyWithSeed:(NSData *)seed {
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:self.wallet];
    self.internalTopupFundingPrivateKey = [path privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];
    BOOL ok = self.internalTopupFundingPrivateKey;
    return ok;
}

- (BOOL)setExternalFundingPrivateKey:(DMaybeOpaqueKey *)privateKey {
    if (!self.isFromIncomingInvitation) return FALSE;
    self.internalRegistrationFundingPrivateKey = privateKey;
    return self.internalRegistrationFundingPrivateKey;
}

- (void)createFundingPrivateKeyForInvitationWithPrompt:(NSString *)prompt
                                            completion:(void (^_Nullable)(BOOL success, BOOL cancelled))completion {
    [self createFundingPrivateKeyWithPrompt:prompt
                            isForInvitation:YES
                                 completion:completion];
}

- (void)createFundingPrivateKeyWithPrompt:(NSString *)prompt
                               completion:(void (^_Nullable)(BOOL success, BOOL cancelled))completion {
    [self createFundingPrivateKeyWithPrompt:prompt
                            isForInvitation:NO
                                 completion:completion];
}

- (void)createFundingPrivateKeyWithPrompt:(NSString *)prompt
                          isForInvitation:(BOOL)isForInvitation
                               completion:(void (^_Nullable)(BOOL success, BOOL cancelled))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt
                                                       forWallet:self.wallet
                                                       forAmount:0
                                             forceAuthentication:NO
                                                      completion:^(NSData *_Nullable seed, BOOL cancelled) {
            if (!seed) {
                if (completion) completion(NO, cancelled);
                return;
            }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                BOOL success = [self createFundingPrivateKeyWithSeed:seed isForInvitation:isForInvitation];
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(success, NO); });
            });
        }];
    });
}

- (BOOL)activePrivateKeysAreLoadedWithFetchingError:(NSError **)error {
    BOOL loaded = TRUE;
    for (NSNumber *index in self.keyInfoDictionaries) {
        NSDictionary *keyDictionary = self.keyInfoDictionaries[index];
        DSIdentityKeyStatus status = [keyDictionary[@(DSIdentityKeyDictionary_KeyStatus)] unsignedIntValue];
        DKeyKind *keyType = [keyDictionary[@(DSIdentityKeyDictionary_KeyType)] pointerValue];
        if (status == DSIdentityKeyStatus_Registered) {
            loaded &= [self hasPrivateKeyAtIndex:[index unsignedIntValue] ofType:keyType error:error];
            if (*error) return FALSE;
        }
    }
    return loaded;
}

- (uint32_t)activeKeyCount {
    uint32_t rActiveKeys = 0;
    for (NSNumber *index in self.keyInfoDictionaries) {
        NSDictionary *keyDictionary = self.keyInfoDictionaries[index];
        DSIdentityKeyStatus status = [keyDictionary[@(DSIdentityKeyDictionary_KeyStatus)] unsignedIntValue];
        if (status == DSIdentityKeyStatus_Registered) rActiveKeys++;
    }
    return rActiveKeys;
}

- (uint32_t)totalKeyCount {
    return (uint32_t)self.keyInfoDictionaries.count;
}

- (NSArray *)activeKeysForKeyType:(DKeyKind *)keyType {
    NSMutableArray *activeKeys = [NSMutableArray array];
    for (NSNumber *index in self.keyInfoDictionaries) {
        NSDictionary *keyDictionary = self.keyInfoDictionaries[index];
        if (dash_spv_crypto_keys_key_KeyKind_equal_to_kind(keyType, [keyDictionary[@(DSIdentityKeyDictionary_KeyType)] pointerValue]))
            [activeKeys addObject:keyDictionary[@(DSIdentityKeyDictionary_Key)]];
    }
    return [activeKeys copy];
}

- (BOOL)verifyKeysForWallet:(DSWallet *)wallet {
    DSWallet *originalWallet = self.wallet;
    self.wallet = wallet;
    for (uint32_t index = 0; index < self.keyInfoDictionaries.count; index++) {
        DKeyKind *keyType = [[[self.keyInfoDictionaries objectForKey:@(index)] objectForKey:@(DSIdentityKeyDictionary_KeyType)] pointerValue];
        DMaybeOpaqueKey *key = [self keyAtIndex:index];
        if (!key || !key->ok) {
            self.wallet = originalWallet;
            return FALSE;
        }
        BOOL hasSameKind = dash_spv_crypto_keys_key_OpaqueKey_has_kind(key->ok, keyType);
        if (!hasSameKind) {
            self.wallet = originalWallet;
            return FALSE;
        }
        DMaybeOpaqueKey *derivedKey = [self publicKeyAtIndex:index ofType:keyType];
        if (!derivedKey || !derivedKey->ok) return NO;
        BOOL isEqual = [DSKeyManager keysPublicKeyDataIsEqual:derivedKey->ok key2:key->ok];
        DMaybeOpaqueKeyDtor(derivedKey);
        if (!isEqual) {
            self.wallet = originalWallet;
            return FALSE;
        }
    }
    return TRUE;
}

- (DSIdentityKeyStatus)statusOfKeyAtIndex:(NSUInteger)index {
    return [[[self.keyInfoDictionaries objectForKey:@(index)] objectForKey:@(DSIdentityKeyDictionary_KeyStatus)] unsignedIntValue];
}

- (DMaybeOpaqueKey *_Nullable)keyAtIndex:(NSUInteger)index {
    NSValue *keyValue = (NSValue *)[[self.keyInfoDictionaries objectForKey:@(index)] objectForKey:@(DSIdentityKeyDictionary_Key)];
    return keyValue.pointerValue;
}

- (NSString *)localizedStatusOfKeyAtIndex:(NSUInteger)index {
    return [[self class] localizedStatusOfKeyForIdentityKeyStatus:[self statusOfKeyAtIndex:index]];
}

+ (NSString *)localizedStatusOfKeyForIdentityKeyStatus:(DSIdentityKeyStatus)status {
    switch (status) {
        case DSIdentityKeyStatus_Unknown:
            return DSLocalizedString(@"Unknown", @"Status of Key or Username is Unknown");
        case DSIdentityKeyStatus_Registered:
            return DSLocalizedString(@"Registered", @"Status of Key or Username is Registered");
        case DSIdentityKeyStatus_Registering:
            return DSLocalizedString(@"Registering", @"Status of Key or Username is Registering");
        case DSIdentityKeyStatus_NotRegistered:
            return DSLocalizedString(@"Not Registered", @"Status of Key or Username is Not Registered");
        case DSIdentityKeyStatus_Revoked:
            return DSLocalizedString(@"Revoked", @"Status of Key or Username is Revoked");
        default:
            return @"";
    }
}

+ (DSAuthenticationKeysDerivationPath *)derivationPathForType:(DKeyKind *)type forWallet:(DSWallet *)wallet {
//    uint16_t kind = &type;
    // TODO: ed25519 + bls basic
    int16_t index = dash_spv_crypto_keys_key_KeyKind_index(type);
    if (index == dash_spv_crypto_keys_key_KeyKind_ECDSA) {
        return [[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:wallet];
    } else if (index == dash_spv_crypto_keys_key_KeyKind_BLS || index == dash_spv_crypto_keys_key_KeyKind_BLSBasic) {
        return [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:wallet];
    }
    return nil;
}

- (DSAuthenticationKeysDerivationPath *)derivationPathForType:(DKeyKind *)type {
    return _isLocal ? [DSIdentity derivationPathForType:type forWallet:self.wallet] : nil;
}

- (BOOL)hasPrivateKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type error:(NSError **)error {
    if (!_isLocal) return NO;
    NSIndexPath *indexPath = [self indexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return hasKeychainData([self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath], error);
}

- (NSIndexPath *)indexPathForIndex:(uint32_t)index {
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    return indexPath;
}

- (DMaybeOpaqueKey *)privateKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type {
    if (!_isLocal) return nil;
    NSIndexPath *indexPath = [self indexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    NSError *error = nil;
    NSData *keySecret = getKeychainData([self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath], &error);
    NSAssert(keySecret, @"This should be present");
    if (!keySecret || error) return nil;
    return [DSKeyManager keyWithPrivateKeyData:keySecret ofType:type];
}

- (DMaybeOpaqueKey *)derivePrivateKeyAtIndexPath:(NSIndexPath *)indexPath ofType:(DKeyKind *)type {
    if (!_isLocal) return nil;
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath privateKeyAtIndexPath:[indexPath hardenAllItems]];
}

- (DMaybeOpaqueKey *)privateKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type forSeed:(NSData *)seed {
    if (!_isLocal) return nil;
    NSIndexPath *indexPath = [self indexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
}

- (DMaybeOpaqueKey *_Nullable)publicKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type {
    if (!_isLocal) return nil;
    NSIndexPath *hardenedIndexPath = [self indexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
}

- (DMaybeOpaqueKey *)createNewKeyOfType:(DKeyKind *)type
                                saveKey:(BOOL)saveKey
                            returnIndex:(uint32_t *)rIndex {
    if (!_isLocal) return nil;
    uint32_t keyIndex = self.keysCreated;
    NSIndexPath *hardenedIndexPath = [self indexPathForIndex:keyIndex];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    DMaybeOpaqueKey *publicKey = [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
    NSAssert([derivationPath hasExtendedPrivateKey], @"The derivation path should have an extended private key");
    DMaybeOpaqueKey *privateKey = [derivationPath privateKeyAtIndexPath:hardenedIndexPath];
    NSAssert(privateKey && privateKey->ok, @"The private key should have been derived");
    NSAssert([DSKeyManager keysPublicKeyDataIsEqual:publicKey->ok key2:privateKey->ok], @"These should be equal");
    _keysCreated++;
    if (rIndex)
        *rIndex = keyIndex;
    [self addKeyInfo:publicKey type:type status:DSIdentityKeyStatus_Registering index:keyIndex];
    if (saveKey)
        [self saveNewKey:publicKey
                  atPath:hardenedIndexPath
              withStatus:DSIdentityKeyStatus_Registering
      fromDerivationPath:derivationPath
               inContext:[NSManagedObjectContext viewContext]];
    return publicKey;
}


- (uint32_t)firstIndexOfKeyOfType:(DKeyKind *)type
               createIfNotPresent:(BOOL)createIfNotPresent
                          saveKey:(BOOL)saveKey {
    for (NSNumber *indexNumber in self.keyInfoDictionaries) {
        NSDictionary *keyDictionary = self.keyInfoDictionaries[indexNumber];
        DKeyKind *keyType = [keyDictionary[@(DSIdentityKeyDictionary_KeyType)] pointerValue];
        if (dash_spv_crypto_keys_key_KeyKind_index(keyType) == dash_spv_crypto_keys_key_KeyKind_index(type))
            return [indexNumber unsignedIntValue];
    }
    if (_isLocal && createIfNotPresent) {
        uint32_t rIndex;
        [self createNewKeyOfType:type saveKey:saveKey returnIndex:&rIndex];
        return rIndex;
    } else {
        return UINT32_MAX;
    }
}

- (DMaybeOpaqueKey *)keyOfType:(DKeyKind *)type
                       atIndex:(uint32_t)index {
    if (!_isLocal) return nil;
    NSIndexPath *hardenedIndexPath = [self indexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
}

//- (void)addKey:(DMaybeOpaqueKey *)key
//       atIndex:(uint32_t)index
//        ofType:(DKeyKind *)type
//    withStatus:(DSIdentityKeyStatus)status
//          save:(BOOL)save {
//    [self addKey:key
//         atIndex:index
//          ofType:type
//      withStatus:status
//            save:save
//       inContext:self.platformContext];
//}

- (void)addKey:(DMaybeOpaqueKey *)key
       atIndex:(uint32_t)index
        ofType:(DKeyKind *)type
    withStatus:(DSIdentityKeyStatus)status
          save:(BOOL)save
     inContext:(NSManagedObjectContext *)context {
    DSLogPrivate(@"Identity (local: %u) add key: %p at %u of %u with %lu", self.isLocal, key, index, dash_spv_crypto_keys_key_KeyKind_index(type), (unsigned long)status);
    if (self.isLocal) {
        [self addKey:key
         atIndexPath:[NSIndexPath indexPathWithIndexes:(const NSUInteger[]){_index, index} length:2]
              ofType:type
          withStatus:status
                save:save
           inContext:context];
    } else {
        if (self.keyInfoDictionaries[@(index)]) {
            NSDictionary *keyDictionary = self.keyInfoDictionaries[@(index)];
            NSValue *keyToCheckInDictionary = keyDictionary[@(DSIdentityKeyDictionary_Key)];
            DMaybeOpaqueKey *maybe_opaque_key = keyToCheckInDictionary.pointerValue;
            DSIdentityKeyStatus keyToCheckInDictionaryStatus = [keyDictionary[@(DSIdentityKeyDictionary_KeyStatus)] unsignedIntegerValue];
            if (maybe_opaque_key->ok && [DSKeyManager keysPublicKeyDataIsEqual:maybe_opaque_key->ok key2:key->ok]) {
                if (save && status != keyToCheckInDictionaryStatus)
                    [self updateStatus:status forKeyWithIndexID:index inContext:context];
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSLog(@"these should really match up");
                return;
            }
        } else {
            _keysCreated = MAX(self.keysCreated, index + 1);
            if (save)
                [self saveNewRemoteIdentityKey:key forKeyWithIndexID:index withStatus:status inContext:context];
        }
        [self addKeyInfo:key type:type status:status index:index];
    }
}

- (void)addKey:(DMaybeOpaqueKey *)key
   atIndexPath:(NSIndexPath *)indexPath
        ofType:(DKeyKind *)type
    withStatus:(DSIdentityKeyStatus)status
          save:(BOOL)save {
    [self addKey:key atIndexPath:indexPath ofType:type withStatus:status save:save inContext:self.platformContext];
}

- (void)addKey:(DMaybeOpaqueKey *)key
   atIndexPath:(NSIndexPath *)indexPath
        ofType:(DKeyKind *)type
    withStatus:(DSIdentityKeyStatus)status
          save:(BOOL)save
     inContext:(NSManagedObjectContext *_Nullable)context {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal) return;
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    //derivationPath will be nil if not local
    
    DMaybeOpaqueKey *keyToCheck = [derivationPath publicKeyAtIndexPath:[indexPath hardenAllItems]];
    NSAssert(keyToCheck != nil && keyToCheck->ok, @"This key should be found");
    if ([DSKeyManager keysPublicKeyDataIsEqual:keyToCheck->ok key2:key->ok]) { //if it isn't local we shouldn't verify
        uint32_t index = (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1];
        if (self.keyInfoDictionaries[@(index)]) {
            NSDictionary *keyDictionary = self.keyInfoDictionaries[@(index)];
            NSValue *keyToCheckInDictionaryValue = keyDictionary[@(DSIdentityKeyDictionary_Key)];
            DMaybeOpaqueKey *maybe_opaque_key = keyToCheckInDictionaryValue.pointerValue;
            if (maybe_opaque_key->ok && [DSKeyManager keysPublicKeyDataIsEqual:maybe_opaque_key->ok key2:key->ok]) {
                if (save) {
                    [self updateStatus:status forKeyAtPath:indexPath fromDerivationPath:derivationPath inContext:context];
                }
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSLog(@"these should really match up");
                return;
            }
        } else {
            _keysCreated = MAX(self.keysCreated, index + 1);
            if (save)
                [self saveNewKey:key atPath:indexPath withStatus:status fromDerivationPath:derivationPath inContext:context];
        }
        [self addKeyInfo:key type:type status:status index:index];
    } else {
        DSLog(@"these should really match up");
    }
}

- (BOOL)registerKeyWithStatus:(DSIdentityKeyStatus)status
                  atIndexPath:(NSIndexPath *)indexPath
                       ofType:(DKeyKind *)type {
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    DMaybeOpaqueKey *key = [derivationPath publicKeyAtIndexPath:[indexPath hardenAllItems]];
    if (!key) return FALSE;
    uint32_t index = (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1];
    _keysCreated = MAX(self.keysCreated, index + 1);
    [self addKeyInfo:key type:type status:status index:index];
    return TRUE;
}

- (void)registerKey:(DMaybeOpaqueKey *)key
         withStatus:(DSIdentityKeyStatus)status
            atIndex:(uint32_t)index
             ofType:(DKeyKind *)type {
    _keysCreated = MAX(self.keysCreated, index + 1);
    [self addKeyInfo:key type:type status:status index:index];
}

- (void)addKeyInfo:(DMaybeOpaqueKey *)key
              type:(DKeyKind *)type
            status:(DSIdentityKeyStatus)status
             index:(uint32_t)index {
    DSLogPrivate(@"%@: addKeyInfo: %p %u %lu %u", self.logPrefix, key, dash_spv_crypto_keys_key_KeyKind_index(type), status, index);
    [self.keyInfoDictionaries setObject:@{
        @(DSIdentityKeyDictionary_Key): [NSValue valueWithPointer:key],
        @(DSIdentityKeyDictionary_KeyType): [NSValue valueWithPointer:type],
        @(DSIdentityKeyDictionary_KeyStatus): @(status)
    } forKey:@(index)];
}


// MARK: - Funding

- (NSString *)registrationFundingAddress {
    if (self.registrationAssetLockTransaction) {
        return [DSKeyManager addressFromHash160:self.registrationAssetLockTransaction.creditBurnPublicKeyHash forChain:self.chain];
    } else {
        DSAssetLockDerivationPath *derivationPathRegistrationFunding = self.isOutgoingInvitation
            ? [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet]
            : [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:self.wallet];
        return [derivationPathRegistrationFunding addressAtIndex:self.index];
    }
}


// MARK: Helpers

- (BOOL)isRegistered {
    return self.registrationStatus == DSIdentityRegistrationStatus_Registered;
}

- (NSString *)localizedRegistrationStatusString {
    switch (self.registrationStatus) {
        case DSIdentityRegistrationStatus_Registered:
            return DSLocalizedString(@"Registered", @"The Dash Identity is registered");
        case DSIdentityRegistrationStatus_Unknown:
            return DSLocalizedString(@"Unknown", @"It is Unknown if the Dash Identity is registered");
        case DSIdentityRegistrationStatus_Registering:
            return DSLocalizedString(@"Registering", @"The Dash Identity is being registered");
        case DSIdentityRegistrationStatus_NotRegistered:
            return DSLocalizedString(@"Not Registered", @"The Dash Identity is not registered");
        default:
            break;
    }
    return @"";
}

- (void)applyIdentity:(DIdentity *)identity
                 save:(BOOL)save
            inContext:(NSManagedObjectContext *_Nullable)context {
    switch (identity->tag) {
        case dpp_identity_identity_Identity_V0: {
            dpp_identity_v0_IdentityV0 *versioned = identity->v0;
            _creditBalance = versioned->balance;
            DIdentityPublicKeysMap *public_keys = versioned->public_keys;
            for (int k = 0; k < public_keys->count; k++) {
                DKeyID *key_id = public_keys->keys[k];
                DIdentityPublicKey *public_key = public_keys->values[k];
                DMaybeOpaqueKey *opaque = dash_spv_platform_identity_manager_opaque_key_from_identity_public_key(public_key);
                [self addKey:opaque
                     atIndex:key_id->_0
                      ofType:DKeyKindECDSA()
                  withStatus:DSIdentityKeyStatus_Registered
                        save:save
                   inContext:context];
            }
            break;
        }
            
        default:
            break;
    }
}

// MARK: Registering

/// instant lock verification will work for recently signed instant locks.
/// we expect clients to use ChainAssetLockProof.
- (DAssetLockProof *)createProof:(DSInstantSendTransactionLock *_Nullable)isLock {
    return isLock ? [self createInstantProof:isLock] : [self createChainProof];
}

- (DAssetLockProof *)createInstantProof:(DSInstantSendTransactionLock *)isLock {
    uint8_t version = isLock.version;
    NSArray<NSData *> *outpoints = isLock.inputOutpoints;
    Arr_u8_36 **values = malloc(sizeof(Arr_u8_36 *) * outpoints.count);
    for (int i = 0; i < outpoints.count; i++) {
        NSData *o = outpoints[i];
        values[i] = Arr_u8_36_ctor(o.length, (uint8_t *) o.bytes);
    }
    Vec_u8_36 *lock_inputs = Vec_u8_36_ctor(outpoints.count, values);
    u256 *txid = u256_ctor_u(isLock.transactionHash);
    u256 *cycle_hash = u256_ctor_u(isLock.cycleHash);
    u768 *signature = u768_ctor_u(isLock.signature);
    uint16_t tx_version = self.registrationAssetLockTransaction.version;
    uint32_t lock_time = self.registrationAssetLockTransaction.lockTime;
    NSArray *inputs = self.registrationAssetLockTransaction.inputs;
    NSUInteger inputsCount = inputs.count;
    dash_spv_crypto_tx_input_TransactionInput **tx_inputs = malloc(sizeof(dash_spv_crypto_tx_input_TransactionInput *) * inputsCount);
    for (int i = 0; i < inputs.count; i++) {
        DSTransactionInput *o = inputs[i];
        u256 *input_hash = u256_ctor_u(o.inputHash);
        BYTES *script = o.inScript ? bytes_ctor(o.inScript) : NULL;
        BYTES *signature = o.signature ? bytes_ctor(o.signature) : NULL;
        tx_inputs[i] = dash_spv_crypto_tx_input_TransactionInput_ctor(input_hash, o.index, script, signature, o.sequence);
    }
    
    NSArray *outputs = self.registrationAssetLockTransaction.outputs;
    NSUInteger outputsCount = outputs.count;
    dash_spv_crypto_tx_output_TransactionOutput **tx_outputs = malloc(sizeof(dash_spv_crypto_tx_output_TransactionOutput *) * outputsCount);
    for (int i = 0; i < outputs.count; i++) {
        DSTransactionOutput *o = outputs[i];
        tx_outputs[i] = dash_spv_crypto_tx_output_TransactionOutput_ctor(o.amount, o.outScript ? bytes_ctor(o.outScript) : NULL, NULL);
    }
    uint8_t asset_lock_payload_version = self.registrationAssetLockTransaction.specialTransactionVersion;
    
    NSArray *creditOutputs = self.registrationAssetLockTransaction.creditOutputs;
    NSUInteger creditOutputsCount = creditOutputs.count;
    dash_spv_crypto_tx_output_TransactionOutput **credit_outputs = malloc(sizeof(dash_spv_crypto_tx_output_TransactionOutput *) * creditOutputsCount);
    for (int i = 0; i < creditOutputsCount; i++) {
        DSTransactionOutput *o = creditOutputs[i];
        credit_outputs[i] = dash_spv_crypto_tx_output_TransactionOutput_ctor(o.amount, o.outScript ? bytes_ctor(o.outScript) : NULL, NULL);
    }

    Vec_dash_spv_crypto_tx_input_TransactionInput *input_vec = Vec_dash_spv_crypto_tx_input_TransactionInput_ctor(inputsCount, tx_inputs);
    Vec_dash_spv_crypto_tx_output_TransactionOutput *output_vec = Vec_dash_spv_crypto_tx_output_TransactionOutput_ctor(outputsCount, tx_outputs);
    Vec_dash_spv_crypto_tx_output_TransactionOutput *credit_output_vec = Vec_dash_spv_crypto_tx_output_TransactionOutput_ctor(creditOutputsCount, credit_outputs);
    uint32_t output_index = (uint32_t ) self.registrationAssetLockTransaction.lockedOutpoint.n;
    
    return dash_spv_platform_transition_instant_proof(output_index, version, lock_inputs, txid, cycle_hash, signature, tx_version, lock_time, input_vec, output_vec, asset_lock_payload_version, credit_output_vec);

}

- (DAssetLockProof *)createChainProof {
    DSUTXO lockedOutpoint = self.registrationAssetLockTransaction.lockedOutpoint;
    u256 *txid = u256_ctor_u(uint256_reverse(lockedOutpoint.hash));
    uint32_t vout = (uint32_t) lockedOutpoint.n;
    return dash_spv_platform_transition_chain_proof(self.registrationAssetLockTransaction.blockHeight, txid, vout);
}

- (void)registerIdentityWithProof:(DAssetLockProof *)proof
                       public_key:(DIdentityPublicKey *)public_key
                          atIndex:(uint32_t)index
                       completion:(void (^)(BOOL, NSError *))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: Register Identity using public key (%u: %p) at %u with private key: %p", self.logPrefix, public_key->tag, public_key, index, self.internalRegistrationFundingPrivateKey->ok];
    DSLog(@"%@", debugInfo);
    DMaybeStateTransitionProofResult *state_transition_result = dash_spv_platform_PlatformSDK_identity_register_using_public_key_at_index(self.chain.sharedRuntime, self.chain.sharedPlatformObj, public_key, index, proof, self.internalRegistrationFundingPrivateKey->ok);
    if (state_transition_result->error) {
        NSError *error = [NSError ffi_from_platform_error:state_transition_result->error];
        DSLog(@"%@: ERROR: %@", debugInfo, error);
        switch (state_transition_result->error->tag) {
            case dash_spv_platform_error_Error_InstantSendSignatureVerificationError:
                DSLog(@"%@: Probably isd lock is outdated... try with chain lock proof", debugInfo);
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                DAssetLockProof *proof = [self createChainProof];
                [self registerIdentityWithProof:proof public_key:public_key atIndex:index completion:completion];
                break;
                
            default: {
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                if (completion) completion(nil, ERROR_REG_TRANSITION_CREATION);
                break;
            }
        }
        return;
    }
    [self processStateTransitionResult:state_transition_result];
    
    DSLog(@"%@: OK %p -> monitor_with_delay", debugInfo, state_transition_result->ok);
    DMaybeIdentity *result = dash_spv_platform_identity_manager_IdentitiesManager_monitor_with_delay(self.chain.sharedRuntime, self.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData), DRetryLinear(5), dash_spv_platform_identity_manager_IdentityValidator_None_ctor(), 4);
    
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DSLog(@"%@: monitor_with_delay: ERROR: %@", debugInfo, error);
        DMaybeIdentityDtor(result);
        completion(NO, error);
    } else if (result->ok) {
        DSLog(@"%@: monitor_with_delay: OK: (%p)", debugInfo, result->ok);
        DMaybeIdentityDtor(result);
        completion(YES, NULL);
    } else {
        DMaybeIdentityDtor(result);
        completion(NO, ERROR_REG_TRANSITION);
    }

}

- (BOOL)containsPublicKey:(DIdentityPublicKey *)identity_public_key {
    DMaybeOpaqueKey *key = [self keyAtIndex:identity_public_key->v0->id->_0];
    if (!key || !key->ok) return NO;
    return dash_spv_crypto_keys_key_OpaqueKey_public_key_data_equal_to(key->ok, identity_public_key->v0->data->_0);
}

- (BOOL)containsTopupTransaction:(DSAssetLockTransaction *)transaction {
    return [self.topupAssetLockTransactionHashes containsObject:uint256_data(transaction.txHash)];
}

- (void)registerIdentityWithProof2:(DAssetLockProof *)proof
                       public_key:(DIdentityPublicKey *)public_key
                          atIndex:(uint32_t)index
                        completion:(void (^)(BOOL, NSError *_Nullable))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: Register Identity using public key (%u: %p) at %u with private key: %p", self.logPrefix, public_key->tag, public_key, index, self.internalRegistrationFundingPrivateKey->ok];
    DSLog(@"%@", debugInfo);
    Result_ok_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error *state_transition_result = dash_spv_platform_PlatformSDK_identity_register_using_public_key_at_index2(self.chain.sharedRuntime, self.chain.sharedPlatformObj, public_key, index, proof, self.internalRegistrationFundingPrivateKey->ok);
    if (state_transition_result->error) {
        NSError *error = [NSError ffi_from_platform_error:state_transition_result->error];
        DSLog(@"%@: ERROR: %@", debugInfo, error);
        switch (state_transition_result->error->tag) {
            case dash_spv_platform_error_Error_InstantSendSignatureVerificationError:
                DSLog(@"%@: Probably isd lock is outdated... try with chain lock proof", debugInfo);
                Result_ok_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(state_transition_result);
                DAssetLockProof *proof = [self createChainProof];
                [self registerIdentityWithProof2:proof public_key:public_key atIndex:index completion:completion];
                break;
                
            default: {
                Result_ok_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(state_transition_result);
                if (completion) completion(nil, ERROR_REG_TRANSITION_CREATION);
                break;
            }
        }
        return;
    }
    DIdentity *identity = state_transition_result->ok;
    [self applyIdentity:identity save:YES inContext:self.platformContext];
    Result_ok_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(state_transition_result);
    DSLog(@"%@: OK ", debugInfo);
    completion(YES, NULL);
}

- (void)topupIdentityWithProof:(DAssetLockProof *)proof
                    public_key:(DIdentityPublicKey *)public_key
                       atIndex:(uint32_t)index
                    completion:(void (^)(BOOL, NSError *_Nullable))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: TopUp Identity using public key (%u: %p) at %u with private key: %p", self.logPrefix, public_key->tag, public_key, index, self.internalTopupFundingPrivateKey->ok];
    DSLog(@"%@", debugInfo);
    u256 *identity_id = u256_ctor_u(self.uniqueID);
    DMaybeStateTransitionProofResult *state_transition_result = dash_spv_platform_PlatformSDK_identity_topup(self.chain.sharedRuntime, self.chain.sharedPlatformObj, identity_id, proof, self.internalTopupFundingPrivateKey->ok);
    if (state_transition_result->error) {
        NSError *error = [NSError ffi_from_platform_error:state_transition_result->error];
        DSLog(@"%@: ERROR: %@", debugInfo, error);
        switch (state_transition_result->error->tag) {
            case dash_spv_platform_error_Error_InstantSendSignatureVerificationError:
                DSLog(@"%@: Probably isd lock is outdated... try with chain lock proof", debugInfo);
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                DAssetLockProof *proof = [self createChainProof];
                [self topupIdentityWithProof:proof public_key:public_key atIndex:index completion:completion];
                break;
                
            default: {
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                if (completion) completion(nil, ERROR_REG_TRANSITION_CREATION);
                break;
            }
        }
        return;
    }
    DSLog(@"%@: OK", debugInfo);
    [self processStateTransitionResult:state_transition_result];
    DMaybeStateTransitionProofResultDtor(state_transition_result);
    completion(YES, NULL);
}

//    [self.identity topupTransactionForTopupAmount:topupAmount fundedByAccount:self.fundingAccount completion:^(DSIdentityTopupTransition *identityTopupTransaction) {
//        if (identityTopupTransaction) {
//            [self.fundingAccount signTransaction:identityTopupTransaction withPrompt:@"Fund Transaction" completion:^(BOOL signedTransaction, BOOL cancelled) {
//                if (signedTransaction) {
//                    [self.chainManager.transactionManager publishTransaction:identityTopupTransaction completion:^(NSError * _Nullable error) {
//                        if (error) {
//                            [self raiseIssue:@"Error" message:error.localizedDescription];
//
//                        } else {
//                            [self.navigationController popViewControllerAnimated:TRUE];
//                        }
//                    }];
//                } else {
//                    [self raiseIssue:@"Error" message:@"Transaction was not signed."];
//
//                }
//            }];
//        } else {
//            [self raiseIssue:@"Error" message:@"Unable to create BlockchainIdentityTopupTransaction."];
//
//        }
//    }];

- (void)createAndPublishTopUpTransitionForAmount:(uint64_t)amount
                                 fundedByAccount:(DSAccount *)fundingAccount
                                       pinPrompt:(NSString *)prompt
                                  withCompletion:(void (^)(BOOL, NSError *_Nullable))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: CREATE AND PUBLISH IDENTITY TOPUP TRANSITION", self.logPrefix];
    DSLog(@"%@", debugInfo);
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:self.wallet];
    NSString *topupAddress = [path addressAtIndex:self.index];
    DSAssetLockTransaction *assetLockTransaction = [fundingAccount assetLockTransactionFor:amount to:topupAddress withFee:YES];
    if (!assetLockTransaction) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, ERROR_FUNDING_TX_CREATION); });
        return;
    }
    
    [fundingAccount signTransaction:assetLockTransaction
                         withPrompt:prompt
                         completion:^(BOOL signedTransaction, BOOL cancelled) {
        if (!signedTransaction) {
            if (completion)
                dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, cancelled ? nil : ERROR_FUNDING_TX_SIGNING); });
            return;
        }
        [self publishTransactionAndWait:assetLockTransaction completion:^(BOOL published, DSInstantSendTransactionLock *_Nullable instantSendLock, NSError *_Nullable error) {
            if (!published) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, ERROR_FUNDING_TX_TIMEOUT); });
                return;
            }
            if (!instantSendLock) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, ERROR_FUNDING_TX_ISD_TIMEOUT); });
                return;
            }
            if (!self.internalTopupFundingPrivateKey) {
                DSLog(@"%@: ERROR: No TopUp Funding Private Key", debugInfo);
                if (completion) completion(nil, ERROR_NO_FUNDING_PRV_KEY);
                return;
            }
            uint32_t index = [self firstIndexOfKeyOfType:DKeyKindECDSA() createIfNotPresent:YES saveKey:!self.wallet.isTransient];
            [debugInfo appendFormat:@", index: %u", index];
            DMaybeOpaqueKey *publicKey = [self keyAtIndex:index];
            [debugInfo appendFormat:@", public_key: %p", publicKey];
            DSInstantSendTransactionLock *isLock = assetLockTransaction.instantSendLockAwaitingProcessing;
            [debugInfo appendFormat:@", is_lock: %p", isLock];
            if (!isLock && assetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
                DSLog(@"%@: ERROR: Funding Tx Not Mined", debugInfo);
                if (completion) completion(nil, ERROR_FUNDING_TX_NOT_MINED);
                return;
            }
            DIdentityPublicKey *public_key = dash_spv_platform_identity_manager_identity_registration_public_key(index, publicKey->ok);
            DAssetLockProof *proof = [self createProof:isLock];
            DSLog(@"%@ Proof: %u: %p", debugInfo, proof->tag, proof);
            [self topupIdentityWithProof:proof public_key:public_key atIndex:index completion:completion];
        }];

    }];
}

- (void)createAndPublishRegistrationTransitionWithCompletion:(void (^)(BOOL, NSError *))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: CREATE AND PUBLISH IDENTITY REGISTRATION TRANSITION", self.logPrefix];
    DSLog(@"%@", debugInfo);
    if (!self.internalRegistrationFundingPrivateKey) {
        DSLog(@"%@: ERROR: No Funding Private Key", debugInfo);
        if (completion) completion(nil, ERROR_NO_FUNDING_PRV_KEY);
        return;
    }
    uint32_t index = [self firstIndexOfKeyOfType:DKeyKindECDSA() createIfNotPresent:YES saveKey:!self.wallet.isTransient];
    [debugInfo appendFormat:@", index: %u", index];
    DMaybeOpaqueKey *publicKey = [self keyAtIndex:index];
    [debugInfo appendFormat:@", public_key: %p", publicKey];
    NSAssert((index & ~(BIP32_HARD)) == 0, @"The index should be 0 here");
    NSAssert(self.registrationAssetLockTransaction, @"The registration credit funding transaction must be known %@", uint256_hex(self.registrationAssetLockTransactionHash));
    DSInstantSendTransactionLock *isLock = self.registrationAssetLockTransaction.instantSendLockAwaitingProcessing;
    [debugInfo appendFormat:@", is_lock: %p", isLock];
    if (!isLock && self.registrationAssetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
        DSLog(@"%@: ERROR: Funding Tx Not Mined", debugInfo);
        if (completion) completion(nil, ERROR_FUNDING_TX_NOT_MINED);
        return;
    }
    DIdentityPublicKey *public_key = dash_spv_platform_identity_manager_identity_registration_public_key(index, publicKey->ok);
    DAssetLockProof *proof = [self createProof:isLock];
    DSLog(@"%@ Proof: %u: %p", debugInfo, proof->tag, proof);
    [self registerIdentityWithProof2:proof public_key:public_key atIndex:index completion:completion];
}

// MARK: Retrieval

- (void)fetchIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success, BOOL found, NSError *error))completion {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@: Fetch Identity State", self.logPrefix];
    DSLog(@"%@", debugString);
    dispatch_async(self.identityQueue, ^{
        DMaybeIdentity *result = dash_spv_platform_identity_manager_IdentitiesManager_monitor_for_id_bytes(self.chain.sharedRuntime, self.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData), DRetryDown50(DEFAULT_FETCH_IDENTITY_RETRY_COUNT), self.isLocal ? dash_spv_platform_identity_manager_IdentityValidator_AcceptNotFoundAsNotAnError_ctor() : dash_spv_platform_identity_manager_IdentityValidator_None_ctor());
        if (result->error) {
            NSError *error = [NSError ffi_from_platform_error:result->error];
            DSLog(@"%@: ERROR: %@", debugString, error);
            DMaybeIdentityDtor(result);
            completion(NO, NO, error);
            return;
        }
        DIdentity *identity = result->ok;
        if (!identity) {
            DSLog(@"%@ ERROR: None", debugString);
            DMaybeIdentityDtor(result);
            completion(YES, NO, nil);
            return;
        }
        switch (identity->tag) {
            case dpp_identity_identity_Identity_V0: {
                dpp_identity_v0_IdentityV0 *identity_v0 = identity->v0;
                self->_creditBalance = identity_v0->balance;
                DIdentityPublicKeysMap *public_keys = identity_v0->public_keys;
                for (int i = 0; i < public_keys->count; i++) {
                    DIdentityPublicKey *key = public_keys->values[i];
                    DMaybeOpaqueKey *maybe_key = dash_spv_platform_identity_manager_opaque_key_from_identity_public_key(key);
                    DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(maybe_key->ok);
                    [self addKey:maybe_key atIndex:i ofType:kind withStatus:DSIdentityKeyStatus_Registered save:!self.isTransient inContext:self.platformContext];
                }
                self.registrationStatus = DSIdentityRegistrationStatus_Registered;
                break;
            }
            default:
                break;
        }
        DMaybeIdentityDtor(result);
        DSLog(@"%@: OK", debugString);
        completion(YES, YES, nil);
    });
}

- (void)fetchAllNetworkStateInformationWithCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion {
    dispatch_async(self.identityQueue, ^{
        [self fetchAllNetworkStateInformationInContext:self.platformContext
                                        withCompletion:completion
                                     onCompletionQueue:dispatch_get_main_queue()];
    });
}

- (void)fetchAllNetworkStateInformationInContext:(NSManagedObjectContext *)context
                                  withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                               onCompletionQueue:(dispatch_queue_t)completionQueue {
    dispatch_async(self.identityQueue, ^{
        DSIdentityQueryStep query = DSIdentityQueryStep_None;
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Identities)
            query |= DSIdentityQueryStep_Identity;
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
            query |= DSIdentityQueryStep_Username;
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
            query |= DSIdentityQueryStep_Profile;
            if (self.isLocal)
                query |= DSIdentityQueryStep_ContactRequests;
        }
        [self fetchNetworkStateInformation:query
                                 inContext:context
                            withCompletion:completion
                         onCompletionQueue:completionQueue];
    });
}

- (void)fetchL3NetworkStateInformation:(DSIdentityQueryStep)queryStep
                        withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion {
    [self fetchL3NetworkStateInformation:queryStep
                               inContext:self.platformContext
                          withCompletion:completion
                       onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchL3NetworkStateInformation:(DSIdentityQueryStep)queryStep
                             inContext:(NSManagedObjectContext *)context
                        withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                     onCompletionQueue:(dispatch_queue_t)completionQueue {
    DSLog(@"%@: Fetch L3 State (%@)", self.logPrefix, DSIdentityQueryStepsDescription(queryStep));
    if (!(queryStep & DSIdentityQueryStep_Identity) && (!self.activeKeyCount)) {
        // We need to fetch keys if we want to query other information
        if (completion) completion(DSIdentityQueryStep_BadQuery, @[ERROR_ATTEMPT_QUERY_WITHOUT_KEYS]);
        return;
    }
    __block DSIdentityQueryStep failureStep = DSIdentityQueryStep_None;
    __block NSMutableArray *groupedErrors = [NSMutableArray array];
    dispatch_group_t dispatchGroup = dispatch_group_create();
    if (queryStep & DSIdentityQueryStep_Username) {
        dispatch_group_enter(dispatchGroup);
        [self fetchUsernamesInContext:context
                       withCompletion:^(BOOL success, NSError *error) {
            failureStep |= success & DSIdentityQueryStep_Username;
            if (error) [groupedErrors addObject:error];
            dispatch_group_leave(dispatchGroup);
        }
                    onCompletionQueue:self.identityQueue];
    }
    
    if (queryStep & DSIdentityQueryStep_Profile) {
        dispatch_group_enter(dispatchGroup);
        [self fetchProfileInContext:context withCompletion:^(BOOL success, NSError *error) {
            failureStep |= success & DSIdentityQueryStep_Profile;
            if (error) [groupedErrors addObject:error];
            dispatch_group_leave(dispatchGroup);
        }
                  onCompletionQueue:self.identityQueue];
    }
    
    if (queryStep & DSIdentityQueryStep_OutgoingContactRequests) {
        dispatch_group_enter(dispatchGroup);
        [self fetchOutgoingContactRequestsInContext:context
                                         startAfter:nil
                                     withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
            failureStep |= success & DSIdentityQueryStep_OutgoingContactRequests;
            if ([errors count]) {
                [groupedErrors addObjectsFromArray:errors];
                dispatch_group_leave(dispatchGroup);
            } else {
                if (queryStep & DSIdentityQueryStep_IncomingContactRequests) {
                    [self fetchIncomingContactRequestsInContext:context
                                                     startAfter:nil
                                                 withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
                        failureStep |= success & DSIdentityQueryStep_IncomingContactRequests;
                        if ([errors count]) [groupedErrors addObjectsFromArray:errors];
                        dispatch_group_leave(dispatchGroup);
                    }
                                              onCompletionQueue:self.identityQueue];
                } else {
                    dispatch_group_leave(dispatchGroup);
                }
            }
        }
                                  onCompletionQueue:self.identityQueue];
    } else if (queryStep & DSIdentityQueryStep_IncomingContactRequests) {
        dispatch_group_enter(dispatchGroup);
        [self fetchIncomingContactRequestsInContext:context
                                         startAfter:nil
                                     withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
            failureStep |= success & DSIdentityQueryStep_IncomingContactRequests;
            if ([errors count]) [groupedErrors addObjectsFromArray:errors];
            dispatch_group_leave(dispatchGroup);
        }
                                  onCompletionQueue:self.identityQueue];
    }
    
    __weak typeof(self) weakSelf = self;
    if (completion) {
        dispatch_group_notify(dispatchGroup, self.identityQueue, ^{
#if DEBUG
            DSLogPrivate(@"%@: Completed fetching of identity information for user %@ (query %@ - failures %@)", self.logPrefix,
                         self.currentDashpayUsername ? self.currentDashpayUsername : self.uniqueIdString, DSIdentityQueryStepsDescription(queryStep), DSIdentityQueryStepsDescription(failureStep));
#else
            DSLog(@"%@: Completed fetching of identity information for user %@ (query %@ - failures %@)",
                  @"<REDACTED>", self.logPrefix, DSIdentityQueryStepsDescription(queryStep), DSIdentityQueryStepsDescription(failureStep));
#endif /* DEBUG */
            if (!(failureStep & DSIdentityQueryStep_ContactRequests)) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                //todo This needs to be eventually set with the blockchain returned by platform.
                strongSelf.dashpaySyncronizationBlockHash = strongSelf.chain.lastTerminalBlock.blockHash;
            }
            dispatch_async(completionQueue, ^{ completion(failureStep, [groupedErrors copy]); });
        });
    }
}

- (void)fetchNetworkStateInformation:(DSIdentityQueryStep)querySteps
                      withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion {
    [self fetchNetworkStateInformation:querySteps
                             inContext:self.platformContext
                        withCompletion:completion
                     onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchNetworkStateInformation:(DSIdentityQueryStep)querySteps
                           inContext:(NSManagedObjectContext *)context
                      withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                   onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@: fetchNetworkStateInformation (%@)", self.logPrefix, DSIdentityQueryStepsDescription(querySteps)];
    DSLog(@"%@", debugString);
    if (querySteps & DSIdentityQueryStep_Identity) {
        [self fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, BOOL found, NSError *error) {
            if (!success) {
                DSLog(@"%@: ERROR: %@", debugString, error);
                if (completion) dispatch_async(completionQueue, ^{ completion(DSIdentityQueryStep_Identity, error ? @[error] : @[]); });
                return;
            }
            if (!found) {
                DSLog(@"%@: ERROR: NoIdentity", debugString);
                if (completion) dispatch_async(completionQueue, ^{ completion(DSIdentityQueryStep_NoIdentity, @[]); });
                return;
            }
            [self fetchL3NetworkStateInformation:querySteps
                                       inContext:context
                                  withCompletion:completion
                               onCompletionQueue:completionQueue];
        }];
    } else {
        NSAssert([self identityEntityInContext:context], @"Blockchain identity entity should be known");
        [self fetchL3NetworkStateInformation:querySteps
                                   inContext:context
                              withCompletion:completion
                           onCompletionQueue:completionQueue];
    }
}

- (void)fetchIfNeededNetworkStateInformation:(DSIdentityQueryStep)querySteps
                                   inContext:(NSManagedObjectContext *)context
                              withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                           onCompletionQueue:(dispatch_queue_t)completionQueue {
    dispatch_async(self.identityQueue, ^{
        if (!self.activeKeyCount) {
            if (self.isLocal) {
                [self fetchNetworkStateInformation:querySteps
                                         inContext:context
                                    withCompletion:completion
                                 onCompletionQueue:completionQueue];
            } else {
                DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
                if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Identities)
                    stepsNeeded |= DSIdentityQueryStep_Identity;
                if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
                    stepsNeeded |= DSIdentityQueryStep_Username;
                if ((self.lastCheckedProfileTimestamp < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                    stepsNeeded |= DSIdentityQueryStep_Profile;
                if (stepsNeeded != DSIdentityQueryStep_None) {
                    [self fetchNetworkStateInformation:stepsNeeded & querySteps inContext:context withCompletion:completion onCompletionQueue:completionQueue];
                } else if (completion) {
                    completion(DSIdentityQueryStep_None, @[]);
                }
            }
        } else {
            DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
            if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS) {
                stepsNeeded |= DSIdentityQueryStep_Username;
            }
            __block uint64_t createdAt;
            [context performBlockAndWait:^{
                createdAt = [[self matchingDashpayUserInContext:context] createdAt];
            }];
            if (!createdAt && (self.lastCheckedProfileTimestamp < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_Profile;
            if (self.isLocal && (self.lastCheckedIncomingContactsTimestamp < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_IncomingContactRequests;
            if (self.isLocal && (self.lastCheckedOutgoingContactsTimestamp < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_OutgoingContactRequests;
            if (stepsNeeded != DSIdentityQueryStep_None) {
                [self fetchNetworkStateInformation:stepsNeeded & querySteps inContext:context withCompletion:completion onCompletionQueue:completionQueue];
            } else if (completion) {
                completion(DSIdentityQueryStep_None, @[]);
            }
        }
    });
}

- (void)fetchNeededNetworkStateInformationInContext:(NSManagedObjectContext *)context
                                     withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                                  onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@: fetchNeededNetworkStateInformationInContext (local: %u, active keys: %u) ", self.logPrefix, self.isLocal, self.activeKeyCount];
    DSLog(@"%@", debugString);
    dispatch_async(self.identityQueue, ^{
        if (!self.activeKeyCount) {
            if (self.isLocal) {
                [self fetchAllNetworkStateInformationWithCompletion:completion];
            } else {
                DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
                if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Identities)
                    stepsNeeded |= DSIdentityQueryStep_Identity;
                if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
                    stepsNeeded |= DSIdentityQueryStep_Username;
                if ((self.lastCheckedProfileTimestamp < [NSDate timeIntervalSince1970Minus:HOUR_TIME_INTERVAL]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                    stepsNeeded |= DSIdentityQueryStep_Profile;
                if (stepsNeeded != DSIdentityQueryStep_None) {
                    [self fetchNetworkStateInformation:stepsNeeded
                                             inContext:context
                                        withCompletion:completion
                                     onCompletionQueue:completionQueue];
                } else if (completion) {
                    completion(DSIdentityQueryStep_None, @[]);
                }
            }
        } else {
            DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
            if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
                stepsNeeded |= DSIdentityQueryStep_Username;
            if (![[self matchingDashpayUserInContext:context] createdAt] && (self.lastCheckedProfileTimestamp < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_Profile;
            if (self.isLocal && (self.lastCheckedIncomingContactsTimestamp < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_IncomingContactRequests;
            if (self.isLocal && (self.lastCheckedOutgoingContactsTimestamp < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_OutgoingContactRequests;
            if (stepsNeeded != DSIdentityQueryStep_None) {
                [self fetchNetworkStateInformation:stepsNeeded
                                         inContext:context
                                    withCompletion:completion
                                 onCompletionQueue:completionQueue];
            } else if (completion) {
                completion(DSIdentityQueryStep_None, @[]);
            }
        }
    });
}

// MARK: - Signing and Encryption

- (BOOL)verifySignature:(NSData *)signature
                 ofType:(DKeyKind *)signingAlgorithm
       forMessageDigest:(UInt256)messageDigest {
    for (NSValue *publicKey in [self activeKeysForKeyType:signingAlgorithm]) {
        SLICE *message_digest = slice_u256_ctor_u(messageDigest);
        SLICE *sig = slice_ctor(signature);
        DMaybeOpaqueKey *maybe_key = publicKey.pointerValue;
        Result_ok_bool_err_dash_spv_crypto_keys_KeyError *result = dash_spv_crypto_keys_key_OpaqueKey_verify(maybe_key->ok, message_digest, sig);
        // TODO: check if correct
        BOOL verified = result && result->ok && result->ok[0] == YES;
        
//        BOOL verified = key_verify_message_digest(publicKey.pointerValue, messageDigest.u8, signature.bytes, signature.length);
        if (verified)
            return TRUE;
    }
    return FALSE;
}

- (BOOL)verifySignature:(NSData *)signature
            forKeyIndex:(uint32_t)keyIndex
                 ofType:(DKeyKind *)signingAlgorithm
       forMessageDigest:(UInt256)messageDigest {
    DMaybeOpaqueKey *publicKey = [self publicKeyAtIndex:keyIndex ofType:signingAlgorithm];
    BOOL verified = [DSKeyManager verifyMessageDigest:publicKey->ok digest:messageDigest signature:signature];
    DMaybeOpaqueKeyDtor(publicKey);
    return verified;
}

- (NSData *)encryptData:(NSData *)data
         withKeyAtIndex:(uint32_t)index
        forRecipientKey:(DOpaqueKey *)recipientPublicKey {
    NSParameterAssert(data);
    NSParameterAssert(recipientPublicKey);
    DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(recipientPublicKey);
    DMaybeOpaqueKey *privateKey = [self privateKeyAtIndex:index ofType:kind];
    NSData *encryptedData = [DSKeyManager encryptData:data secretKey:privateKey->ok publicKey:recipientPublicKey];
    DMaybeOpaqueKeyDtor(privateKey);
    return encryptedData;
}

- (BOOL)processStateTransitionResult:(DMaybeStateTransitionProofResult *)result {
#if (defined(DPP_STATE_TRANSITIONS))
    dpp_state_transition_proof_result_StateTransitionProofResult *proof_result = result->ok;
    switch (proof_result->tag) {
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedDataContract: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_data_contract->v0->id->_0->_0);
            DSLog(@"%@: VerifiedDataContract: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedIdentity: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_identity->v0->id->_0->_0);
            DSLog(@"%@: VerifiedIdentity: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedPartialIdentity: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_partial_identity>id->_0->_0);
            DSLog(@"%@: VerifiedPartialIdentity: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedBalanceTransfer: {
            dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedBalanceTransfer_Body *transfer = proof_result->verified_balance_transfer;
            NSData *from_identifier = NSDataFromPtr(transfer->_0->id->_0->_0);
            NSData *to_identifier = NSDataFromPtr(transfer->_1->id->_0->_0);
            DSLog(@"%@: VerifiedBalanceTransfer: %@ --> %@", self.logPrefix, from_identifier.hexString, to_identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedDocuments: {
            std_collections_Map_keys_platform_value_types_identifier_Identifier_values_Option_dpp_document_Document *verified_documents = proof_result->verified_documents;
            DSLog(@"%@: VerifiedDocuments: %u", self.logPrefix, verified_documents->count);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedMasternodeVote: {
            dpp_voting_votes_Vote *verified_masternode_vote = proof_result->verified_masternode_vote;
            DSLog(@"%@: VerifiedMasternodeVote: %u", self.logPrefix, verified_masternode_vote->tag);
            break;
        }
        default:
            break;
    }
#endif
    return YES;
}

// MARK: - Contracts

- (void)fetchAndUpdateContract:(DPContract *)contract {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@: fetchAndUpdateContract (%lu) ", self.logPrefix, (unsigned long) contract.contractState];
    DSLog(@"%@", debugString);
    NSManagedObjectContext *context = [NSManagedObjectContext platformContext];
    __weak typeof(contract) weakContract = contract;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get service immediately
        BOOL isDPNSEmpty = [contract.name isEqual:@"DPNS"] && uint256_is_zero(self.chain.dpnsContractID);
        BOOL isDashpayEmpty = [contract.name isEqual:@"DashPay"] && uint256_is_zero(self.chain.dashpayContractID);
        BOOL isOtherContract = !([contract.name isEqual:@"DashPay"] || [contract.name isEqual:@"DPNS"]);
        if (((isDPNSEmpty || isDashpayEmpty || isOtherContract) && uint256_is_zero(contract.registeredIdentityUniqueID)) || contract.contractState == DPContractState_NotRegistered) {
            [contract registerCreator:self];
            [contract saveAndWaitInContext:context];
            
            if (!self.keysCreated) {
                uint32_t index;
                [self createNewKeyOfType:DKeyKindECDSA() saveKey:!self.wallet.isTransient returnIndex:&index];
            }
            DMaybeOpaqueKey *privateKey = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
            
            DMaybeStateTransitionProofResult *state_transition_result = dash_spv_platform_PlatformSDK_data_contract_create2(self.chain.sharedRuntime, self.chain.sharedPlatformObj, data_contracts_SystemDataContract_DPNS_ctor(), u256_ctor_u(self.uniqueID), 0, privateKey->ok);

            if (state_transition_result->error) {
                DSLog(@"%@: ERROR: %@", debugString, [NSError ffi_from_platform_error:state_transition_result->error]);
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                return;
            }
            DSLog(@"%@: OK", debugString);
            if ([self processStateTransitionResult:state_transition_result]) {
                contract.contractState = DPContractState_Registering;
            } else {
                contract.contractState = DPContractState_Unknown;
            }
            [contract saveAndWaitInContext:context];
            
            DMaybeContract *monitor_result = dash_spv_platform_contract_manager_ContractsManager_monitor_for_id_bytes(self.chain.sharedRuntime, self.chain.shareCore.contractsManager->obj, u256_ctor_u(contract.contractId), DRetryLinear(2), dash_spv_platform_contract_manager_ContractValidator_None_ctor());

            if (monitor_result->error) {
                DMaybeContractDtor(monitor_result);
                DSLog(@"%@: Contract Monitoring Error: %@", self.logPrefix, [NSError ffi_from_platform_error:monitor_result->error]);
                return;
            }
            if (monitor_result->ok) {
                NSData *identifier = NSDataFromPtr(monitor_result->ok->v0->id->_0->_0);
                if ([identifier isEqualToData:uint256_data(contract.contractId)]) {
                    DSLog(@"%@: Contract Monitoring OK", self.logPrefix);
                    contract.contractState = DPContractState_Registered;
                    [contract saveAndWaitInContext:context];
                } else {
                    DSLog(@"%@: Contract Monitoring Error: Ids dont match", self.logPrefix);
                }
            }
            DSLog(@"%@: Contract Monitoring Error", self.logPrefix);

        } else if (contract.contractState == DPContractState_Registered || contract.contractState == DPContractState_Registering) {
            DSLog(@"%@: Fetching contract for verification %@", self.logPrefix, contract.base58ContractId);
            DIdentifier *identifier = platform_value_types_identifier_Identifier_ctor(platform_value_types_identifier_IdentifierBytes32_ctor(u256_ctor_u(contract.contractId)));
            DMaybeContract *result = dash_spv_platform_contract_manager_ContractsManager_fetch_contract_by_id(self.chain.sharedRuntime, self.chain.shareCore.contractsManager->obj, identifier);
            if (!result) return;
            if (result->error || !result->ok->v0->document_types) {
                DSLog(@"%@: Fetch contract error %u", self.logPrefix, result->error->tag);
                contract.contractState = DPContractState_NotRegistered;
                [contract saveAndWaitInContext:context];
                DMaybeContractDtor(result);
                return;
            }

            DMaybeContract *contract_result = dash_spv_platform_contract_manager_ContractsManager_fetch_contract_by_id_bytes(self.chain.sharedRuntime, self.chain.shareCore.contractsManager->obj, u256_ctor_u(contract.contractId));

            dispatch_async(self.identityQueue, ^{
                __strong typeof(weakContract) strongContract = weakContract;
                if (!weakContract || !contract_result) return;
                if (!contract_result->ok) {
                    DSLog(@"%@: Contract Monitoring ERROR: NotRegistered ", self.logPrefix);
                    strongContract.contractState = DPContractState_NotRegistered;
                    [strongContract saveAndWaitInContext:context];
                    DMaybeContractDtor(result);
                    return;
                }
                DSLog(@"%@: Contract Monitoring OK: %@ ", self.logPrefix, strongContract);
                if (strongContract.contractState == DPContractState_Registered && !dash_spv_platform_contract_manager_has_equal_document_type_keys(contract_result->ok, strongContract.raw_contract)) {
                    strongContract.contractState = DPContractState_NotRegistered;
                    [strongContract saveAndWaitInContext:context];
                    //DSLog(@"Contract dictionary is %@", contractDictionary);
                }
            });
        }
    });
}

// MARK: - Monitoring

- (void)updateCreditBalance {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        Result_ok_Option_u64_err_dash_spv_platform_error_Error *result = dash_spv_platform_identity_manager_IdentitiesManager_fetch_balance_by_id_bytes(strongSelf.chain.sharedRuntime, strongSelf.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData));
        if (!result) {
            DSLog(@"%@: updateCreditBalance: NULL RESULT", self.logPrefix);
            return;
        }
        if (!result->ok) {
            DSLog(@"%@: updateCreditBalance: ERROR RESULT: %u", self.logPrefix, result->error->tag);
            Result_ok_Option_u64_err_dash_spv_platform_error_Error_destroy(result);
            return;
        }
        dispatch_async(self.identityQueue, ^{
            DSLog(@"%@: updateCreditBalance: OK: %llu", self.logPrefix, result->ok[0]);
            strongSelf.creditBalance = result->ok[0];
        });
    });
}


// MARK: Helpers

- (BOOL)isDashpayReady {
    return self.activeKeyCount > 0 && self.isRegistered;
}



// MARK: - Persistence

// MARK: Saving

- (void)saveInitial {
    [self saveInitialInContext:self.platformContext];
}

- (DSBlockchainIdentityEntity *)initialEntityInContext:(NSManagedObjectContext *)context {
    DSChainEntity *chainEntity = [self.chain chainEntityInContext:context];
    DSBlockchainIdentityEntity *entity = [DSBlockchainIdentityEntity managedObjectInBlockedContext:context];
    entity.uniqueID = uint256_data(self.uniqueID);
    entity.isLocal = self.isLocal;
    entity.registrationStatus = self.registrationStatus;
    if (self.isLocal) {
        entity.registrationFundingTransaction = [DSAssetLockTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.registrationAssetLockTransaction.txHash)];
    }
    entity.chain = chainEntity;
    [self collectUsernameEntitiesIntoIdentityEntityInContext:entity context:context];
    for (NSNumber *index in self.keyInfoDictionaries) {
        NSDictionary *keyDictionary = self.keyInfoDictionaries[index];
        DSIdentityKeyStatus status = [keyDictionary[@(DSIdentityKeyDictionary_KeyStatus)] unsignedIntValue];
        DKeyKind *keyType = [keyDictionary[@(DSIdentityKeyDictionary_KeyType)] pointerValue];
        DMaybeOpaqueKey *key = [keyDictionary[@(DSIdentityKeyDictionary_Key)] pointerValue];
        DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:keyType];
        const NSUInteger indexes[] = {_index, index.unsignedIntegerValue};
        [self createNewKey:key
         forIdentityEntity:entity
                    atPath:[NSIndexPath indexPathWithIndexes:indexes length:2]
                withStatus:status
        fromDerivationPath:derivationPath
                 inContext:context];
    }
    DSDashpayUserEntity *dashpayUserEntity = [DSDashpayUserEntity managedObjectInBlockedContext:context];
    dashpayUserEntity.chain = chainEntity;
    entity.matchingDashpayUser = dashpayUserEntity;
    if (self.isOutgoingInvitation) {
        DSBlockchainInvitationEntity *invitationEntity = [DSBlockchainInvitationEntity managedObjectInBlockedContext:context];
        invitationEntity.chain = chainEntity;
        entity.associatedInvitation = invitationEntity;
    }
    return entity;
}

- (void)saveInitialInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    //no need for active check, in fact it will cause an infinite loop
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *entity = [self initialEntityInContext:context];
        DSDashpayUserEntity *dashpayUserEntity = entity.matchingDashpayUser;
        [context ds_saveInBlockAndWait];
        [[NSManagedObjectContext viewContext] performBlockAndWait:^{
            self.matchingDashpayUserInViewContext = [[NSManagedObjectContext viewContext] objectWithID:dashpayUserEntity.objectID];
        }];
        [[NSManagedObjectContext platformContext] performBlockAndWait:^{
            self.matchingDashpayUserInPlatformContext = [[NSManagedObjectContext platformContext] objectWithID:dashpayUserEntity.objectID];
        }];
        if ([self isLocal])
            [self notifyUpdate:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSIdentityKey: self
            }];
    }];
}

- (void)saveInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    if (!self.isActive) return;
    [context performBlockAndWait:^{
        BOOL changeOccured = NO;
        NSMutableArray *updateEvents = [NSMutableArray array];
        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
        if (entity.creditBalance != self.creditBalance) {
            entity.creditBalance = self.creditBalance;
            changeOccured = YES;
            [updateEvents addObject:DSIdentityUpdateEventCreditBalance];
        }
        if (entity.registrationStatus != self.registrationStatus) {
            entity.registrationStatus = self.registrationStatus;
            changeOccured = YES;
            [updateEvents addObject:DSIdentityUpdateEventRegistration];
        }
        
        if (!uint256_eq(entity.dashpaySyncronizationBlockHash.UInt256, self.dashpaySyncronizationBlockHash)) {
            entity.dashpaySyncronizationBlockHash = uint256_data(self.dashpaySyncronizationBlockHash);
            changeOccured = YES;
            [updateEvents addObject:DSIdentityUpdateEventDashpaySyncronizationBlockHash];
        }
        
        if (entity.lastCheckedUsernamesTimestamp != self.lastCheckedUsernamesTimestamp) {
            entity.lastCheckedUsernamesTimestamp = self.lastCheckedUsernamesTimestamp;
            changeOccured = YES;
        }
        
        if (entity.lastCheckedProfileTimestamp != self.lastCheckedProfileTimestamp) {
            entity.lastCheckedProfileTimestamp = self.lastCheckedProfileTimestamp;
            changeOccured = YES;
        }
        
        if (entity.lastCheckedIncomingContactsTimestamp != self.lastCheckedIncomingContactsTimestamp) {
            entity.lastCheckedIncomingContactsTimestamp = self.lastCheckedIncomingContactsTimestamp;
            changeOccured = YES;
        }
        
        if (entity.lastCheckedOutgoingContactsTimestamp != self.lastCheckedOutgoingContactsTimestamp) {
            entity.lastCheckedOutgoingContactsTimestamp = self.lastCheckedOutgoingContactsTimestamp;
            changeOccured = YES;
        }
        
        if (changeOccured) {
            [context ds_save];
            if (updateEvents.count)
                [self notifyUpdate:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSIdentityKey: self,
                    DSIdentityUpdateEvents: updateEvents
                }];
        }
    }];
}

- (NSString *)identifierForKeyAtPath:(NSIndexPath *)path
                  fromDerivationPath:(DSDerivationPath *)derivationPath {
    return [NSString stringWithFormat:@"%@-%@-%@", self.uniqueIdString, derivationPath.standaloneExtendedPublicKeyUniqueID, [[path softenAllItems] indexPathString]];
}

- (BOOL)createNewKey:(DMaybeOpaqueKey *)key
   forIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity
              atPath:(NSIndexPath *)path
          withStatus:(DSIdentityKeyStatus)status
  fromDerivationPath:(DSDerivationPath *)derivationPath
           inContext:(NSManagedObjectContext *)context {
    NSAssert(identityEntity, @"Entity should be present");
    
    DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:context];
    NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@", identityEntity, derivationPathEntity, path];
    if (!count) {
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
        keyPathEntity.derivationPath = derivationPathEntity;
        // TODO: that's wrong should convert KeyType <-> KeyKind
        keyPathEntity.keyType = dash_spv_platform_identity_manager_opaque_key_to_key_type_index(key->ok);
        keyPathEntity.keyStatus = status;
        NSData *privateKeyData = [DSKeyManager privateKeyData:key->ok];
        if (privateKeyData) {
            setKeychainData(privateKeyData, [self identifierForKeyAtPath:path fromDerivationPath:derivationPath], YES);
#if DEBUG
            DSLogPrivate(@"Saving key at %@ for user %@", [self identifierForKeyAtPath:path fromDerivationPath:derivationPath], self.currentDashpayUsername);
#else
            DSLog(@"Saving key at %@ for user %@", @"<REDACTED>", @"<REDACTED>");
#endif
        } else {
            DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(key->ok);
            DMaybeOpaqueKey *privateKey = [self derivePrivateKeyAtIndexPath:path ofType:kind];
            NSAssert([DSKeyManager keysPublicKeyDataIsEqual:privateKey->ok key2:key->ok], @"The keys don't seem to match up");
            NSData *privateKeyData = [DSKeyManager privateKeyData:privateKey->ok];
            NSAssert(privateKeyData, @"Private key data should exist");
            setKeychainData(privateKeyData, [self identifierForKeyAtPath:path fromDerivationPath:derivationPath], YES);
#if DEBUG
            DSLogPrivate(@"Saving key after rederivation %@ for user %@", [self identifierForKeyAtPath:path fromDerivationPath:derivationPath], self.currentDashpayUsername ? self.currentDashpayUsername : self.uniqueIdString);
#else
            DSLog(@"Saving key after rederivation %@ for user %@", @"<REDACTED>", @"<REDACTED>");
#endif
        }
        
        keyPathEntity.path = path;
        keyPathEntity.publicKeyData = [DSKeyManager publicKeyData:key->ok];
        keyPathEntity.keyID = (uint32_t)[path indexAtPosition:path.length - 1];
        [identityEntity addKeyPathsObject:keyPathEntity];
        return YES;
    } else {
#if DEBUG
        DSLogPrivate(@"Already had saved this key %@", path);
#else
        DSLog(@"Already had saved this key %@", @"<REDACTED>");
#endif
        return NO; //no need to save the context
    }
}

- (void)saveNewKey:(DMaybeOpaqueKey *)key
            atPath:(NSIndexPath *)path
        withStatus:(DSIdentityKeyStatus)status
fromDerivationPath:(DSDerivationPath *)derivationPath
         inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        if ([self createNewKey:key forIdentityEntity:identityEntity atPath:path withStatus:status fromDerivationPath:derivationPath inContext:context])
            [context ds_save];
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self,
            DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
        }];
    }];
}

- (void)saveNewRemoteIdentityKey:(DMaybeOpaqueKey *)key
               forKeyWithIndexID:(uint32_t)keyID
                      withStatus:(DSIdentityKeyStatus)status
                       inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal == FALSE, @"This should only be called on non local identities");
    if (self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:context matching:@"blockchainIdentity == %@ && keyID == %@", identityEntity, @(keyID)];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity *keyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
            // TODO: migrate OpaqueKey/KeyKind to KeyType
            keyPathEntity.keyType = dash_spv_platform_identity_manager_opaque_key_to_key_type_index(key->ok);
            keyPathEntity.keyStatus = status;
            keyPathEntity.keyID = keyID;
            keyPathEntity.publicKeyData = [DSKeyManager publicKeyData:key->ok];
            [identityEntity addKeyPathsObject:keyPathEntity];
            [context ds_save];
        }
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self,
            DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
        }];
    }];
}


- (void)updateStatus:(DSIdentityKeyStatus)status
        forKeyAtPath:(NSIndexPath *)path
  fromDerivationPath:(DSDerivationPath *)derivationPath
           inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal, @"This should only be called on local identities");
    if (!self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:context];
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@", identityEntity, derivationPathEntity, path] firstObject];
        if (keyPathEntity && (keyPathEntity.keyStatus != status)) {
            keyPathEntity.keyStatus = status;
            [context ds_save];
        }
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self,
            DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
        }];
    }];
}

- (void)updateStatus:(DSIdentityKeyStatus)status
   forKeyWithIndexID:(uint32_t)keyID
           inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal == FALSE, @"This should only be called on non local identities");
    if (self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == NULL && keyID == %@", identityEntity, @(keyID)] firstObject];
        if (keyPathEntity) {
            DSBlockchainIdentityKeyPathEntity *keyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
            keyPathEntity.keyStatus = status;
            [context ds_save];
        }
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self,
            DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
        }];
    }];
}

// MARK: Deletion

- (void)deletePersistentObjectAndSave:(BOOL)save
                            inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        if (identityEntity) {
            NSSet<DSFriendRequestEntity *> *friendRequests = [identityEntity.matchingDashpayUser outgoingRequests];
            for (DSFriendRequestEntity *friendRequest in friendRequests) {
                uint32_t accountNumber = friendRequest.account.index;
                DSAccount *account = [self.wallet accountWithNumber:accountNumber];
                [account removeIncomingDerivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
            }
            [identityEntity deleteObjectAndWait];
            if (save)
                [context ds_save];
        }
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self
        }];
    }];
}

// MARK: Entity

- (DSBlockchainIdentityEntity *)identityEntity {
    return [self identityEntityInContext:[NSManagedObjectContext viewContext]];
}

- (DSBlockchainIdentityEntity *)identityEntityInContext:(NSManagedObjectContext *)context {
    __block DSBlockchainIdentityEntity *entity = nil;
    [context performBlockAndWait:^{
        entity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@", self.uniqueIDData];
    }];
    NSAssert(entity, @"An entity should always be found");
    return entity;
}

- (DSDashpayUserEntity *)matchingDashpayUserInViewContext {
    if (!_matchingDashpayUserInViewContext) {
        _matchingDashpayUserInViewContext = [self matchingDashpayUserInContext:[NSManagedObjectContext viewContext]];
    }
    return _matchingDashpayUserInViewContext;
}

- (DSDashpayUserEntity *)matchingDashpayUserInPlatformContext {
    if (!_matchingDashpayUserInPlatformContext) {
        _matchingDashpayUserInPlatformContext = [self matchingDashpayUserInContext:[NSManagedObjectContext platformContext]];
    }
    return _matchingDashpayUserInPlatformContext;
}

- (DSDashpayUserEntity *)matchingDashpayUserInContext:(NSManagedObjectContext *)context {
    if (_matchingDashpayUserInViewContext || _matchingDashpayUserInPlatformContext) {
        if (context == [_matchingDashpayUserInPlatformContext managedObjectContext]) return _matchingDashpayUserInPlatformContext;
        if (context == [_matchingDashpayUserInViewContext managedObjectContext]) return _matchingDashpayUserInViewContext;
        if (_matchingDashpayUserInPlatformContext) {
            __block NSManagedObjectID *managedId;
            [[NSManagedObjectContext platformContext] performBlockAndWait:^{
                managedId = _matchingDashpayUserInPlatformContext.objectID;
            }];
            return [context objectWithID:managedId];
        } else {
            __block NSManagedObjectID *managedId;
            [[NSManagedObjectContext viewContext] performBlockAndWait:^{
                managedId = _matchingDashpayUserInViewContext.objectID;
            }];
            return [context objectWithID:managedId];
        }
    } else {
        __block DSDashpayUserEntity *dashpayUserEntity = nil;
        [context performBlockAndWait:^{
            dashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentity.uniqueID == %@", uint256_data(self.uniqueID)];
        }];
        return dashpayUserEntity;
    }
}

- (void)notifyUpdate:(NSDictionary *_Nullable)userInfo {
    [self notify:DSIdentityDidUpdateNotification userInfo:userInfo];
}

- (BOOL)isDefault {
    return self.wallet.defaultIdentity == self;
}


- (NSString *)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@-%@}", self.currentDashpayUsername, self.uniqueIdString]];
}

@end
