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
#import "DSTransition.h"
#import "DSWallet+Identity.h"
#import "NSData+Encryption.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSIndexPath+Dash.h"
#import "NSManagedObject+Sugar.h"

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

@interface DSIdentity ()

@property (nonatomic, assign) UInt256 uniqueID;
@property (nonatomic, assign) BOOL isOutgoingInvitation;
@property (nonatomic, assign) BOOL isFromIncomingInvitation;
@property (nonatomic, assign) DSUTXO lockedOutpoint;
@property (nonatomic, assign) uint32_t index;
@property (nonatomic, assign) DSIdentityRegistrationStatus registrationStatus;
@property (nonatomic, assign) uint64_t creditBalance;
//@property (nonatomic, assign) uint32_t keysCreated;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDictionary *> *keyInfoDictionaries;
//@property (nonatomic, assign) uint32_t currentMainKeyIndex;
@property (nonatomic, strong) DSDashpayUserEntity *matchingDashpayUserInViewContext;
@property (nonatomic, strong) DSDashpayUserEntity *matchingDashpayUserInPlatformContext;
@property (nonatomic, assign) DMaybeOpaqueKey *internalRegistrationFundingPrivateKey;
@property (nonatomic, assign) UInt256 dashpaySyncronizationBlockHash;
@property (nonatomic, strong) DSAssetLockTransaction *registrationAssetLockTransaction;
@property (nonatomic, assign) uint64_t lastCheckedUsernamesTimestamp;
@property (nonatomic, assign) uint64_t lastCheckedProfileTimestamp;

@end

@implementation DSIdentity

- (void)dealloc {
    if (_internalRegistrationFundingPrivateKey != NULL) {
        DMaybeOpaqueKeyDtor(_internalRegistrationFundingPrivateKey);
    }
//    if (_transientDashpayUser)
//        DMaybeTransientUserDtor(_transientDashpayUser);
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
    _currentMainKeyType = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
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
        self.lastCheckedProfileTimestamp = [[NSDate date] timeIntervalSince1970];
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
    for (DSBlockchainIdentityKeyPathEntity *keyPath in identityEntity.keyPaths) {
        NSIndexPath *keyIndexPath = (NSIndexPath *)[keyPath path];
        
        DKeyKind *keyType = dash_spv_crypto_keys_key_key_kind_from_index(keyPath.keyType);
        if (keyIndexPath) {
            BOOL success = [self registerKeyWithStatus:keyPath.keyStatus atIndexPath:[keyIndexPath softenAllItems] ofType:keyType];
            if (!success)
                [self registerKeyFromKeyPathEntity:keyPath];
        } else {
            [self registerKeyFromKeyPathEntity:keyPath];
        }
    }
    if (self.isLocal || self.isOutgoingInvitation) {
        if (identityEntity.registrationFundingTransaction) {
            self.registrationAssetLockTransactionHash = identityEntity.registrationFundingTransaction.transactionHash.txHash.UInt256;
        } else {
            NSData *transactionHashData = uint256_data(uint256_reverse(self.lockedOutpoint.hash));
            DSTransactionEntity *assetLockEntity = [DSTransactionEntity anyObjectInContext:identityEntity.managedObjectContext matching:@"transactionHash.txHash == %@", transactionHashData];
            if (assetLockEntity) {
                self.registrationAssetLockTransactionHash = assetLockEntity.transactionHash.txHash.UInt256;
                
                DSAssetLockTransaction *registrationAssetLockTransaction = (DSAssetLockTransaction *)[assetLockEntity transactionForChain:self.chain];
                BOOL correctIndex;
                if (self.isOutgoingInvitation) {
                    correctIndex = [registrationAssetLockTransaction checkInvitationDerivationPathIndexForWallet:self.wallet isIndex:self.index];
                } else {
                    correctIndex = [registrationAssetLockTransaction checkDerivationPathIndexForWallet:self.wallet isIndex:self.index];
                }
                if (!correctIndex) {
                    NSAssert(FALSE, @"We should implement this");
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
    self.currentMainKeyType = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
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
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
     withUsernameDictionary:(NSDictionary<NSString *, NSDictionary *> *_Nullable)usernameDictionary
              havingCredits:(uint64_t)credits
         registrationStatus:(DSIdentityRegistrationStatus)registrationStatus
                   inWallet:(DSWallet *)wallet {
    if (!(self = [self initAtIndex:index withAssetLockTransaction:transaction
            withUsernameDictionary:usernameDictionary
                          inWallet:wallet])) return nil;
    self.creditBalance = credits;
    self.registrationStatus = registrationStatus;
    return self;
}

//- (instancetype)initAtIndex:(uint32_t)index
//     withIdentityDictionary:(NSDictionary *)identityDictionary
//                    version:(uint32_t)version
//                   inWallet:(DSWallet *)wallet {
//    NSParameterAssert(wallet);
//    if (!(self = [super init])) return nil;
//    self.wallet = wallet;
//    self.isLocal = YES;
//    self.isOutgoingInvitation = NO;
//    self.isTransient = FALSE;
//    self.keysCreated = 0;
//    self.currentMainKeyIndex = 0;
//    self.currentMainKeyType = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
//    NSData *identityIdData = [identityDictionary objectForKey:@"id"];
//    self.uniqueID = identityIdData.UInt256;
//    self.keyInfoDictionaries = [NSMutableDictionary dictionary];
//    self.registrationStatus = DSIdentityRegistrationStatus_Registered;
//    [self setupUsernames];
//    self.chain = wallet.chain;
//    self.index = index;
//    [self applyIdentityDictionary:identityDictionary version:version save:NO inContext:nil];
//    return self;
//}

- (instancetype)initAtIndex:(uint32_t)index
                   uniqueId:(UInt256)uniqueId
//                    balance:(uint64_t)balance
//                public_keys:(std_collections_Map_keys_dpp_identity_identity_public_key_KeyID_values_dpp_identity_identity_public_key_IdentityPublicKey *)public_keys
                   inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isLocal = YES;
    self.isOutgoingInvitation = NO;
    self.isTransient = FALSE;
    _keysCreated = 0;
    self.currentMainKeyIndex = 0;
    self.currentMainKeyType = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
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
                           pinPrompt:(NSString *)prompt stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
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


- (void)registerOnNetwork:(DSIdentityRegistrationStep)steps
       withFundingAccount:(DSAccount *)fundingAccount
           forTopupAmount:(uint64_t)topupDuffAmount
                pinPrompt:(NSString *)prompt
           stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
               completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSError *error))completion {
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
    DSAssetLockTransaction *assetLockTransaction = [fundingAccount assetLockTransactionFor:topupDuffAmount to:assetLockRegistrationAddress withFee:YES];
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
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        __block BOOL transactionSuccessfullyPublished = FALSE;
        __block DSInstantSendTransactionLock *instantSendLock = nil;
        __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                                object:nil
                                                                                 queue:nil
                                                                            usingBlock:^(NSNotification *note) {
            DSTransaction *tx = [note.userInfo objectForKey:DSTransactionManagerNotificationTransactionKey];
            if ([tx isEqual:assetLockTransaction]) {
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
        [self.chain.chainManager.transactionManager publishTransaction:assetLockTransaction
                                                            completion:^(NSError *_Nullable error) {
            if (error) {
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, error); });
                return;
            }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC));
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                if (!transactionSuccessfullyPublished) {
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
            });
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
        if (completion) {
            completion(YES);
        }
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt
                                                   forWallet:self.wallet
                                                   forAmount:0
                                         forceAuthentication:NO
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
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
        completion(YES);
    }];
}

- (void)registerInWalletForAssetLockTransaction:(DSAssetLockTransaction *)fundingTransaction {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    self.registrationAssetLockTransactionHash = fundingTransaction.txHash;
    self.lockedOutpoint = fundingTransaction.lockedOutpoint;
    [self registerInWalletForIdentityUniqueId:fundingTransaction.creditBurnIdentityIdentifier];
    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [fundingTransaction markAddressAsUsedInWallet:self.wallet];
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

// MARK: - Keys

- (void)createFundingPrivateKeyWithSeed:(NSData *)seed
                        isForInvitation:(BOOL)isForInvitation
                             completion:(void (^_Nullable)(BOOL success))completion {
    DSAssetLockDerivationPath *derivationPathRegistrationFunding;
    if (isForInvitation) {
        derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet];
    } else {
        derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:self.wallet];
    }
    
    self.internalRegistrationFundingPrivateKey = [derivationPathRegistrationFunding privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];
    BOOL ok = self.internalRegistrationFundingPrivateKey;
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok); });
}

