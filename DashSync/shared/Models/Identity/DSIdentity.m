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
#import "DSTransactionOutput+FFI.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSWallet+Identity.h"
#import "NSData+Encryption.h"
#import "NSDate+Utils.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSIndexPath+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
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
    DSIdentityKeyDictionary_KeyLevel = 3,
    DSIdentityKeyDictionary_KeyPurpose = 4,
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

@property (nonatomic, assign) uint64_t creditBalance;
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

- (void)dealloc {
    if (_internalRegistrationFundingPrivateKey != NULL)
        DMaybeOpaqueKeyDtor(_internalRegistrationFundingPrivateKey);
    if (_internalTopupFundingPrivateKey != NULL)
        DMaybeOpaqueKeyDtor(_internalTopupFundingPrivateKey);
    // TODO: identity_model dtor
//    if [(_identity_model != NULL)
//        TODO::// NO
}
// MARK: - Initialization

- (instancetype)initWithUniqueId:(UInt256)uniqueId
                     isTransient:(BOOL)isTransient
                         onChain:(DSChain *)chain {
    //this is the initialization of a non local identity
    if (!(self = [super init])) return nil;
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    _uniqueID = uniqueId;
    _isLocal = FALSE;
    _isTransient = isTransient;
    _keysCreated = 0;
    _currentMainKeyIndex = 0;
    _currentMainKeyType = DKeyKindECDSA();
    self.identity_model = dash_spv_platform_identity_model_IdentityModel_new(DIdentityRegistrationStatusRegistered());
    self.chain = chain;
    return self;
}

- (instancetype)initWithIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initWithUniqueId:entity.uniqueID.UInt256
                            isTransient:FALSE
                                onChain:entity.chain.chain])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initAtIndex:index
                withLockedOutpoint:lockedOutpoint
                          inWallet:wallet])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
               withUniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initAtIndex:index
                      withUniqueId:uniqueId
                          inWallet:wallet])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity
     associatedToInvitation:(DSInvitation *)invitation {
    if (!(self = [self initAtIndex:index
                withLockedOutpoint:lockedOutpoint
                          inWallet:wallet])) return nil;
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
    self.identity_model = dash_spv_platform_identity_model_IdentityModel_new(dash_spv_platform_identity_model_IdentityRegistrationStatus_Unknown_ctor());
    self.chain = wallet.chain;
    return self;
}

- (void)saveProfileTimestamp {
    [self.platformContext performBlockAndWait:^{
        self.lastCheckedProfileTimestamp = [NSDate timeIntervalSince1970];
        //[self saveInContext:self.platformContext];
    }];
}

- (void)registerKeyFromKeyPathEntity:(DSBlockchainIdentityKeyPathEntity *)entity {
    DKeyKind *keyType = DKeyKindFromIndex(entity.keyType);
    DMaybeOpaqueKey *key = DMaybeOpaqueKeyWithPublicKeyData(keyType, slice_ctor(entity.publicKeyData));
    DSecurityLevel *level = DSecurityLevelFromIndex(entity.securityLevel);
    DPurpose *purpose = DPurposeFromIndex(entity.purpose);
    _keysCreated = MAX(self.keysCreated, entity.keyID + 1);
    [self addKeyInfo:key->ok
                type:keyType
       securityLevel:level
             purpose:purpose
              status:DIdentityKeyStatusFromIndex(entity.keyStatus)
               index:entity.keyID];
}
- (void)applyIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity {
    [self applyUsernameEntitiesFromIdentityEntity:identityEntity];
    _creditBalance = identityEntity.creditBalance;
    DIdentityModelSetStatus(self.identity_model, DIdentityRegistrationStatusFromIndex(identityEntity.registrationStatus));
    _lastCheckedProfileTimestamp = identityEntity.lastCheckedProfileTimestamp;
    _lastCheckedUsernamesTimestamp = identityEntity.lastCheckedUsernamesTimestamp;
    _lastCheckedIncomingContactsTimestamp = identityEntity.lastCheckedIncomingContactsTimestamp;
    _lastCheckedOutgoingContactsTimestamp = identityEntity.lastCheckedOutgoingContactsTimestamp;
    
    self.dashpaySyncronizationBlockHash = identityEntity.dashpaySyncronizationBlockHash.UInt256;
    for (DSBlockchainIdentityKeyPathEntity *keyPathEntity in identityEntity.keyPaths) {
        NSIndexPath *keyIndexPath = (NSIndexPath *)[keyPathEntity path];
        DKeyKind *keyType = DKeyKindFromIndex(keyPathEntity.keyType);
        BOOL added = NO;
        if (keyIndexPath) {
            DSecurityLevel *level = DSecurityLevelFromIndex(keyPathEntity.securityLevel);
            DPurpose *purpose = DPurposeFromIndex(keyPathEntity.purpose);
            DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:keyType];
            NSIndexPath *nonhardenedPath = [keyIndexPath softenAllItems];
            NSIndexPath *hardenedPath = [nonhardenedPath hardenAllItems];
            DMaybeOpaqueKey *key = [derivationPath publicKeyAtIndexPath:hardenedPath];
            if (key->ok) {
                uint32_t index = (uint32_t)[nonhardenedPath indexAtPosition:[nonhardenedPath length] - 1];
                _keysCreated = MAX(self.keysCreated, index + 1);
                DKeyInfo *key_info = dash_spv_platform_identity_model_KeyInfo_ctor(key->ok, keyType, DIdentityKeyStatusFromIndex(keyPathEntity.keyStatus), level, purpose);
                dash_spv_platform_identity_model_IdentityModel_add_key_info(self.identity_model, index, key_info);
                added = YES;
            }
        }
        if (!added)
            [self registerKeyFromKeyPathEntity:keyPathEntity];
    }
    if (self.isLocal || self.isOutgoingInvitation) {
        if (identityEntity.registrationFundingTransaction) {
            self.registrationAssetLockTransactionHash = identityEntity.registrationFundingTransaction.transactionHash.txHash.UInt256;
            DSLog(@"%@ AssetLockTX: Entity Attached: txHash: %@: entity: %@", self.logPrefix, uint256_hex(self.registrationAssetLockTransactionHash), identityEntity.registrationFundingTransaction);
        } else {
            NSData *transactionHashData = uint256_data(uint256_reverse(self.lockedOutpoint.hash));
            DSLog(@"%@ AssetLockTX: Load: lockedOutpoint: %@: %lu %@", self.logPrefix, uint256_hex(self.lockedOutpoint.hash), self.lockedOutpoint.n, transactionHashData.hexString);
            DSAssetLockTransactionEntity *assetLockEntity = [DSAssetLockTransactionEntity anyObjectInContext:identityEntity.managedObjectContext matching:@"transactionHash.txHash == %@", transactionHashData];
            if (assetLockEntity) {
                self.registrationAssetLockTransactionHash = assetLockEntity.transactionHash.txHash.UInt256;
                DSLog(@"%@ AssetLockTX: Entity Found for txHash: %@", self.logPrefix, uint256_hex(self.registrationAssetLockTransactionHash));
                DSAssetLockTransaction *registrationAssetLockTransaction = (DSAssetLockTransaction *)[assetLockEntity transactionForChain:self.chain];
                BOOL correctIndex = self.isOutgoingInvitation ?
                    [registrationAssetLockTransaction checkInvitationDerivationPathIndexForWallet:self.wallet isIndex:self.index] :
                    [registrationAssetLockTransaction checkDerivationPathIndexForWallet:self.wallet isIndex:self.index];
                if (!correctIndex) {
                    DSLog(@"%@ AssetLockTX: IncorrectIndex %u (%@)", self.logPrefix, self.index, registrationAssetLockTransaction.toData.hexString);
                    //NSAssert(FALSE, @"We should implement this");
                }
            }
        }
    }
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
    DSLog(@"%@ initAtIndex: %u lockedOutpoint: %@: %lu", self.logPrefix, index, uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
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
    self.identity_model = dash_spv_platform_identity_model_IdentityModel_new(DIdentityRegistrationStatusRegistered());
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
        if (dash_spv_platform_identity_model_IdentityModel_confirmed_username_full_paths_count(self.identity_model))
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
                                 completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *error))completion {
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
                                   completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    __block DSIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    if (!(steps & DSIdentityRegistrationStep_Username)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    [self registerUsernamesWithCompletion:^(BOOL success, NSArray<NSError *> *errors) {
        if (!success) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, errors); });
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
                                  completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    __block DSIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    if (!(steps & DSIdentityRegistrationStep_Identity)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    [self createAndPublishRegistrationTransitionWithCompletion:^(BOOL success, NSError *_Nullable error) {
        if (error) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[error]); });
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
                          completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
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
                          completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    if (!self.registrationAssetLockTransaction) {
        [self registerOnNetwork:steps
             withFundingAccount:fundingAccount
                 forTopupAmount:topupDuffAmount
                      pinPrompt:prompt
                 stepCompletion:stepCompletion
                     completion:completion];
    } else if (dash_spv_platform_identity_model_IdentityModel_is_registered(self.identity_model)) {
        [self continueRegisteringIdentityOnNetwork:steps
                                    stepsCompleted:DSIdentityRegistrationStep_L1Steps
                                    stepCompletion:stepCompletion
                                        completion:completion];
    } else if (dash_spv_platform_identity_model_IdentityModel_unregistered_username_full_paths_count(self.identity_model)) {
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
               completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    DSLog(@"%@ Register On Network: %@", self.logPrefix, DSRegistrationStepsDescription(steps));
    __block DSIdentityRegistrationStep stepsCompleted = DSIdentityRegistrationStep_None;
    if (![self hasIdentityExtendedPublicKeys]) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_REGISTER_KEYS_BEFORE_IDENTITY]); });
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
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_FUNDING_TX_CREATION]); });
        return;
    }
    [fundingAccount signTransaction:assetLockTransaction
                         withPrompt:prompt
                         completion:^(BOOL signedTransaction, BOOL cancelled) {
        if (!signedTransaction) {
            if (completion)
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (cancelled) stepsCompleted |= DSIdentityRegistrationStep_Cancelled;
                    completion(stepsCompleted, cancelled ? nil : @[ERROR_FUNDING_TX_SIGNING]);
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
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_FUNDING_TX_TIMEOUT]); });
                return;
            }
            if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_FundingTransactionAccepted); });
            stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionAccepted;
            if (!instantSendLock) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_FUNDING_TX_ISD_TIMEOUT]); });
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
    DSLog(@"%@ Register In Wallet (AssetLockTx Register): txHash: %@: creditBurnIdentityID: %@, creditBurnPublicKeyHash: %@, lockedOutpoint: %@: %lu", self.logPrefix, uint256_hex(transaction.txHash), uint256_hex(creditBurnIdentityIdentifier), uint160_hex(transaction.creditBurnPublicKeyHash), uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
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
    DSLog(@"%@ Register In Wallet (AssetLockTx TopUp): txHash: %@: creditBurnIdentityID: %@, creditBurnPublicKeyHash: %@, lockedOutpoint: %@: %lu", self.logPrefix, uint256_hex(transaction.txHash), uint256_hex(creditBurnIdentityIdentifier), uint160_hex(transaction.creditBurnPublicKeyHash), uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
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
    BOOL loaded = YES;
    DKeyInfoDictionaries *key_infos = DGetRegisteredKeyInfoDictionaries(self.identity_model);
    for (uint32_t index = 0; index < key_infos->count; index++) {
        DKeyInfo *key_info = key_infos->values[index];
        loaded &= !_isLocal ? NO : hasKeychainData([self identifierForKeyAtPath:[self indexPathForIndex:key_infos->keys[index]] fromDerivationPath:[self derivationPathForType:key_info->key_type]], error);
        if (*error) {
            DKeyInfoDictionariesDtor(key_infos);
            return NO;
        }
    }
    DKeyInfoDictionariesDtor(key_infos);
    return loaded;
}

- (uintptr_t)activeKeyCount {
    return dash_spv_platform_identity_model_IdentityModel_active_key_count(self.identity_model);
}

- (uintptr_t)totalKeyCount {
    return dash_spv_platform_identity_model_IdentityModel_total_key_count(self.identity_model);
}

- (BOOL)verifyKeysForWallet:(DSWallet *)wallet {
    DSWallet *originalWallet = self.wallet;
    self.wallet = wallet;
    DKeyInfoDictionaries *key_info_dictionaries = DGetKeyInfoDictionaries(self.identity_model);
    for (uint32_t index = 0; index < key_info_dictionaries->count; index++) {
        DKeyInfo *key_info = key_info_dictionaries->values[index];
        if (!key_info->key) {
            self.wallet = originalWallet;
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return NO;
        }
        DOpaqueKey *key = [self keyAtIndex:index];
        DKeyKind *key_kind = key_info->key_type;
        BOOL hasSameKind = DOpaqueKeyHasKind(key, key_kind);
        if (!hasSameKind) {
            self.wallet = originalWallet;
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return NO;
        }
        DMaybeOpaqueKey *derivedKey = [self publicKeyAtIndex:index ofType:key_kind];
        if (!derivedKey || !derivedKey->ok) {
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return NO;
        }
        BOOL isEqual = [DSKeyManager keysPublicKeyDataIsEqual:derivedKey->ok key2:key];
        DMaybeOpaqueKeyDtor(derivedKey);
        if (!isEqual) {
            self.wallet = originalWallet;
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return NO;
        }
    }
    DKeyInfoDictionariesDtor(key_info_dictionaries);
    return TRUE;
}

- (DIdentityKeyStatus *)statusOfKeyAtIndex:(NSUInteger)index {
    return dash_spv_platform_identity_model_IdentityModel_status_of_key_at_index(self.identity_model, (uint32_t) index);
}

- (DOpaqueKey *_Nullable)keyAtIndex:(NSUInteger)index {
    return dash_spv_platform_identity_model_IdentityModel_key_at_index(self.identity_model, (uint32_t) index);
}

- (NSString *)localizedStatusOfKeyAtIndex:(NSUInteger)index {
    return [[self class] localizedStatusOfKeyForIdentityKeyStatus:[self statusOfKeyAtIndex:index]];
}

+ (NSString *)localizedStatusOfKeyForIdentityKeyStatus:(DIdentityKeyStatus *)status {
    char *str = dash_spv_platform_identity_model_IdentityKeyStatus_string(status);
    char *desc = dash_spv_platform_identity_model_IdentityKeyStatus_string_description(status);
    NSString *localizedStatus = DSLocalizedString(NSStringFromPtr(str), NSStringFromPtr(desc));
    DCharDtor(str);
    DCharDtor(desc);
    return localizedStatus;
}

- (DSAuthenticationKeysDerivationPath *)derivationPathForType:(DKeyKind *)type {
    if (!_isLocal) return nil;
    // TODO: ed25519 + bls basic
    int16_t index = DKeyKindIndex(type);
    switch (index) {
        case dash_spv_crypto_keys_key_KeyKind_ECDSA:
            return [[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:self.wallet];
        case dash_spv_crypto_keys_key_KeyKind_BLS:
        case dash_spv_crypto_keys_key_KeyKind_BLSBasic:
            return [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:self.wallet];
        default:
            return nil;
    }
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

- (DMaybeOpaqueKey *_Nullable)publicKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type {
    if (!_isLocal) return nil;
    NSIndexPath *hardenedIndexPath = [self indexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
}

- (DMaybeOpaqueKey *)createNewKeyOfType:(DKeyKind *)type
                          securityLevel:(DSecurityLevel *)security_level
                                purpose:(DPurpose *)purpose
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
    [self addKeyInfo:publicKey->ok
                type:type
       securityLevel:security_level
             purpose:purpose
              status:dash_spv_platform_identity_model_IdentityKeyStatus_Registering_ctor()
               index:keyIndex];
    if (saveKey)
        [self saveNewKey:publicKey->ok
                  atPath:hardenedIndexPath
              withStatus:dash_spv_platform_identity_model_IdentityKeyStatus_Registering_ctor()
       withSecurityLevel:security_level
             withPurpose:purpose
      fromDerivationPath:derivationPath
               inContext:[NSManagedObjectContext viewContext]];
    return publicKey;
}


- (uint32_t)firstIndexOfKeyOfType:(DKeyKind *)type
               createIfNotPresent:(BOOL)createIfNotPresent
                          saveKey:(BOOL)saveKey {
    DKeyInfoDictionaries *key_info_dictionaries = DGetKeyInfoDictionaries(self.identity_model);
    for (uint32_t index = 0; index < key_info_dictionaries->count; index++) {
        uint32_t key_info_index = key_info_dictionaries->keys[index];
        DKeyInfo *key_info = key_info_dictionaries->values[index];
        DKeyKind *key_type = key_info->key_type;
        if (DKeyKindIndex(key_type) == DKeyKindIndex(type)) {
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return key_info_index;
        }
    }
    DKeyInfoDictionariesDtor(key_info_dictionaries);
    if (_isLocal && createIfNotPresent) {
        uint32_t rIndex;
        [self createNewKeyOfType:type
                   securityLevel:DSecurityLevelMaster()
                         purpose:DPurposeAuth()
                         saveKey:saveKey
                     returnIndex:&rIndex];
        return rIndex;
    } else {
        return UINT32_MAX;
    }
}

- (DIdentityPublicKey *_Nullable)firstIdentityPublicKeyOfSecurityLevel:(DSecurityLevel *)security_level
                                                            andPurpose:(DPurpose *)purpose {
    return dash_spv_platform_identity_model_IdentityModel_first_identity_public_key(self.identity_model, security_level, purpose);
}

- (void)addKey:(DOpaqueKey *)key
 securityLevel:(DSecurityLevel *)security_level
       purpose:(DPurpose *)purpose
       atIndex:(uint32_t)index
    withStatus:(DIdentityKeyStatus *)status
          save:(BOOL)save
     inContext:(NSManagedObjectContext *)context {
    DKeyKind *type = DOpaqueKeyKind(key);
    DSLogPrivate(@"Identity (local: %u) add key: %p at %u of %u with %lu", self.isLocal, key, index, DKeyKindIndex(type), (unsigned long)status);
    if (self.isLocal) {
        [self addKey:key
       securityLevel:security_level
             purpose:purpose
         atIndexPath:[NSIndexPath indexPathWithIndexes:(const NSUInteger[]){_index, index} length:2]
              ofType:type
          withStatus:status
                save:save
           inContext:context];
    } else {
        DKeyInfo *key_info = DKeyInfoAtIndex(self.identity_model, index);
        if (key_info) {
            DOpaqueKey *maybe_opaque_key = key_info->key;
            DIdentityKeyStatus *keyToCheckInDictionaryStatus = key_info->key_status;
            if (maybe_opaque_key && [DSKeyManager keysPublicKeyDataIsEqual:maybe_opaque_key key2:key]) {
                if (save && status != keyToCheckInDictionaryStatus)
                    [self updateStatus:status forKeyWithIndexID:index inContext:context];
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSLog(@"these should really match up");
                DKeyInfoDtor(key_info);
                return;
            }
        } else {
            _keysCreated = MAX(self.keysCreated, index + 1);
            if (save)
                [self saveNewRemoteIdentityKey:key
                             forKeyWithIndexID:index
                                    withStatus:status
                             withSecurityLevel:security_level
                                   withPurpose:purpose
                                     inContext:context];
        }
        [self addKeyInfo:key type:type securityLevel:security_level purpose:purpose status:status index:index];
        if (key_info)
            DKeyInfoDtor(key_info);
    }
}

- (void)addKey:(DOpaqueKey *)key
 securityLevel:(DSecurityLevel *)security_level
       purpose:(DPurpose *)purpose
   atIndexPath:(NSIndexPath *)indexPath
        ofType:(DKeyKind *)type
    withStatus:(DIdentityKeyStatus *)status
          save:(BOOL)save
     inContext:(NSManagedObjectContext *_Nullable)context {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal) return;
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    //derivationPath will be nil if not local
    
    DMaybeOpaqueKey *keyToCheck = [derivationPath publicKeyAtIndexPath:[indexPath hardenAllItems]];
    NSAssert(keyToCheck != nil && keyToCheck->ok, @"This key should be found");
    if ([DSKeyManager keysPublicKeyDataIsEqual:keyToCheck->ok key2:key]) { //if it isn't local we shouldn't verify
        uint32_t index = (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1];
        DKeyInfo *key_info = DKeyInfoAtIndex(self.identity_model, index);

        if (key_info) {
            if (key_info->key && [DSKeyManager keysPublicKeyDataIsEqual:key_info->key key2:key]) {
                if (save)
                    [self updateStatus:status
                          forKeyAtPath:indexPath
                    fromDerivationPath:derivationPath
                             inContext:context];
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSLog(@"these should really match up");
                DKeyInfoDtor(key_info);
                return;
            }
        } else {
            _keysCreated = MAX(self.keysCreated, index + 1);
            if (save)
                [self saveNewKey:key
                          atPath:indexPath
                      withStatus:status
               withSecurityLevel:security_level
                     withPurpose:purpose
              fromDerivationPath:derivationPath
                       inContext:context];
        }
        [self addKeyInfo:key
                    type:type
           securityLevel:security_level
                 purpose:purpose
                  status:status
                   index:index];
        if (key_info)
            DKeyInfoDtor(key_info);
    } else {
        DSLog(@"these should really match up");
    }
}

- (void)addKeyInfo:(DOpaqueKey *)key
              type:(DKeyKind *)type
     securityLevel:(DSecurityLevel *)security_level
           purpose:(DPurpose *)purpose
            status:(DIdentityKeyStatus *)status
             index:(uint32_t)index {
//    DSLogPrivate(@"%@: addKeyInfo: %p %u %hhu %u", self.logPrefix, key, DKeyKindIndex(type), DSecurityLevelIndex(security_level), index);
    DKeyInfo *key_info = dash_spv_platform_identity_model_KeyInfo_ctor(key, type, status, security_level, purpose);
    dash_spv_platform_identity_model_IdentityModel_add_key_info(self.identity_model, index, key_info);
}


// MARK: - Funding

- (NSString *)registrationFundingAddress {
    if (self.registrationAssetLockTransaction) {
        return [DSKeyManager addressFromHash160:self.registrationAssetLockTransaction.creditBurnPublicKeyHash forChain:self.chain];
    } else {
        DSAssetLockDerivationPath *path = self.isOutgoingInvitation
            ? [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet]
            : [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:self.wallet];
        return [path addressAtIndexPath:[NSIndexPath indexPathWithIndex:self.index]];
    }
}


// MARK: Helpers

- (BOOL)isRegistered {
    return dash_spv_platform_identity_model_IdentityModel_is_registered(self.identity_model);
}

- (NSString *)localizedRegistrationStatusString {
    char *status_string = dash_spv_platform_identity_model_IdentityRegistrationStatus_string(self.registrationStatus);
    NSString *status = NSStringFromPtr(status_string);
    DCharDtor(status_string);
    return status;
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
                DIdentityPublicKey *public_key = public_keys->values[k];
                switch (public_key->tag) {
                    case dpp_identity_identity_public_key_IdentityPublicKey_V0: {
                        DKeyID *key_id = public_keys->keys[k];
                        DMaybeOpaqueKey *opaque = DOpaqueKeyFromIdentityPubKey(public_key);
                        [self addKey:opaque->ok
                       securityLevel:public_key->v0->security_level
                             purpose:public_key->v0->purpose
                             atIndex:key_id->_0
                          withStatus:DIdentityKeyStatusRegistered()
                                save:save
                           inContext:context];
                        break;
                    }
                    default:
                        break;
                }
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
    return isLock ? [self createInstantProof:isLock.lock] : [self createChainProof];
}

- (DAssetLockProof *)createInstantProof:(DInstantLock *)isLock {
    uint16_t tx_version = self.registrationAssetLockTransaction.version;
    uint32_t lock_time = self.registrationAssetLockTransaction.lockTime;
    NSArray *inputs = self.registrationAssetLockTransaction.inputs;
    NSUInteger inputsCount = inputs.count;
    DTxIn **tx_inputs = malloc(sizeof(DTxIn *) * inputsCount);
    for (int i = 0; i < inputs.count; i++) {
        DSTransactionInput *o = inputs[i];
        DScriptBuf *script = o.signature ? DScriptBufCtor(bytes_ctor(o.signature)) : o.inScript ? DScriptBufCtor(bytes_ctor(o.inScript)) : NULL;
        DOutPoint *prev_output = DOutPointCtorU(o.inputHash, o.index);
        tx_inputs[i] = DTxInCtor(prev_output, script, o.sequence);
    }
    
    NSArray *outputs = self.registrationAssetLockTransaction.outputs;
    NSUInteger outputsCount = outputs.count;
    DTxOut **tx_outputs = malloc(sizeof(DTxOut *) * outputsCount);
    for (int i = 0; i < outputs.count; i++) {
        DSTransactionOutput *o = outputs[i];
        tx_outputs[i] = [o ffi_malloc];
    }
    uint8_t asset_lock_payload_version = self.registrationAssetLockTransaction.specialTransactionVersion;
    
    NSArray *creditOutputs = self.registrationAssetLockTransaction.creditOutputs;
    NSUInteger creditOutputsCount = creditOutputs.count;
    DTxOut **credit_outputs = malloc(sizeof(DTxOut *) * creditOutputsCount);
    for (int i = 0; i < creditOutputsCount; i++) {
        DSTransactionOutput *o = creditOutputs[i];
        credit_outputs[i] = [o ffi_malloc];
    }

    DTxInputs *input_vec = DTxInputsCtor(inputsCount, tx_inputs);
    DTxOutputs *output_vec = DTxOutputsCtor(outputsCount, tx_outputs);
    DTxOutputs *credit_output_vec = DTxOutputsCtor(creditOutputsCount, credit_outputs);
    uint32_t output_index = (uint32_t ) self.registrationAssetLockTransaction.lockedOutpoint.n;
    
    return dash_spv_platform_transition_instant_proof(output_index, isLock, tx_version, lock_time, input_vec, output_vec, asset_lock_payload_version, credit_output_vec);

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
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ Register Identity using public key (%u: %p) at %u with private key: %p", self.logPrefix, public_key->tag, public_key, index, self.internalRegistrationFundingPrivateKey->ok];
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
    DMaybeIdentity *result = dash_spv_platform_identity_manager_IdentitiesManager_monitor_with_delay(self.chain.sharedRuntime, self.chain.sharedIdentitiesObj, u256_ctor(self.uniqueIDData), DRetryLinear(5), DRaiseIdentityNotFound(), 4);
    
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
    return dash_spv_platform_identity_model_IdentityModel_has_identity_public_key(self.identity_model, identity_public_key);
}

- (BOOL)containsTopupTransaction:(DSAssetLockTransaction *)transaction {
    return [self.topupAssetLockTransactionHashes containsObject:uint256_data(transaction.txHash)];
}

- (void)registerIdentityWithProof2:(DAssetLockProof *)proof
                       public_key:(DIdentityPublicKey *)public_key
                          atIndex:(uint32_t)index
                        completion:(void (^)(BOOL, NSError *_Nullable))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ Register Identity (public key (%u: %p) at %u with private key: %p", self.logPrefix, public_key->tag, public_key, index, self.internalRegistrationFundingPrivateKey->ok];
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
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ TopUp Identity using public key (%u: %p) at %u with private key: %p", self.logPrefix, public_key->tag, public_key, index, self.internalTopupFundingPrivateKey->ok];
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
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ CREATE AND PUBLISH IDENTITY TOPUP TRANSITION", self.logPrefix];
    DSLog(@"%@", debugInfo);
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:self.wallet];
    NSString *topupAddress = [path addressAtIndexPath:[NSIndexPath indexPathWithIndex:self.index]];
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
            DOpaqueKey *publicKey = [self keyAtIndex:index];
            [debugInfo appendFormat:@", public_key: %p", publicKey];
            DSInstantSendTransactionLock *isLock = assetLockTransaction.instantSendLockAwaitingProcessing;
            [debugInfo appendFormat:@", is_lock: %p", isLock];
            if (!isLock && assetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
                DSLog(@"%@: ERROR: Funding Tx Not Mined", debugInfo);
                if (completion) completion(nil, ERROR_FUNDING_TX_NOT_MINED);
                return;
            }
            DIdentityPublicKey *public_key = DIdentityRegistrationPublicKey(index, publicKey);
            DAssetLockProof *proof = [self createProof:isLock];
            DSLog(@"%@ Proof: %u: %p", debugInfo, proof->tag, proof);
            [self topupIdentityWithProof:proof public_key:public_key atIndex:index completion:completion];
        }];

    }];
}