- (BOOL)setExternalFundingPrivateKey:(DMaybeOpaqueKey *)privateKey {
    if (!self.isFromIncomingInvitation) {
        return FALSE;
    }
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
                [self createFundingPrivateKeyWithSeed:seed
                                      isForInvitation:isForInvitation
                                           completion:^(BOOL success) {
                    if (completion) completion(success, NO);
                }];
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

- (uint32_t)keyCountForKeyType:(DKeyKind *)keyType {
    uint32_t keyCount = 0;
    for (NSNumber *index in self.keyInfoDictionaries) {
        NSDictionary *keyDictionary = self.keyInfoDictionaries[index];
        DKeyKind *type = [keyDictionary[@(DSIdentityKeyDictionary_KeyType)] pointerValue];
        if (dash_spv_crypto_keys_key_KeyKind_index(type) == dash_spv_crypto_keys_key_KeyKind_index(keyType)) keyCount++;
    }
    return keyCount;
}

- (NSArray *)activeKeysForKeyType:(DKeyKind *)keyType {
    NSMutableArray *activeKeys = [NSMutableArray array];
    for (NSNumber *index in self.keyInfoDictionaries) {
        NSDictionary *keyDictionary = self.keyInfoDictionaries[index];
        DKeyKind *type = [keyDictionary[@(DSIdentityKeyDictionary_KeyType)] pointerValue];
        if (dash_spv_crypto_keys_key_KeyKind_index(type) == dash_spv_crypto_keys_key_KeyKind_index(keyType))
            [activeKeys addObject:keyDictionary[@(DSIdentityKeyDictionary_Key)]];
    }
    return [activeKeys copy];
}

- (BOOL)verifyKeysForWallet:(DSWallet *)wallet {
    DSWallet *originalWallet = self.wallet;
    self.wallet = wallet;
    for (uint32_t index = 0; index < self.keyInfoDictionaries.count; index++) {
        DKeyKind *keyType = [self typeOfKeyAtIndex:index];
        DMaybeOpaqueKey *key = [self keyAtIndex:index];
        NSLog(@"verifyKeysForWallet.1: %u: %p %u", dash_spv_crypto_keys_key_KeyKind_index(keyType), key->ok, key->ok->tag);
        if (!key || !key->ok) {
            self.wallet = originalWallet;
            return FALSE;
        }
        
        if (dash_spv_crypto_keys_key_KeyKind_index(keyType) != (int16_t) key->ok->tag) {
            self.wallet = originalWallet;
            return FALSE;
        }
        DMaybeOpaqueKey *derivedKey = [self publicKeyAtIndex:index ofType:keyType];
        if (!derivedKey || !derivedKey->ok) return NO;
        BOOL isEqual = [DSKeyManager keysPublicKeyDataIsEqual:derivedKey->ok key2:key->ok];
        BYTES *derived = dash_spv_crypto_keys_key_OpaqueKey_public_key_data(derivedKey->ok);
        BYTES *obtained = dash_spv_crypto_keys_key_OpaqueKey_public_key_data(key->ok);
        DSLog(@"equal ? %@ == %@", [DSKeyManager NSDataFrom:derived].hexString, [DSKeyManager NSDataFrom:obtained].hexString);
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

- (DKeyKind *)typeOfKeyAtIndex:(NSUInteger)index {
    return [[[self.keyInfoDictionaries objectForKey:@(index)] objectForKey:@(DSIdentityKeyDictionary_KeyType)] pointerValue];
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
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return hasKeychainData([self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath], error);
}

- (DMaybeOpaqueKey *)privateKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    NSError *error = nil;
    NSData *keySecret = getKeychainData([self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath], &error);
    NSAssert(keySecret, @"This should be present");
    if (!keySecret || error) return nil;
    return [DSKeyManager keyWithPrivateKeyData:keySecret ofType:type];
}

//- (DMaybeOpaqueKey *)derivePrivateKeyAtIdentityKeyIndex:(uint32_t)index ofType:(DKeyKind *)type {
//    if (!_isLocal) return nil;
//    const NSUInteger indexes[] = {_index, index};
//    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
//    return [self derivePrivateKeyAtIndexPath:indexPath ofType:*type];
//}

- (DMaybeOpaqueKey *)derivePrivateKeyAtIndexPath:(NSIndexPath *)indexPath ofType:(DKeyKind *)type {
    if (!_isLocal) return nil;
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath privateKeyAtIndexPath:[indexPath hardenAllItems]];
}

- (DMaybeOpaqueKey *)privateKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type forSeed:(NSData *)seed {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
}

- (DMaybeOpaqueKey *_Nullable)publicKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath *hardenedIndexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
}

- (DMaybeOpaqueKey *)createNewKeyOfType:(DKeyKind *)type
                                saveKey:(BOOL)saveKey
                            returnIndex:(uint32_t *)rIndex {
    if (!_isLocal) return nil;
    uint32_t keyIndex = self.keysCreated;
    const NSUInteger indexes[] = {_index | BIP32_HARD, keyIndex | BIP32_HARD};
    NSIndexPath *hardenedIndexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    DMaybeOpaqueKey *publicKey = [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
    NSAssert([derivationPath hasExtendedPrivateKey], @"The derivation path should have an extended private key");
    DMaybeOpaqueKey *privateKey = [derivationPath privateKeyAtIndexPath:hardenedIndexPath];
    NSAssert(privateKey && privateKey->ok, @"The private key should have been derived");
    NSAssert([DSKeyManager keysPublicKeyDataIsEqual:publicKey->ok key2:privateKey->ok], @"These should be equal");
    _keysCreated++;
    if (rIndex) {
        *rIndex = keyIndex;
    }
    NSDictionary *keyDictionary = @{
        @(DSIdentityKeyDictionary_Key): [NSValue valueWithPointer:publicKey],
        @(DSIdentityKeyDictionary_KeyType): [NSValue valueWithPointer:type],
        @(DSIdentityKeyDictionary_KeyStatus): @(DSIdentityKeyStatus_Registering)
    };
    [self.keyInfoDictionaries setObject:keyDictionary forKey:@(keyIndex)];
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
        if (dash_spv_crypto_keys_key_KeyKind_index(keyType) == dash_spv_crypto_keys_key_KeyKind_index(type)) {
            return [indexNumber unsignedIntValue];
        }
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
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath *hardenedIndexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
}

- (void)addKey:(DMaybeOpaqueKey *)key
       atIndex:(uint32_t)index
        ofType:(DKeyKind *)type
    withStatus:(DSIdentityKeyStatus)status
          save:(BOOL)save {
    [self addKey:key atIndex:index ofType:type withStatus:status save:save inContext:self.platformContext];
}

- (void)addKey:(DMaybeOpaqueKey *)key
       atIndex:(uint32_t)index
        ofType:(DKeyKind *)type
    withStatus:(DSIdentityKeyStatus)status
          save:(BOOL)save
     inContext:(NSManagedObjectContext *)context {
    if (self.isLocal) {
        const NSUInteger indexes[] = {_index, index};
        NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
        [self addKey:key atIndexPath:indexPath ofType:type withStatus:status save:save inContext:context];
    } else {
        if (self.keyInfoDictionaries[@(index)]) {
            NSDictionary *keyDictionary = self.keyInfoDictionaries[@(index)];
            NSValue *keyToCheckInDictionary = keyDictionary[@(DSIdentityKeyDictionary_Key)];
            DSIdentityKeyStatus keyToCheckInDictionaryStatus = [keyDictionary[@(DSIdentityKeyDictionary_KeyStatus)] unsignedIntegerValue];
            if ([DSKeyManager keysPublicKeyDataIsEqual:keyToCheckInDictionary.pointerValue key2:key->ok]) {
                if (save && status != keyToCheckInDictionaryStatus) {
                    [self updateStatus:status forKeyWithIndexID:index inContext:context];
                }
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSLog(@"these should really match up");
                return;
            }
        } else {
            _keysCreated = MAX(self.keysCreated, index + 1);
            if (save) {
                [self saveNewRemoteIdentityKey:key forKeyWithIndexID:index withStatus:status inContext:context];
            }
        }
        NSDictionary *keyDictionary = @{
            @(DSIdentityKeyDictionary_Key): [NSValue valueWithPointer:key],
            @(DSIdentityKeyDictionary_KeyType): [NSValue valueWithPointer:type],
            @(DSIdentityKeyDictionary_KeyStatus): @(status)
        };
        [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
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
            if ([DSKeyManager keysPublicKeyDataIsEqual:keyToCheckInDictionaryValue.pointerValue key2:key->ok]) {
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
            if (save) {
                [self saveNewKey:key atPath:indexPath withStatus:status fromDerivationPath:derivationPath inContext:context];
            }
        }
        NSDictionary *keyDictionary = @{
            @(DSIdentityKeyDictionary_Key): [NSValue valueWithPointer:key],
            @(DSIdentityKeyDictionary_KeyType): [NSValue valueWithPointer:key],
            @(DSIdentityKeyDictionary_KeyStatus): @(status)
        };
        [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
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
    NSDictionary *keyDictionary = @{
        @(DSIdentityKeyDictionary_Key): [NSValue valueWithPointer:key],
        @(DSIdentityKeyDictionary_KeyType): [NSValue valueWithPointer:key],
        @(DSIdentityKeyDictionary_KeyStatus): @(status)
    };
    [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
    return TRUE;
}

- (void)registerKey:(DMaybeOpaqueKey *)key
         withStatus:(DSIdentityKeyStatus)status
            atIndex:(uint32_t)index
             ofType:(DKeyKind *)type {
    _keysCreated = MAX(self.keysCreated, index + 1);
    NSDictionary *keyDictionary = @{
        @(DSIdentityKeyDictionary_Key): [NSValue valueWithPointer:key],
        @(DSIdentityKeyDictionary_KeyType): [NSValue valueWithPointer:key],
        @(DSIdentityKeyDictionary_KeyStatus): @(status)
    };
    [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
}

// MARK: From Remote/Network
// TODO: make sure we determine 'legacy' correctly here
+ (DMaybeOpaqueKey *)keyFromKeyDictionary:(NSDictionary *)dictionary
                                    rType:(uint32_t *)rType
                                   rIndex:(uint32_t *)rIndex {
    NSData *keyData = dictionary[@"data"];
    NSNumber *keyId = dictionary[@"id"]; // TODO: why this treatead as u32???
    NSNumber *type = dictionary[@"type"];
    if (keyData && keyId && type) {
        DKeyKind *kind = dash_spv_crypto_keys_key_key_kind_from_index(type.intValue);
        DMaybeOpaqueKey *key = [DSKeyManager keyWithPublicKeyData:keyData ofType:kind];
        *rIndex = [keyId unsignedIntValue];
        *rType = [type unsignedIntValue];
        return key;
    }
    return nil;
}

- (void)addKeyFromKeyDictionary:(NSDictionary *)dictionary
                           save:(BOOL)save
                      inContext:(NSManagedObjectContext *_Nullable)context {
    uint32_t index = 0;
    uint32_t type = 0;
    DMaybeOpaqueKey *key = [DSIdentity keyFromKeyDictionary:dictionary rType:&type rIndex:&index];
    DKeyKind *kind = dash_spv_crypto_keys_key_key_kind_from_index(index);
    if (key && key->ok) {
        [self addKey:key atIndex:index ofType:kind withStatus:DSIdentityKeyStatus_Registered save:save inContext:context];
    }
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

- (void)applyIdentityDictionary:(NSDictionary *)identityDictionary
                        version:(uint32_t)version
                           save:(BOOL)save
                      inContext:(NSManagedObjectContext *_Nullable)context {
    if (identityDictionary[@"balance"]) {
        uint64_t creditBalance = (uint64_t)[identityDictionary[@"balance"] longLongValue];
        _creditBalance = creditBalance;
    }
    if (identityDictionary[@"publicKeys"]) {
        for (NSDictionary *dictionary in identityDictionary[@"publicKeys"]) {
            [self addKeyFromKeyDictionary:dictionary save:save inContext:context];
        }
    }
}
- (void)applyIdentity:(dpp_identity_identity_Identity *)identity
                 save:(BOOL)save
            inContext:(NSManagedObjectContext *_Nullable)context {
    switch (identity->tag) {
        case dpp_identity_identity_Identity_V0: {
            dpp_identity_v0_IdentityV0 *versioned = identity->v0;
            _creditBalance = versioned->balance;
            for (int k = 0; k < versioned->public_keys->count; k++) {
                dpp_identity_identity_public_key_KeyID *key_id = versioned->public_keys->keys[k];
                dpp_identity_identity_public_key_IdentityPublicKey *public_key = versioned->public_keys->values[k];
                [self addKey:dash_spv_platform_identity_manager_opaque_key_from_identity_public_key(public_key)
                     atIndex:key_id->_0
                      ofType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()
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

//+ (DMaybeOpaqueKey *)firstKeyInIdentityDictionary:(NSDictionary *)identityDictionary {
//    if (identityDictionary[@"publicKeys"]) {
//        for (NSDictionary *dictionary in identityDictionary[@"publicKeys"]) {
//            uint32_t index = 0;
//            uint32_t type = 0;
//            DMaybeOpaqueKey *key = [DSIdentity keyFromKeyDictionary:dictionary rType:&type rIndex:&index];
//            if (index == 0) return key;
//        }
//    }
//    return nil;
//}

// MARK: Transition

//- (DSIdentityRegistrationTransition *)registrationTransitionSignedByPrivateKey:(DMaybeOpaqueKey *)privateKey
//                                                         registeringPublicKeys:(NSDictionary<NSNumber *, NSValue *> *)publicKeys
//                                                     usingAssetLockTransaction:(DSAssetLockTransaction *)transaction {
//    DSIdentityRegistrationTransition *identityRegistrationTransition = [[DSIdentityRegistrationTransition alloc] initWithVersion:1
//                                                                                                           registeringPublicKeys:publicKeys
//                                                                                                       usingAssetLockTransaction:transaction
//                                                                                                                         onChain:self.chain];
//    [identityRegistrationTransition signWithKey:privateKey atIndex:UINT32_MAX fromIdentity:self];
//    return identityRegistrationTransition;
//}
//
//- (void)registrationTransitionWithCompletion:(void (^_Nullable)(DSIdentityRegistrationTransition *_Nullable identityRegistrationTransaction, NSError *_Nullable error))completion {
//    if (!self.internalRegistrationFundingPrivateKey) {
//        if (completion) completion(nil, ERROR_NO_FUNDING_PRV_KEY);
//        return;
//    }
//    uint32_t index = [self firstIndexOfKeyOfType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor() createIfNotPresent:YES saveKey:!self.wallet.isTransient];
//    DMaybeOpaqueKey *publicKey = [self keyAtIndex:index];
//    NSAssert((index & ~(BIP32_HARD)) == 0, @"The index should be 0 here");
//    NSAssert(self.registrationAssetLockTransaction, @"The registration credit funding transaction must be known");
//    if (!self.registrationAssetLockTransaction.instantSendLockAwaitingProcessing && self.registrationAssetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
//        if (completion) completion(nil, ERROR_FUNDING_TX_NOT_MINED);
//        return;
//    }
//    DSIdentityRegistrationTransition *transition = [self registrationTransitionSignedByPrivateKey:self.internalRegistrationFundingPrivateKey
//                                                                            registeringPublicKeys:@{@(index): [NSValue valueWithPointer:publicKey]}
//                                                                        usingAssetLockTransaction:self.registrationAssetLockTransaction];
//    completion(transition, nil);
//}

// MARK: Registering

- (void)createAndPublishRegistrationTransitionWithCompletion:(void (^)(BOOL, NSError *))completion {
    if (!self.internalRegistrationFundingPrivateKey) {
        if (completion) completion(nil, ERROR_NO_FUNDING_PRV_KEY);
        return;
    }
    uint32_t index = [self firstIndexOfKeyOfType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor() createIfNotPresent:YES saveKey:!self.wallet.isTransient];
    DMaybeOpaqueKey *publicKey = [self keyAtIndex:index];
    NSAssert((index & ~(BIP32_HARD)) == 0, @"The index should be 0 here");
    NSAssert(self.registrationAssetLockTransaction, @"The registration credit funding transaction must be known");
    if (!self.registrationAssetLockTransaction.instantSendLockAwaitingProcessing && self.registrationAssetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
        if (completion) completion(nil, ERROR_FUNDING_TX_NOT_MINED);
        return;
    }
    
//    platformKeyDictionary[@"id"] = @([indexIdentifier unsignedIntValue]);
//    platformKeyDictionary[@"purpose"] = @(DWIdentityPublicKeyPurposeAuthentication);
//    platformKeyDictionary[@"securityLevel"] = @(DWIdentityPublicKeySecurityLevelMaster);
//    platformKeyDictionary[@"readOnly"] = @NO;
//    platformKeyDictionary[@"type"] = @(key->ok->tag);
//    platformKeyDictionary[@"data"] = [DSKeyManager publicKeyData:key->ok];
//    - (DSMutableStringValueDictionary *)assetLockProofDictionary {
//        DSMutableStringValueDictionary *assetLockDictionary = [DSMutableStringValueDictionary dictionary];
//        if (self.assetLockTransaction.instantSendLockAwaitingProcessing) {
//            assetLockDictionary[@"type"] = @(0);
//            assetLockDictionary[@"instantLock"] = self.assetLockTransaction.instantSendLockAwaitingProcessing.toData;
//            assetLockDictionary[@"outputIndex"] = @(self.assetLockTransaction.lockedOutpoint.n);
//            assetLockDictionary[@"transaction"] = [self.assetLockTransaction toData];
//        } else {
//            assetLockDictionary[@"type"] = @(1);
//            assetLockDictionary[@"coreChainLockedHeight"] = @(self.assetLockTransaction.blockHeight);
//            assetLockDictionary[@"outPoint"] = dsutxo_data(self.assetLockTransaction.lockedOutpoint);
//        }
//
//        return assetLockDictionary;
//    }

    dpp_identity_identity_public_key_IdentityPublicKey *public_key = dash_spv_platform_transition_identity_registration_public_key(index, publicKey->ok);
    
    dpp_identity_state_transition_asset_lock_proof_AssetLockProof *proof;
    DSInstantSendTransactionLock *isLock = self.registrationAssetLockTransaction.instantSendLockAwaitingProcessing;
    if (isLock) {
        uint8_t version = isLock.version;
        NSArray<NSData *> *outpoints = isLock.inputOutpoints;
        Arr_u8_36 **values = malloc(sizeof(Arr_u8_36 *) * outpoints.count);
        for (int i = 0; i < outpoints.count; i++) {
            NSData *o = outpoints[i];
            values[i] = Arr_u8_36_ctor(o.length, (uint8_t *) o.bytes);
        }
        Vec_u8_36 *lock_inputs = Vec_u8_36_ctor(isLock.inputOutpoints.count, values);
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
            Vec_u8 *script = o.inScript ? Vec_u8_ctor(o.inScript.length, (uint8_t *) o.inScript.bytes) : NULL;
            Vec_u8 *signature = Vec_u8_ctor(o.signature.length, (uint8_t *) o.signature.bytes);
            tx_inputs[i] = dash_spv_crypto_tx_input_TransactionInput_ctor(input_hash, o.index, script, signature, o.sequence);
        }
        
        NSArray *outputs = self.registrationAssetLockTransaction.outputs;
        NSUInteger outputsCount = outputs.count;
        dash_spv_crypto_tx_output_TransactionOutput **tx_outputs = malloc(sizeof(dash_spv_crypto_tx_output_TransactionOutput *) * outputsCount);
        for (int i = 0; i < outputs.count; i++) {
            DSTransactionOutput *o = outputs[i];
            Vec_u8 *script = o.outScript ? Vec_u8_ctor(o.outScript.length, (uint8_t *) o.outScript.bytes) : NULL;
            tx_outputs[i] = dash_spv_crypto_tx_output_TransactionOutput_ctor(o.amount, script, NULL);
        }
        uint8_t asset_lock_payload_version = self.registrationAssetLockTransaction.specialTransactionVersion;
        
        NSArray *creditOutputs = self.registrationAssetLockTransaction.creditOutputs;
        NSUInteger creditOutputsCount = creditOutputs.count;
        dash_spv_crypto_tx_output_TransactionOutput **credit_outputs = malloc(sizeof(dash_spv_crypto_tx_output_TransactionOutput *) * creditOutputsCount);
        for (int i = 0; i < creditOutputs.count; i++) {
            DSTransactionOutput *o = creditOutputs[i];
            Vec_u8 *script = o.outScript ? Vec_u8_ctor(o.outScript.length, (uint8_t *) o.outScript.bytes) : NULL;
            tx_outputs[i] = dash_spv_crypto_tx_output_TransactionOutput_ctor(o.amount, script, NULL);
        }

        Vec_dash_spv_crypto_tx_input_TransactionInput *input = Vec_dash_spv_crypto_tx_input_TransactionInput_ctor(inputsCount, tx_inputs);
        Vec_dash_spv_crypto_tx_output_TransactionOutput *output = Vec_dash_spv_crypto_tx_output_TransactionOutput_ctor(outputsCount, tx_outputs);
        Vec_dash_spv_crypto_tx_output_TransactionOutput *credit_output = Vec_dash_spv_crypto_tx_output_TransactionOutput_ctor(creditOutputsCount, credit_outputs);
        uint32_t output_index = (uint32_t ) self.registrationAssetLockTransaction.lockedOutpoint.n;
        
        proof =
        dash_spv_platform_transition_instant_proof(output_index, version, lock_inputs, txid, cycle_hash, signature, tx_version, lock_time, input, output, asset_lock_payload_version, credit_output);
    } else {
        DSUTXO lockedOutpoint = self.registrationAssetLockTransaction.lockedOutpoint;
        u256 *txid = u256_ctor_u(lockedOutpoint.hash);
        uint32_t vout = (uint32_t) lockedOutpoint.n;
        proof = dash_spv_platform_transition_chain_proof(self.registrationAssetLockTransaction.blockHeight, txid, vout);
    }
    
    DMaybeStateTransitionProofResult *state_transition_result = dash_spv_platform_PlatformSDK_identity_register_using_public_key_at_index(self.chain.shareCore.runtime, self.chain.shareCore.platform->obj, public_key, index, proof, self.internalRegistrationFundingPrivateKey->ok);
    if (!state_transition_result) {
        completion(NO, ERROR_REG_TRANSITION);
        return;
    }
    if (state_transition_result->error) {
        if (completion) completion(nil, ERROR_REG_TRANSITION_CREATION);
        Result_ok_dpp_state_transition_proof_result_StateTransitionProofResult_err_dash_spv_platform_error_Error_destroy(state_transition_result);
        return;
    }
    [self processStateTransitionResult:state_transition_result];
    
    DMaybeIdentity *result = dash_spv_platform_identity_manager_IdentitiesManager_monitor_with_delay(self.chain.shareCore.runtime, self.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData), dash_spv_platform_util_RetryStrategy_Linear_ctor(5), dash_spv_platform_identity_manager_IdentityValidator_None_ctor(), 4);
    
//    BOOL unsuccess = result->error;
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
        completion(NO, error);
    } else if (result->ok) {
        Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
        completion(YES, NULL);
    } else {
        Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
        completion(NO, ERROR_REG_TRANSITION);
    }

//    if (unsuccess) {
//        Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error *result_after_error = dash_spv_platform_identity_manager_IdentitiesManager_identity_monitor_with_delay(self.chain.shareCore.runtime, self.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData), dash_spv_platform_util_RetryStrategy_Linear_ctor(1), dash_spv_platform_identity_manager_IdentityMonitorValidator_None_ctor(), 4);
//        NSError *err = result_after_error->ok ? nil : ERROR_REG_TRANSITION;
//        Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result_after_error);
//        completion(NO, err);
//    } else {
//        completion(YES, nil);
//    }
    
//    DSIdentityRegistrationTransition *transition = [[DSIdentityRegistrationTransition alloc] initWithVersion:1
//                                                                                       registeringPublicKeys:@{@(index): [NSValue valueWithPointer:publicKey]}
//                                                                                   usingAssetLockTransaction:self.registrationAssetLockTransaction
//                                                                                                     onChain:self.chain];
//    
//    transition.signatureData = [DSKeyManager signMesasageDigest:self.internalRegistrationFundingPrivateKey->ok digest:[transition serializedBaseDataHash].UInt256];
//    transition.signaturePublicKeyId = UINT32_MAX;
//    transition.transitionHash = transition.data.SHA256;

    
//    [transition signWithKey:self.internalRegistrationFundingPrivateKey atIndex:UINT32_MAX fromIdentity:self];
    
    
    
//    [self.DAPIClient publishTransition:transition
//                       completionQueue:self.identityQueue
//                               success:^(NSDictionary *_Nonnull successDictionary, BOOL added) {
//        
//        Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error *result = dash_spv_platform_identity_manager_IdentitiesManager_identity_monitor_with_delay(self.chain.shareCore.runtime, self.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData), dash_spv_platform_util_RetryStrategy_Linear_ctor(5), dash_spv_platform_identity_manager_IdentityMonitorValidator_None_ctor(), 4);
//
//        
////        [self monitorForIdentityWithRetryCount:5
////                              retryAbsentCount:5
////                                         delay:4
////                                retryDelayType:DSIdentityRetryDelayType_Linear
////                                       options:DSIdentityMonitorOptions_None
////                                     inContext:self.platformContext
////                                    completion:^(BOOL success, BOOL found, NSError *error) {
////            if (completion) completion(successDictionary, error);
////        }];
//    }
//                               failure:^(NSError *_Nonnull error) {
//        if (error) {
//            Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error *result = dash_spv_platform_identity_manager_IdentitiesManager_identity_monitor_with_delay(self.chain.shareCore.runtime, self.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData), dash_spv_platform_util_RetryStrategy_Linear_ctor(1), dash_spv_platform_identity_manager_IdentityMonitorValidator_None_ctor(), 4);
//
////            [self monitorForIdentityWithRetryCount:1
////                                  retryAbsentCount:1
////                                             delay:4
////                                    retryDelayType:DSIdentityRetryDelayType_Linear
////                                           options:DSIdentityMonitorOptions_None
////                                         inContext:self.platformContext
////                                        completion:^(BOOL success, BOOL found, NSError *error) {
////                if (completion) completion(nil, found ? nil : error);
////            }];
//        } else if (completion) {
//            completion(nil, ERROR_REG_TRANSITION);
//        }
//    }];

//    completion(transition, nil);

    
    
//    [self registrationTransitionWithCompletion:^(DSIdentityRegistrationTransition *transition, NSError *transitionError) {
//        if (transition) {
//            [self.DAPIClient publishTransition:transition
//                               completionQueue:self.identityQueue
//                                       success:^(NSDictionary *_Nonnull successDictionary, BOOL added) {
//                [self monitorForIdentityWithRetryCount:5
//                                      retryAbsentCount:5
//                                                 delay:4
//                                        retryDelayType:DSIdentityRetryDelayType_Linear
//                                               options:DSIdentityMonitorOptions_None
//                                             inContext:self.platformContext
//                                            completion:^(BOOL success, BOOL found, NSError *error) {
//                    if (completion) completion(successDictionary, error);
//                }];
//            }
//                                       failure:^(NSError *_Nonnull error) {
//                if (error) {
//                    [self monitorForIdentityWithRetryCount:1
//                                          retryAbsentCount:1
//                                                     delay:4
//                                            retryDelayType:DSIdentityRetryDelayType_Linear
//                                                   options:DSIdentityMonitorOptions_None
//                                                 inContext:self.platformContext
//                                                completion:^(BOOL success, BOOL found, NSError *error) {
//                        if (completion) completion(nil, found ? nil : error);
//                    }];
//                } else if (completion) {
//                    completion(nil, ERROR_REG_TRANSITION);
//                }
//            }];
//        } else if (completion) {
//            completion(nil, transitionError ? transitionError : ERROR_REG_TRANSITION_CREATION);
//        }
//    }];
}

// MARK: Retrieval

- (void)fetchIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success, BOOL found, NSError *error))completion {
    dispatch_async(self.identityQueue, ^{
        DMaybeIdentity *result = dash_spv_platform_identity_manager_IdentitiesManager_monitor_for_id_bytes(self.chain.shareCore.runtime, self.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData), dash_spv_platform_util_RetryStrategy_SlowingDown50Percent_ctor(DEFAULT_FETCH_IDENTITY_RETRY_COUNT), self.isLocal ? dash_spv_platform_identity_manager_IdentityValidator_AcceptNotFoundAsNotAnError_ctor() : dash_spv_platform_identity_manager_IdentityValidator_None_ctor());
        if (!result) {
            completion(NO, NO, [NSError errorWithCode:0 localizedDescriptionKey:@"Unknown Error"]);
            return;
        }
        if (result->error) {
            NSError *error = [NSError ffi_from_platform_error:result->error];
            Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
            completion(NO, NO, error);
            return;
        }
        if (!result->ok) {
            completion(YES, NO, nil);
            return;
        }
        dpp_identity_v0_IdentityV0 *versioned_identity = result->ok->v0;
        self->_creditBalance = versioned_identity->balance;
        std_collections_Map_keys_dpp_identity_identity_public_key_KeyID_values_dpp_identity_identity_public_key_IdentityPublicKey *public_keys = versioned_identity->public_keys;
        for (int i = 0; i < public_keys->count; i++) {
//            dpp_identity_identity_public_key_KeyID *key_id = public_keys->keys[i];
            dpp_identity_identity_public_key_IdentityPublicKey *key = public_keys->values[i];
            DMaybeOpaqueKey *maybe_key = dash_spv_platform_identity_manager_opaque_key_from_identity_public_key(key);
            DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(maybe_key->ok);
            [self addKey:maybe_key atIndex:i ofType:kind withStatus:DSIdentityKeyStatus_Registered save:!self.isTransient inContext:self.platformContext];
        }
        self.registrationStatus = DSIdentityRegistrationStatus_Registered;
        completion(YES, YES, nil);

    });
}

//- (void)fetchIdentityNetworkStateInformationInContext:(NSManagedObjectContext *)context
//                                       withCompletion:(void (^)(BOOL success, BOOL found, NSError *error))completion {
//    //a local identity might not have been published yet
//    //todo retryabsentcount should be 0 if it can be proved to be absent
//    
//    Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error *result = dash_spv_platform_identity_manager_IdentitiesManager_identity_monitor_for_id_bytes(self.chain.shareCore.runtime, self.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData), dash_spv_platform_util_RetryStrategy_SlowingDown50Percent_ctor(DEFAULT_FETCH_IDENTITY_RETRY_COUNT), self.isLocal ? dash_spv_platform_identity_manager_IdentityMonitorValidator_AcceptNotFoundAsNotAnError_ctor() : dash_spv_platform_identity_manager_IdentityMonitorValidator_None_ctor());
//    if (!result) {
//        completion(NO, NO, [NSError errorWithCode:0 localizedDescriptionKey:@"Unknown Error"]);
//        return;
//    }
//    if (result->error) {
//        NSError *error;
//        switch (result->error->tag) {
//            case dash_spv_platform_error_Error_DashSDKError: {
//                error = [NSError errorWithCode:0 localizedDescriptionKey:[NSString stringWithCString:result->error->dash_sdk_error encoding:NSUTF8StringEncoding]];
//                break;
//            }
//            default:
//                break;
//        }
//        Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
//        completion(NO, NO, error);
//        return;
//    }
//    if (!result->ok) {
//        completion(YES, NO, nil);
//        return;
//    }
//    dpp_identity_v0_IdentityV0 *versioned_identity = result->ok->v0;
//    _creditBalance = versioned_identity->balance;
//    std_collections_Map_keys_dpp_identity_identity_public_key_KeyID_values_dpp_identity_identity_public_key_IdentityPublicKey *public_keys = versioned_identity->public_keys;
//    for (int i = 0; i < public_keys->count; i++) {
//        dpp_identity_identity_public_key_KeyID *key_id = public_keys->keys[i];
//        dpp_identity_identity_public_key_IdentityPublicKey *key = public_keys->values[i];
//        DMaybeOpaqueKey *maybe_key = dash_spv_platform_identity_manager_opaque_key_from_identity_public_key(key);
//        DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(maybe_key->ok);
//        [self addKey:maybe_key atIndex:i ofType:kind withStatus:DSIdentityKeyStatus_Registered save:!self.isTransient inContext:context];
//    }
//    self.registrationStatus = DSIdentityRegistrationStatus_Registered;
//    completion(YES, YES, nil);
////    [self monitorForIdentityWithRetryCount:DEFAULT_FETCH_IDENTITY_RETRY_COUNT
////                          retryAbsentCount:DEFAULT_FETCH_IDENTITY_RETRY_COUNT
////                                     delay:3
////                            retryDelayType:DSIdentityRetryDelayType_SlowingDown50Percent
////                                   options:self.isLocal ? DSIdentityMonitorOptions_AcceptNotFoundAsNotAnError : DSIdentityMonitorOptions_None
////                                 inContext:context
////                                completion:completion];
//}

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
        [self fetchUsernamesInContext:context withCompletion:^(BOOL success, NSError *error) {
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
                                     withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
            failureStep |= success & DSIdentityQueryStep_OutgoingContactRequests;
            if ([errors count]) {
                [groupedErrors addObjectsFromArray:errors];
                dispatch_group_leave(dispatchGroup);
            } else {
                if (queryStep & DSIdentityQueryStep_IncomingContactRequests) {
                    [self fetchIncomingContactRequestsInContext:context
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
            DSLogPrivate(@"Completed fetching of identity information for user %@ (query %lu - failures %lu)",
                         self.currentDashpayUsername ? self.currentDashpayUsername : self.uniqueIdString, (unsigned long)queryStep, failureStep);
#else
            DSLog(@"Completed fetching of identity information for user %@ (query %lu - failures %lu)",
                  @"<REDACTED>", (unsigned long)queryStep, failureStep);
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
    if (querySteps & DSIdentityQueryStep_Identity) {
        [self fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, BOOL found, NSError *error) {
            if (!success) {
                if (completion) dispatch_async(completionQueue, ^{ completion(DSIdentityQueryStep_Identity, error ? @[error] : @[]); });
                return;
            }
            if (!found) {
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
                if ((self.lastCheckedProfileTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
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
            if (!createdAt && (self.lastCheckedProfileTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_Profile;
            if (self.isLocal && (self.lastCheckedIncomingContactsTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_IncomingContactRequests;
            if (self.isLocal && (self.lastCheckedOutgoingContactsTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_OutgoingContactRequests;
            if (stepsNeeded != DSIdentityQueryStep_None) {
                [self fetchNetworkStateInformation:stepsNeeded & querySteps inContext:context withCompletion:completion onCompletionQueue:completionQueue];
            } else if (completion) {
                completion(DSIdentityQueryStep_None, @[]);
            }
        }
    });
}

- (void)fetchNeededNetworkStateInformationWithCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion {
    [self fetchNeededNetworkStateInformationInContext:self.platformContext
                                       withCompletion:completion
                                    onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchNeededNetworkStateInformationInContext:(NSManagedObjectContext *)context
                                     withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                                  onCompletionQueue:(dispatch_queue_t)completionQueue {
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
                if ((self.lastCheckedProfileTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                    stepsNeeded |= DSIdentityQueryStep_Profile;
                if (stepsNeeded != DSIdentityQueryStep_None) {
                    [self fetchNetworkStateInformation:stepsNeeded inContext:context withCompletion:completion onCompletionQueue:completionQueue];
                } else if (completion) {
                    completion(DSIdentityQueryStep_None, @[]);
                }
            }
        } else {
            DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
            if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
                stepsNeeded |= DSIdentityQueryStep_Username;
            if (![[self matchingDashpayUserInContext:context] createdAt] && (self.lastCheckedProfileTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_Profile;
            if (self.isLocal && (self.lastCheckedIncomingContactsTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_IncomingContactRequests;
            if (self.isLocal && (self.lastCheckedOutgoingContactsTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
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

//- (BOOL)signStateTransition:(DSTransition *)transition
//                forKeyIndex:(uint32_t)keyIndex
//                     ofType:(DKeyKind *)signingAlgorithm {
//    NSParameterAssert(transition);
//    DMaybeOpaqueKey *privateKey = [self privateKeyAtIndex:keyIndex ofType:signingAlgorithm];
//    NSAssert(privateKey && privateKey->ok, @"The private key should exist");
//    DMaybeOpaqueKey *publicKey = [self publicKeyAtIndex:keyIndex ofType:signingAlgorithm];
//    NSAssert([DSKeyManager keysPublicKeyDataIsEqual:privateKey->ok key2:publicKey->ok], @"These should be equal");
//    //        NSLog(@"%@",uint160_hex(self.identityRegistrationTransition.pubkeyHash));
//    //        NSAssert(uint160_eq(privateKey.publicKeyData.hash160,self.identityRegistrationTransition.pubkeyHash),@"Keys aren't ok");
//    [transition signWithKey:privateKey atIndex:keyIndex fromIdentity:self];
//    return YES;
//}
//
//- (BOOL)signStateTransition:(DSTransition *)transition {
//    if (!self.keysCreated) {
//        uint32_t index;
//        [self createNewKeyOfType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor() saveKey:!self.wallet.isTransient returnIndex:&index];
//    }
//    return [self signStateTransition:transition forKeyIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
//}
//
//- (void)signMessageDigest:(UInt256)digest
//              forKeyIndex:(uint32_t)keyIndex
//                   ofType:(DKeyKind *)signingAlgorithm
//               completion:(void (^_Nullable)(BOOL success, NSData *signature))completion {
//    NSParameterAssert(completion);
//    DMaybeOpaqueKey *privateKey = [self privateKeyAtIndex:keyIndex ofType:signingAlgorithm];
//    NSAssert(privateKey, @"The private key should exist");
//    DMaybeOpaqueKey *publicKey = [self publicKeyAtIndex:keyIndex ofType:signingAlgorithm];
//    NSAssert(publicKey, @"The public key should exist");
//    NSAssert([DSKeyManager keysPublicKeyDataIsEqual:privateKey->ok key2:publicKey->ok], @"These should be equal");
//
//    DSLogPrivate(@"Signing %@ with key %@", uint256_hex(digest), [DSKeyManager publicKeyData:privateKey->ok].hexString);
//    BYTES *sig = dash_spv_crypto_keys_key_OpaqueKey_sign(privateKey->ok, slice_u256_ctor_u(digest));
//    NSData *signature = [DSKeyManager NSDataFrom:sig];
//    DMaybeOpaqueKeyDtor(privateKey);
//    DMaybeOpaqueKeyDtor(publicKey);
//    completion(!signature.isZeroBytes, signature);
//}

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
        if (verified) {
            return TRUE;
        }
    }
    return FALSE;
}

- (BOOL)verifySignature:(NSData *)signature
            forKeyIndex:(uint32_t)keyIndex
                 ofType:(DKeyKind *)signingAlgorithm
       forMessageDigest:(UInt256)messageDigest {
    DMaybeOpaqueKey *publicKey = [self publicKeyAtIndex:keyIndex ofType:signingAlgorithm];
    BOOL verified = [DSKeyManager verifyMessageDigest:publicKey->ok digest:messageDigest signature:signature];
    // TODO: check we need to destroy here
    DMaybeOpaqueKeyDtor(publicKey);
    return verified;
}

- (void)encryptData:(NSData *)data
     withKeyAtIndex:(uint32_t)index
    forRecipientKey:(DOpaqueKey *)recipientPublicKey
         completion:(void (^_Nullable)(NSData *encryptedData))completion {
    NSParameterAssert(data);
    NSParameterAssert(recipientPublicKey);
    
    DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(recipientPublicKey);
    
    DMaybeOpaqueKey *privateKey = [self privateKeyAtIndex:index ofType:kind];
    NSData *encryptedData = [data encryptWithSecretKey:privateKey->ok forPublicKey:recipientPublicKey];
    // TODO: destroy opaque pointer here?
    DMaybeOpaqueKeyDtor(privateKey);
    if (completion) {
        completion(encryptedData);
    }
}
//
//- (void)decryptData:(NSData *)encryptedData
//     withKeyAtIndex:(uint32_t)index
//      fromSenderKey:(DOpaqueKey *)senderPublicKey
//         completion:(void (^_Nullable)(NSData *decryptedData))completion {
//    
////    senderPublicKey->tag
////    senderPublicKey->tag
//    DOpaqueKey *privateKey = [self privateKeyAtIndex:index ofType:(KeyKind)senderPublicKey->tag];
//    // TODO: destroy pointers here?
//    NSData *data = [encryptedData decryptWithSecretKey:privateKey fromPublicKey:senderPublicKey];
//    if (completion) {
//        completion(data);
//    }
//}
//

- (BOOL)processStateTransitionResult:(DMaybeStateTransitionProofResult *)result {
#if (!defined(TEST) && defined(DPP_STATE_TRANSITIONS))
    dpp_state_transition_proof_result_StateTransitionProofResult *proof_result = result->ok;
    switch (proof_result->tag) {
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedDataContract: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_data_contract->v0->id->_0->_0);
            DSLog(@"VerifiedDataContract: %@", identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedIdentity: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_identity->v0->id->_0->_0);
            DSLog(@"VerifiedIdentity: %@", identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedPartialIdentity: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_partial_identity>id->_0->_0);
            DSLog(@"VerifiedPartialIdentity: %@", identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedBalanceTransfer: {
            dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedBalanceTransfer_Body *transfer = proof_result->verified_balance_transfer;
            NSData *from_identifier = NSDataFromPtr(transfer->_0->id->_0->_0);
            NSData *to_identifier = NSDataFromPtr(transfer->_1->id->_0->_0);
            DSLog(@"VerifiedBalanceTransfer: %@ --> %@", from_identifier.hexString, to_identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedDocuments: {
            std_collections_Map_keys_platform_value_types_identifier_Identifier_values_Option_dpp_document_Document *verified_documents = proof_result->verified_documents;
            DSLog(@"VerifiedDocuments: %u", verified_documents->count);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedMasternodeVote: {
            dpp_voting_votes_Vote *verified_masternode_vote = proof_result->verified_masternode_vote;
            DSLog(@"VerifiedMasternodeVote: %u", verified_masternode_vote->tag);
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
    NSManagedObjectContext *context = [NSManagedObjectContext platformContext];
    __weak typeof(contract) weakContract = contract;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get service immediately
        BOOL isDPNSEmpty = [contract.name isEqual:@"DPNS"] && uint256_is_zero(self.chain.dpnsContractID);
        BOOL isDashpayEmpty = [contract.name isEqual:@"DashPay"] && uint256_is_zero(self.chain.dashpayContractID);
        BOOL isOtherContract = !([contract.name isEqual:@"DashPay"] || [contract.name isEqual:@"DPNS"]);
        if (((isDPNSEmpty || isDashpayEmpty || isOtherContract) && uint256_is_zero(contract.registeredIdentityUniqueID)) || contract.contractState == DPContractState_NotRegistered) {
            [contract registerCreator:self];
            [contract saveAndWaitInContext:context];
            
            if (!self.keysCreated) {
                uint32_t index;
                [self createNewKeyOfType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor() saveKey:!self.wallet.isTransient returnIndex:&index];
            }
            DMaybeOpaqueKey *privateKey = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
            DMaybeStateTransitionProofResult *state_transition_result = dash_spv_platform_PlatformSDK_data_contract_update(self.chain.shareCore.runtime, self.chain.shareCore.platform->obj, contract.raw_contract, 0, privateKey->ok);
            
            if (!state_transition_result) {
                return;
            }
            if (state_transition_result->error) {
                Result_ok_dpp_state_transition_proof_result_StateTransitionProofResult_err_dash_spv_platform_error_Error_destroy(state_transition_result);
                return;
            }
            if ([self processStateTransitionResult:state_transition_result]) {
                contract.contractState = DPContractState_Registering;
            } else {
                contract.contractState = DPContractState_Unknown;
            }
            [contract saveAndWaitInContext:context];
            
            Result_ok_Option_dpp_data_contract_DataContract_err_dash_spv_platform_error_Error *monitor_result = dash_spv_platform_contract_manager_ContractsManager_monitor_for_id_bytes(self.chain.shareCore.runtime, self.chain.shareCore.contractsManager->obj, u256_ctor_u(contract.contractId), dash_spv_platform_util_RetryStrategy_Linear_ctor(2), dash_spv_platform_contract_manager_ContractValidator_None_ctor());

            if (!monitor_result) {
                return;
            }
            if (monitor_result->error) {
                Result_ok_Option_dpp_data_contract_DataContract_err_dash_spv_platform_error_Error_destroy(monitor_result);
                DSLog(@"Contract Monitoring Error: %@", [NSError ffi_from_platform_error:monitor_result->error]);
                return;
            }
            if (monitor_result->ok) {
                NSData *identifier = NSDataFromPtr(monitor_result->ok->v0->id->_0->_0);
                if ([identifier isEqualToData:uint256_data(contract.contractId)]) {
                    DSLog(@"Contract Monitoring OK");
                    contract.contractState = DPContractState_Registered;
                    [contract saveAndWaitInContext:context];
                } else {
                    DSLog(@"Contract Monitoring Error: Ids dont match");
                }
            }
            DSLog(@"Contract Monitoring Error");

        } else if (contract.contractState == DPContractState_Registered || contract.contractState == DPContractState_Registering) {
            DSLog(@"Fetching contract for verification %@", contract.base58ContractId);
            DIdentifier *identifier = platform_value_types_identifier_Identifier_ctor(platform_value_types_identifier_IdentifierBytes32_ctor(u256_ctor_u(contract.contractId)));
            Result_ok_Option_dpp_data_contract_DataContract_err_dash_spv_platform_error_Error *result = dash_spv_platform_contract_manager_ContractsManager_fetch_contract_by_id(self.chain.shareCore.runtime, self.chain.shareCore.contractsManager->obj, identifier);
            if (!result) return;
            if (result->error || !result->ok->v0->document_types) {
                DSLog(@"Fetch contract error %u", result->error->tag);
                contract.contractState = DPContractState_NotRegistered;
                [contract saveAndWaitInContext:context];
                Result_ok_Option_dpp_data_contract_DataContract_err_dash_spv_platform_error_Error_destroy(result);
                return;
            }

            Result_ok_Option_dpp_data_contract_DataContract_err_dash_spv_platform_error_Error *contract_result = dash_spv_platform_contract_manager_ContractsManager_fetch_contract_by_id_bytes(self.chain.shareCore.runtime, self.chain.shareCore.contractsManager->obj, u256_ctor_u(contract.contractId));

            dispatch_async(self.identityQueue, ^{
                __strong typeof(weakContract) strongContract = weakContract;
                if (!weakContract || !contract_result) return;
                if (!contract_result->ok) {
                    strongContract.contractState = DPContractState_NotRegistered;
                    [strongContract saveAndWaitInContext:context];
                    Result_ok_Option_dpp_data_contract_DataContract_err_dash_spv_platform_error_Error_destroy(result);
                    return;
                }
                if (strongContract.contractState == DPContractState_Registered && !dash_spv_platform_contract_manager_has_equal_document_type_keys(contract_result->ok, strongContract.raw_contract)) {
                    strongContract.contractState = DPContractState_NotRegistered;
                    [strongContract saveAndWaitInContext:context];
                    //DSLog(@"Contract dictionary is %@", contractDictionary);
                }
            });
//
//            [self.DAPINetworkService fetchContractForId:uint256_data(contract.contractId)
//                                        completionQueue:self.identityQueue
//                                                success:^(NSDictionary *_Nonnull contractDictionary) {
//                __strong typeof(weakContract) strongContract = weakContract;
//                if (!weakContract) return;
//                if (!contractDictionary[@"documents"]) {
//                    strongContract.contractState = DPContractState_NotRegistered;
//                    [strongContract saveAndWaitInContext:context];
//                    return;
//                }
//                if (strongContract.contractState == DPContractState_Registered) {
//                    NSSet *set1 = [NSSet setWithArray:[contractDictionary[@"documents"] allKeys]];
//                    NSSet *set2 = [NSSet setWithArray:[strongContract.documents allKeys]];
//                    if (![set1 isEqualToSet:set2]) {
//                        strongContract.contractState = DPContractState_NotRegistered;
//                        [strongContract saveAndWaitInContext:context];
//                    }
//                    DSLog(@"Contract dictionary is %@", contractDictionary);
//                }
//            }
//                                                failure:^(NSError *_Nonnull error) {
//                NSString *debugDescription1 = [error.userInfo objectForKey:@"NSDebugDescription"];
//                NSError *jsonError;
//                NSData *objectData = [debugDescription1 dataUsingEncoding:NSUTF8StringEncoding];
//                NSDictionary *debugDescription = [NSJSONSerialization JSONObjectWithData:objectData options:0 error:&jsonError];
//                //NSDictionary * debugDescription =
//                __unused NSString *errorMessage = debugDescription[@"grpc_message"]; //!OCLINT
//                if (TRUE) {                                                          //[errorMessage isEqualToString:@"Invalid argument: Contract not found"]) {
//                    __strong typeof(weakContract) strongContract = weakContract;
//                    if (!strongContract) return;
//                    __strong typeof(weakSelf) strongSelf = weakSelf;
//                    if (!strongSelf) return;
//                    strongContract.contractState = DPContractState_NotRegistered;
//                    [strongContract saveAndWaitInContext:context];
//                }
//            }];
        }
    });
}
//
//- (void)fetchAndUpdateContractWithBase58Identifier:(NSString *)base58Identifier {
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
//        [self.DAPINetworkService fetchContractForId:base58Identifier.base58ToData
//                                    completionQueue:self.identityQueue
//                                            success:^(NSDictionary *_Nonnull contract) {}
//                                            failure:^(NSError *_Nonnull error) {}];
//    });
//}

// MARK: - Monitoring

- (void)updateCreditBalance {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        Result_ok_Option_u64_err_dash_spv_platform_error_Error *result = dash_spv_platform_identity_manager_IdentitiesManager_fetch_balance_by_id_bytes(strongSelf.chain.shareCore.runtime, strongSelf.chain.shareCore.identitiesManager->obj, u256_ctor(self.uniqueIDData));
        if (!result) {
            DSLog(@"updateCreditBalance (%@): NULL RESULT", self.uniqueIDData.hexString);
            return;
        }
        if (!result->ok) {
            DSLog(@"updateCreditBalance (%@): ERROR RESULT: %u", self.uniqueIDData.hexString, result->error->tag);
            Result_ok_Option_u64_err_dash_spv_platform_error_Error_destroy(result);
            return;
        }
        dispatch_async(self.identityQueue, ^{
            DSLog(@"updateCreditBalance (%@): OK: %llu", self.uniqueIDData.hexString, result->ok[0]);
            strongSelf.creditBalance = result->ok[0];
        });

        
//        DSDAPIPlatformNetworkService *dapiNetworkService = self.DAPINetworkService;
//        [dapiNetworkService getIdentityById:self.uniqueIDData
//                            completionQueue:self.identityQueue
//                                    success:^(NSDictionary *_Nullable profileDictionary) {
//            __strong typeof(weakSelf) strongSelf = weakSelf;
//            if (!strongSelf) return;
//            dispatch_async(self.identityQueue, ^{
//                strongSelf.creditBalance = (uint64_t)[profileDictionary[@"balance"] longLongValue];
//            });
//        }
//                                    failure:^(NSError *_Nonnull error) {
//            if (error.code == 12) { //UNIMPLEMENTED, this would mean that we are connecting to an old node
//                [self.DAPIClient removeDAPINodeByAddress:dapiNetworkService.ipAddress];
//            }
//        }];
    });
}

//- (void)monitorForIdentityWithRetryCount:(uint32_t)retryCount
//                        retryAbsentCount:(uint32_t)retryAbsentCount
//                                   delay:(NSTimeInterval)delay
//                          retryDelayType:(DSIdentityRetryDelayType)retryDelayType
//                                 options:(DSIdentityMonitorOptions)options
//                               inContext:(NSManagedObjectContext *)context
//                              completion:(void (^)(BOOL success, BOOL found, NSError *error))completion {
//    __weak typeof(self) weakSelf = self;
//    DSDAPIPlatformNetworkService *dapiNetworkService = self.DAPINetworkService;
//    void (^completionSuccess)(BOOL found) = ^(BOOL found) { if (completion) completion(YES, found, nil); };
//    void (^completionError)(BOOL success, BOOL found, NSError *error) = ^(BOOL success, BOOL found, NSError *error) { if (completion) completion(success, found, error); };
//
//    void (^notFoundError)(NSError *error) = ^(NSError *error) {
//        BOOL acceptNotFound = options & DSIdentityMonitorOptions_AcceptNotFoundAsNotAnError;
//        completionError(acceptNotFound, NO, acceptNotFound ? nil : error ?: ERROR_NO_IDENTITY);
//    };
//    
//    
//    [dapiNetworkService getIdentityById:self.uniqueIDData
//                        completionQueue:self.identityQueue
//                                success:^(NSDictionary *_Nullable versionedIdentityDictionary) {
//
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) return;
//        if (!versionedIdentityDictionary) notFoundError(nil);
//        if (![versionedIdentityDictionary respondsToSelector:@selector(objectForKey:)]) {
//            completionSuccess(NO);
//            return;
//        }
//        NSNumber *version = [versionedIdentityDictionary objectForKey:@(DSPlatformStoredMessage_Version)];
//        NSDictionary *identityDictionary = [versionedIdentityDictionary objectForKey:@(DSPlatformStoredMessage_Item)];
//        if (!identityDictionary) {
//            notFoundError(nil);
//        } else {
//            if (identityDictionary.count) {
//                [strongSelf applyIdentityDictionary:identityDictionary
//                                            version:[version intValue]
//                                               save:!self.isTransient
//                                          inContext:context];
//                strongSelf.registrationStatus = DSIdentityRegistrationStatus_Registered;
//                [self saveInContext:context];
//            }
//            completionSuccess(YES);
//        }
//    }
//                                
//                                failure:^(NSError *_Nonnull error) {
//        if (error.code == 12) { //UNIMPLEMENTED, this would mean that we are connecting to an old node
//            [self.DAPIClient removeDAPINodeByAddress:dapiNetworkService.ipAddress];
//        }
//        uint32_t nextRetryAbsentCount = retryAbsentCount;
//        if ([[error localizedDescription] isEqualToString:@"Identity not found"]) {
//            if (!retryAbsentCount) {
//                notFoundError(error);
//                return;
//            }
//            nextRetryAbsentCount--;
//        }
//        if (retryCount > 0) {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                NSTimeInterval nextDelay = delay;
//                switch (retryDelayType) {
//                    case DSIdentityRetryDelayType_SlowingDown20Percent:
//                        nextDelay = delay * 1.2;
//                        break;
//                    case DSIdentityRetryDelayType_SlowingDown50Percent:
//                        nextDelay = delay * 1.5;
//                        break;
//                    default:
//                        break;
//                }
//                [self monitorForIdentityWithRetryCount:retryCount - 1
//                                      retryAbsentCount:nextRetryAbsentCount
//                                                 delay:nextDelay
//                                        retryDelayType:retryDelayType
//                                               options:options
//                                             inContext:context
//                                            completion:completion];
//            });
//        } else {
//            completion(NO, NO, error);
//        }
//    }];
//}
//
//- (void)monitorForContract:(DPContract *)contract
//            withRetryCount:(uint32_t)retryCount
//                 inContext:(NSManagedObjectContext *)context
//                completion:(void (^)(BOOL success, NSError *error))completion {
//    __weak typeof(self) weakSelf = self;
//    NSParameterAssert(contract);
//    if (!contract) return;
//    DSDAPIPlatformNetworkService *dapiNetworkService = self.DAPINetworkService;
//    [dapiNetworkService fetchContractForId:uint256_data(contract.contractId)
//                           completionQueue:self.identityQueue
//                                   success:^(id _Nonnull contractDictionary) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) {
//            if (completion) completion(NO, ERROR_MEM_ALLOC);
//            return;
//        }
//        DSLog(@"Contract dictionary is %@", contractDictionary);
//        if ([contractDictionary isKindOfClass:[NSDictionary class]] && [contractDictionary[@"$id"] isEqualToData:uint256_data(contract.contractId)]) {
//            contract.contractState = DPContractState_Registered;
//            [contract saveAndWaitInContext:context];
//            if (completion) completion(TRUE, nil);
//        } else if (retryCount > 0) {
//            [strongSelf monitorForContract:contract withRetryCount:retryCount - 1 inContext:context completion:completion];
//        } else if (completion) {
//            completion(NO, ERROR_MALFORMED_RESPONSE);
//        }
//    }
//                                   failure:^(NSError *_Nonnull error) {
//        if (error.code == 12) { //UNIMPLEMENTED, this would mean that we are connecting to an old node
//            [self.DAPIClient removeDAPINodeByAddress:dapiNetworkService.ipAddress];
//        }
//        if (retryCount > 0) {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                __strong typeof(weakSelf) strongSelf = weakSelf;
//                if (!strongSelf) {
//                    if (completion) completion(NO, ERROR_MEM_ALLOC);
//                    return;
//                }
//                [strongSelf monitorForContract:contract
//                                withRetryCount:retryCount - 1
//                                     inContext:context
//                                    completion:completion];
//            });
//        } else if (completion) {
//            completion(FALSE, error);
//        }
//    }];
//}

// MARK: - Dashpay

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
        entity.registrationFundingTransaction = (DSAssetLockTransactionEntity *)[DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.registrationAssetLockTransaction.txHash)];
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
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateNotification
                                                                    object:nil
                                                                  userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSIdentityKey: self
                }];
            });
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateNotification
                                                                        object:nil
                                                                      userInfo:@{
                        DSChainManagerNotificationChainKey: self.chain,
                        DSIdentityKey: self,
                        DSIdentityUpdateEvents: updateEvents
                    }];
                });
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
        DSBlockchainIdentityKeyPathEntity *blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
        blockchainIdentityKeyPathEntity.derivationPath = derivationPathEntity;
        blockchainIdentityKeyPathEntity.keyType = key->ok->tag;
        blockchainIdentityKeyPathEntity.keyStatus = status;
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
        
        blockchainIdentityKeyPathEntity.path = path;
        blockchainIdentityKeyPathEntity.publicKeyData = [DSKeyManager publicKeyData:key->ok];
        blockchainIdentityKeyPathEntity.keyID = (uint32_t)[path indexAtPosition:path.length - 1];
        [identityEntity addKeyPathsObject:blockchainIdentityKeyPathEntity];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateNotification
                                                                object:nil
                                                              userInfo:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSIdentityKey: self,
                DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
            }];
        });
    }];
}

- (void)saveNewRemoteIdentityKey:(DMaybeOpaqueKey *)key
               forKeyWithIndexID:(uint32_t)keyID
                      withStatus:(DSIdentityKeyStatus)status
                       inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal == FALSE, @"This should only be called on non local blockchain identities");
    if (self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:context matching:@"blockchainIdentity == %@ && keyID == %@", identityEntity, @(keyID)];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity *blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
            blockchainIdentityKeyPathEntity.keyType = key->ok->tag;
            blockchainIdentityKeyPathEntity.keyStatus = status;
            blockchainIdentityKeyPathEntity.keyID = keyID;
            blockchainIdentityKeyPathEntity.publicKeyData = [DSKeyManager publicKeyData:key->ok];
            [identityEntity addKeyPathsObject:blockchainIdentityKeyPathEntity];
            [context ds_save];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateNotification
                                                                object:nil
                                                              userInfo:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSIdentityKey: self,
                DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
            }];
        });
    }];
}


- (void)updateStatus:(DSIdentityKeyStatus)status
        forKeyAtPath:(NSIndexPath *)path
  fromDerivationPath:(DSDerivationPath *)derivationPath
           inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:context];
        DSBlockchainIdentityKeyPathEntity *blockchainIdentityKeyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@", identityEntity, derivationPathEntity, path] firstObject];
        if (blockchainIdentityKeyPathEntity && (blockchainIdentityKeyPathEntity.keyStatus != status)) {
            blockchainIdentityKeyPathEntity.keyStatus = status;
            [context ds_save];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateNotification
                                                                object:nil
                                                              userInfo:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSIdentityKey: self,
                DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
            }];
        });
    }];
}