- (void)createAndPublishRegistrationTransitionWithCompletion:(void (^)(BOOL, NSError *))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ CREATE AND PUBLISH IDENTITY REGISTRATION TRANSITION", self.logPrefix];
    DSLog(@"%@", debugInfo);
    if (!self.internalRegistrationFundingPrivateKey) {
        DSLog(@"%@: ERROR: No Funding Private Key", debugInfo);
        if (completion) completion(nil, ERROR_NO_FUNDING_PRV_KEY);
        return;
    }
    uint32_t index = [self firstIndexOfKeyOfType:DKeyKindECDSA() createIfNotPresent:YES saveKey:!self.wallet.isTransient];
    [debugInfo appendFormat:@", index: %u", index];
    DOpaqueKey *publicKey = [self keyAtIndex:index];
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
    DIdentityPublicKey *public_key = DIdentityRegistrationPublicKey(index, publicKey);
    DAssetLockProof *proof = [self createProof:isLock];
    DSLog(@"%@ Proof: %u: %p", debugInfo, proof->tag, proof);
    [self registerIdentityWithProof2:proof public_key:public_key atIndex:index completion:completion];
}

// MARK: Retrieval

- (void)fetchIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success, BOOL found, NSError *error))completion {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch Identity State", self.logPrefix];
    DSLog(@"%@", debugString);
    dispatch_async(self.identityQueue, ^{
        DMaybeIdentity *result = dash_spv_platform_identity_manager_IdentitiesManager_monitor_for_id_bytes(self.chain.sharedRuntime, self.chain.sharedIdentitiesObj, u256_ctor(self.uniqueIDData), DRetryDown50(DEFAULT_FETCH_IDENTITY_RETRY_COUNT), self.isLocal ? DAcceptIdentityNotFound() : DRaiseIdentityNotFound());
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
                    switch (key->tag) {
                        case dpp_identity_identity_public_key_IdentityPublicKey_V0: {
                            DMaybeOpaqueKey *maybe_key = DOpaqueKeyFromIdentityPubKey(key);
                            [self addKey:maybe_key->ok
                           securityLevel:key->v0->security_level
                                 purpose:key->v0->purpose
                                 atIndex:i
                              withStatus:DIdentityKeyStatusRegistered()
                                    save:!self.isTransient
                               inContext:self.platformContext];
                            break;
                        }
                        default:
                            DSLog(@"%@ WARN: Unsupported Identity Public Key Version %u", debugString, key->tag);
                            break;
                    }
                }
                DIdentityModelSetStatus(self.identity_model, DIdentityRegistrationStatusRegistered());
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
    DSLog(@"%@ Fetch L3 State (%@)", self.logPrefix, DSIdentityQueryStepsDescription(queryStep));
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
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ fetchNetworkStateInformation (%@)", self.logPrefix, DSIdentityQueryStepsDescription(querySteps)];
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
                if (!self.dashpayUsernameCount && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
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
            if (!self.dashpayUsernameCount && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS) {
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
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch Needed Network State Info (local: %u, active keys: %lu) ", self.logPrefix, self.isLocal, self.activeKeyCount];
    DSLog(@"%@", debugString);
    dispatch_async(self.identityQueue, ^{
        if (!self.activeKeyCount) {
            if (self.isLocal) {
                [self fetchAllNetworkStateInformationWithCompletion:completion];
            } else {
                DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
                if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Identities)
                    stepsNeeded |= DSIdentityQueryStep_Identity;
                if (!self.dashpayUsernameCount && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
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
            if (!self.dashpayUsernameCount && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
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

- (BOOL)processStateTransitionResult:(DMaybeStateTransitionProofResult *)result {
#if (defined(DPP_STATE_TRANSITIONS))
    dpp_state_transition_proof_result_StateTransitionProofResult *proof_result = result->ok;
    switch (proof_result->tag) {
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedDataContract: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_data_contract->v0->id->_0->_0);
            DSLog(@"%@ VerifiedDataContract: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedIdentity: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_identity->v0->id->_0->_0);
            DSLog(@"%@ VerifiedIdentity: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedPartialIdentity: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_partial_identity->id->_0->_0);
            DSLog(@"%@ VerifiedPartialIdentity: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedBalanceTransfer: {
            dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedBalanceTransfer_Body transfer = proof_result->verified_balance_transfer;
            NSData *from_identifier = NSDataFromPtr(transfer._0->id->_0->_0);
            NSData *to_identifier = NSDataFromPtr(transfer._1->id->_0->_0);
            DSLog(@"%@ VerifiedBalanceTransfer: %@ --> %@", self.logPrefix, from_identifier.hexString, to_identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedDocuments: {
            std_collections_Map_keys_platform_value_types_identifier_Identifier_values_Option_dpp_document_Document *verified_documents = proof_result->verified_documents;
            DSLog(@"%@ VerifiedDocuments: %lu", self.logPrefix, verified_documents->count);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedMasternodeVote: {
            dpp_voting_votes_Vote *verified_masternode_vote = proof_result->verified_masternode_vote;
            DSLog(@"%@ VerifiedMasternodeVote: %u", self.logPrefix, verified_masternode_vote->tag);
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
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch & Update Contract (%lu) ", self.logPrefix, (unsigned long) contract.contractState];
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
                [self createNewKeyOfType:DKeyKindECDSA()
                           securityLevel:DSecurityLevelMaster()
                                 purpose:DPurposeAuth()
                                 saveKey:!self.wallet.isTransient
                             returnIndex:&index];
            }
            DMaybeOpaqueKey *privateKey = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
            
            DMaybeStateTransitionProofResult *state_transition_result = dash_spv_platform_PlatformSDK_data_contract_create2(self.chain.sharedRuntime, self.chain.sharedPlatformObj, data_contracts_SystemDataContract_DPNS_ctor(), u256_ctor_u(self.uniqueID), 0, privateKey->ok);

            if (state_transition_result->error) {
                DSLog(@"%@ ERROR: %@", debugString, [NSError ffi_from_platform_error:state_transition_result->error]);
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                return;
            }
            DSLog(@"%@ OK", debugString);
            if ([self processStateTransitionResult:state_transition_result]) {
                contract.contractState = DPContractState_Registering;
            } else {
                contract.contractState = DPContractState_Unknown;
            }
            [contract saveAndWaitInContext:context];
            
            DMaybeContract *monitor_result = dash_spv_platform_contract_manager_ContractsManager_monitor_for_id_bytes(self.chain.sharedRuntime, self.chain.sharedContractsObj, u256_ctor_u(contract.contractId), DRetryLinear(2), dash_spv_platform_contract_manager_ContractValidator_None_ctor());

            if (monitor_result->error) {
                DMaybeContractDtor(monitor_result);
                DSLog(@"%@ Contract Monitoring Error: %@", self.logPrefix, [NSError ffi_from_platform_error:monitor_result->error]);
                return;
            }
            if (monitor_result->ok) {
                NSData *identifier = NSDataFromPtr(monitor_result->ok->v0->id->_0->_0);
                if ([identifier isEqualToData:uint256_data(contract.contractId)]) {
                    DSLog(@"%@ Contract Monitoring OK", self.logPrefix);
                    contract.contractState = DPContractState_Registered;
                    [contract saveAndWaitInContext:context];
                } else {
                    DSLog(@"%@ Contract Monitoring Error: Ids dont match", self.logPrefix);
                }
            }
            DSLog(@"%@ Contract Monitoring Error", self.logPrefix);

        } else if (contract.contractState == DPContractState_Registered || contract.contractState == DPContractState_Registering) {
            DSLog(@"%@ Fetching contract for verification %@", self.logPrefix, contract.base58ContractId);
            DMaybeContract *contract_result = dash_spv_platform_contract_manager_ContractsManager_fetch_contract_by_id_bytes(self.chain.sharedRuntime, self.chain.sharedContractsObj, u256_ctor_u(contract.contractId));

            dispatch_async(self.identityQueue, ^{
                __strong typeof(weakContract) strongContract = weakContract;
                if (!weakContract || !contract_result) return;
                if (!contract_result->ok) {
                    DSLog(@"%@ Contract Monitoring ERROR: NotRegistered ", self.logPrefix);
                    strongContract.contractState = DPContractState_NotRegistered;
                    [strongContract saveAndWaitInContext:context];
                    DMaybeContractDtor(contract_result);
                    return;
                }
                DSLog(@"%@ Contract Monitoring OK: %@ ", self.logPrefix, strongContract);
                if (strongContract.contractState == DPContractState_Registered && !dash_spv_platform_contract_manager_has_equal_document_type_keys(contract_result->ok, strongContract.raw_contract)) {
                    strongContract.contractState = DPContractState_NotRegistered;
                    [strongContract saveAndWaitInContext:context];
                    //DSLog(@"Contract dictionary is %@", contractDictionary);
                }
                DMaybeContractDtor(contract_result);

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
        DMaybeIdentityBalance *result = dash_spv_platform_identity_manager_IdentitiesManager_fetch_balance_by_id_bytes(strongSelf.chain.sharedRuntime, strongSelf.chain.sharedIdentitiesObj, u256_ctor(self.uniqueIDData));
        if (!result->ok) {
            DSLog(@"%@ Update Credit Balance: ERROR RESULT: %u", self.logPrefix, result->error->tag);
            DMaybeIdentityBalanceDtor(result);
            return;
        }
        uint64_t balance = result->ok[0];
        DMaybeIdentityBalanceDtor(result);
        DSLog(@"%@ Update Credit Balance: OK: %llu", self.logPrefix, balance);
        dispatch_async(self.identityQueue, ^{
            strongSelf.creditBalance = balance;
        });
    });
}


// MARK: Helpers

- (BOOL)isDashpayReady {
    return self.activeKeyCount > 0 && self.isRegistered;
}

- (UInt256)contractIdIfRegistered:(DDataContract *)contract {
    NSMutableData *mData = [NSMutableData data];
    [mData appendUInt256:self.uniqueID];
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identitiesECDSAKeysDerivationPathForWallet:self.wallet];
    Result_ok_Vec_u8_err_dash_spv_platform_error_Error *result = dash_spv_platform_contract_manager_ContractsManager_contract_serialized_hash(self.chain.sharedContractsObj, contract);
    NSData *serializedHash = NSDataFromPtr(result->ok);
    Result_ok_Vec_u8_err_dash_spv_platform_error_Error_destroy(result);
    NSMutableData *entropyData = [serializedHash mutableCopy];
    [entropyData appendUInt256:self.uniqueID];
    [entropyData appendData:[derivationPath publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndex:UINT32_MAX - 1]]]; //use the last key in 32 bit space (it won't probably ever be used anyways)
    [mData appendData:uint256_data([entropyData SHA256])];
    return [mData SHA256_2]; //this is the contract ID
}

- (DIdentityRegistrationStatus *)registrationStatus {
    return dash_spv_platform_identity_model_IdentityModel_registration_status(self.identity_model);
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
    entity.registrationStatus = DIdentityRegistrationStatusIndex(self.identity_model);
    if (self.isLocal)
        entity.registrationFundingTransaction = [DSAssetLockTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.registrationAssetLockTransaction.txHash)];
    entity.chain = chainEntity;
    [self collectUsernameEntitiesIntoIdentityEntityInContext:entity context:context];
    DKeyInfoDictionaries *key_info_dictionaries = DGetKeyInfoDictionaries(self.identity_model);
    
    for (uint32_t index = 0; index < key_info_dictionaries->count; index++) {
        uint32_t key_info_index = key_info_dictionaries->keys[index];
        DKeyInfo *key_info = key_info_dictionaries->values[index];
        DIdentityKeyStatus *status = key_info->key_status;
        DKeyKind *key_type = key_info->key_type;
        DOpaqueKey *key = key_info->key;
        DSecurityLevel *level = key_info->security_level;
        DPurpose *purpose = key_info->purpose;
        DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:key_type];
        const NSUInteger indexes[] = {_index, key_info_index};
        [self createNewKey:key
         forIdentityEntity:entity
                    atPath:[NSIndexPath indexPathWithIndexes:indexes length:2]
                withStatus:status
         withSecurityLevel:level
               withPurpose:purpose
        fromDerivationPath:derivationPath
                 inContext:context];
    }
    DKeyInfoDictionariesDtor(key_info_dictionaries);
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
        
        uint16_t registrationStatus = DIdentityRegistrationStatusIndex(self.identity_model);
        if (entity.registrationStatus != registrationStatus) {
            entity.registrationStatus = registrationStatus;
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

- (BOOL)createNewKey:(DOpaqueKey *)key
   forIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity
              atPath:(NSIndexPath *)path
          withStatus:(DIdentityKeyStatus *)status
          withSecurityLevel:(DSecurityLevel *)security_level
          withPurpose:(DPurpose *)purpose
  fromDerivationPath:(DSDerivationPath *)derivationPath
           inContext:(NSManagedObjectContext *)context {
    NSAssert(identityEntity, @"Entity should be present");
    
    DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:context];
    NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@", identityEntity, derivationPathEntity, path];
    if (!count) {
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
        keyPathEntity.derivationPath = derivationPathEntity;
        // TODO: that's wrong should convert KeyType <-> KeyKind
        keyPathEntity.keyType = DOpaqueKeyToKeyTypeIndex(key);
        keyPathEntity.keyStatus = DIdentityKeyStatusToIndex(status);
        NSData *privateKeyData = [DSKeyManager privateKeyData:key];
        if (!privateKeyData) {
            DKeyKind *kind = DOpaqueKeyKind(key);
            DMaybeOpaqueKey *privateKey = [self derivePrivateKeyAtIndexPath:path ofType:kind];
            NSAssert([DSKeyManager keysPublicKeyDataIsEqual:privateKey->ok key2:key], @"The keys don't seem to match up");
            privateKeyData = [DSKeyManager privateKeyData:privateKey->ok];
            NSAssert(privateKeyData, @"Private key data should exist");
        }
        NSString *identifier = [self identifierForKeyAtPath:path fromDerivationPath:derivationPath];
        setKeychainData(privateKeyData, identifier, YES);

        keyPathEntity.path = path;
        keyPathEntity.publicKeyData = [DSKeyManager publicKeyData:key];
        keyPathEntity.keyID = (uint32_t)[path indexAtPosition:path.length - 1];
        keyPathEntity.securityLevel = DSecurityLevelIndex(security_level);
        keyPathEntity.purpose = DPurposeIndex(purpose);
        [identityEntity addKeyPathsObject:keyPathEntity];
        return YES;
    } else {
        return NO; //no need to save the context
    }
}

- (void)saveNewKey:(DOpaqueKey *)key
            atPath:(NSIndexPath *)path
        withStatus:(DIdentityKeyStatus *)status
 withSecurityLevel:(DSecurityLevel *)security_level
       withPurpose:(DPurpose *)purpose
fromDerivationPath:(DSDerivationPath *)derivationPath
         inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        if ([self createNewKey:key
             forIdentityEntity:identityEntity
                        atPath:path
                    withStatus:status
             withSecurityLevel:security_level
                   withPurpose:purpose
            fromDerivationPath:derivationPath
                     inContext:context])
            [context ds_save];
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self,
            DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
        }];
    }];
}

- (void)saveNewRemoteIdentityKey:(DOpaqueKey *)key
               forKeyWithIndexID:(uint32_t)keyID
                      withStatus:(DIdentityKeyStatus *)status
               withSecurityLevel:(DSecurityLevel *)security_level
                     withPurpose:(DPurpose *)purpose
                       inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal == FALSE, @"This should only be called on non local identities");
    if (self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:context matching:@"blockchainIdentity == %@ && keyID == %@", identityEntity, @(keyID)];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity *keyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
            // TODO: migrate OpaqueKey/KeyKind to KeyType
            keyPathEntity.keyType = DOpaqueKeyToKeyTypeIndex(key);
            keyPathEntity.keyStatus = DIdentityKeyStatusToIndex(status);
            keyPathEntity.keyID = keyID;
            keyPathEntity.publicKeyData = [DSKeyManager publicKeyData:key];
            keyPathEntity.securityLevel = DSecurityLevelIndex(security_level);
            keyPathEntity.purpose = DPurposeIndex(purpose);
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


- (void)updateStatus:(DIdentityKeyStatus *)status
        forKeyAtPath:(NSIndexPath *)path
  fromDerivationPath:(DSDerivationPath *)derivationPath
           inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal, @"This should only be called on local identities");
    if (!self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:context];
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@", identityEntity, derivationPathEntity, path] firstObject];
        uint16_t keyStatus = DIdentityKeyStatusToIndex(status);
        if (keyPathEntity && (keyPathEntity.keyStatus != keyStatus)) {
            keyPathEntity.keyStatus = keyStatus;
            [context ds_save];
        }
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self,
            DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
        }];
    }];
}

- (void)updateStatus:(DIdentityKeyStatus *)status
   forKeyWithIndexID:(uint32_t)keyID
           inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal == FALSE, @"This should only be called on non local identities");
    if (self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == NULL && keyID == %@", identityEntity, @(keyID)] firstObject];
        if (keyPathEntity) {
            DSBlockchainIdentityKeyPathEntity *keyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
            keyPathEntity.keyStatus = DIdentityKeyStatusToIndex(status);
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

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [Identity: %@]", self.chain.name, uint256_hex(self.uniqueID)];
}


@end