- (void)updateStatus:(DSIdentityKeyStatus)status
   forKeyWithIndexID:(uint32_t)keyID
           inContext:(NSManagedObjectContext *)context {
    NSAssert(self.isLocal == FALSE, @"This should only be called on non local blockchain identities");
    if (self.isLocal || self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        DSBlockchainIdentityKeyPathEntity *identityKeyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == NULL && keyID == %@", identityEntity, @(keyID)] firstObject];
        if (identityKeyPathEntity) {
            DSBlockchainIdentityKeyPathEntity *identityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
            identityKeyPathEntity.keyStatus = status;
            [context ds_save];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateNotification
                                                                object:nil
                                                              userInfo:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSIdentityKey: self,
                DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
            }];
        });
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
            if (save) {
                [context ds_save];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateNotification
                                                                object:nil
                                                              userInfo:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSIdentityKey: self
            }];
        });
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

//-(DSIdentityRegistrationTransition*)identityRegistrationTransition {
//    if (!_identityRegistrationTransition) {
//        _identityRegistrationTransition = (DSIdentityRegistrationTransition*)[self.wallet.specialTransactionsHolder transactionForHash:self.registrationTransitionHash];
//    }
//    return _identityRegistrationTransition;
//}

//-(UInt256)lastTransitionHash {
//    //this is not effective, do this locally in the future
//    return [[self allTransitions] lastObject].transitionHash;
//}


- (NSString *)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@-%@}", self.currentDashpayUsername, self.uniqueIdString]];
}

@end
