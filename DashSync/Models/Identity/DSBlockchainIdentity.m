//
//  DSBlockchainIdentity.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "DSBlockchainIdentity+Protected.h"
#import "DSChain+Protected.h"
#import "DSECDSAKey.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSCoder+Dash.h"
#import "NSMutableData+Dash.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSBlockchainIdentityCloseTransition.h"
#import "DSAuthenticationManager.h"
#import "DSPriceManager.h"
#import "DSPeerManager.h"
#import "DSDerivationPathFactory.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSTransition+Protected.h"
#import <TinyCborObjc/NSObject+DSCborEncoding.h>
#import "DSChainManager.h"
#import "DSDAPINetworkService.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSDashPlatform.h"
#import "DSPotentialOneWayFriendship.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSPotentialContact.h"
#import "NSData+Encryption.h"
#import "DSCreditFundingTransaction.h"
#import "DSCreditFundingDerivationPath.h"
#import "DSDocumentTransition.h"
#import "DSDerivationPath.h"
#import "DPDocumentFactory.h"
#import "DPContract+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSTransaction+Protected.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSCreditFundingTransactionEntity+CoreDataClass.h"
#import "BigIntTypes.h"
#import "DSContractTransition.h"
#import "NSData+Bitcoin.h"
#import "DSContactRequest.h"
#import "NSIndexPath+Dash.h"
#import "DSTransactionManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSIdentitiesManager.h"
#import "DSOptionsManager.h"

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"
#define DEFAULT_SIGNING_ALGORITH DSKeyType_ECDSA

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityKeyDictionary) {
    DSBlockchainIdentityKeyDictionary_Key = 0,
    DSBlockchainIdentityKeyDictionary_KeyType = 1,
    DSBlockchainIdentityKeyDictionary_KeyStatus = 2,
};

@interface DSBlockchainIdentity()

@property (nonatomic,weak) DSWallet * wallet;
@property (nonatomic,strong) NSMutableDictionary <NSString *,NSDictionary *> * usernameStatuses;
@property (nonatomic,assign) UInt256 uniqueID;
@property (nonatomic,assign) BOOL isLocal;
@property (nonatomic,assign) BOOL isTransient;
@property (nonatomic,assign) DSUTXO lockedOutpoint;
@property (nonatomic,assign) uint32_t index;
@property (nonatomic,assign) DSBlockchainIdentityRegistrationStatus registrationStatus;
@property (nonatomic,assign) uint64_t creditBalance;

@property (nonatomic,assign) uint32_t keysCreated;
@property (nonatomic,strong) NSMutableDictionary <NSNumber*, NSDictionary*> * keyInfoDictionaries;
@property (nonatomic,assign) uint32_t currentMainKeyIndex;
@property (nonatomic,assign) DSKeyType currentMainKeyType;

@property (nonatomic,strong) DSCreditFundingTransaction * registrationCreditFundingTransaction;

@property(nonatomic,strong) NSMutableDictionary <NSString*,NSData*>* usernameSalts;
@property(nonatomic,strong) NSMutableDictionary <NSString*,NSData*>* usernameDomains;

@property(nonatomic,readonly) DSDAPIClient* DAPIClient;
@property(nonatomic,readonly) DSDAPINetworkService* DAPINetworkService;

@property(nonatomic,strong) DPDocumentFactory* dashpayDocumentFactory;
@property(nonatomic,strong) DPDocumentFactory* dpnsDocumentFactory;

@property(nonatomic,strong) DSDashpayUserEntity * matchingDashpayUserInViewContext;

@property(nonatomic,strong) DSDashpayUserEntity * matchingDashpayUserInPlatformContext;

@property (nonatomic, strong) DSChain * chain;

@property (nonatomic, strong) DSECDSAKey * registrationFundingPrivateKey;

@property (nonatomic, assign) UInt256 dashpaySyncronizationBlockHash;

@property (nonatomic, readonly) DSIdentitiesManager * identitiesManager;

@property (nonatomic, readonly) NSManagedObjectContext * platformContext;

@property (nonatomic, strong) dispatch_queue_t identityQueue;


@property (nonatomic, assign) uint64_t lastCheckedUsernamesTimestamp;
@property (nonatomic, assign) uint64_t lastCheckedProfileTimestamp;
@property (nonatomic, assign) uint64_t lastCheckedIncomingContactsTimestamp;
@property (nonatomic, assign) uint64_t lastCheckedOutgoingContactsTimestamp;

@end

@implementation DSBlockchainIdentity

// MARK: - Initialization

-(instancetype)initWithUniqueId:(UInt256)uniqueId isTransient:(BOOL)isTransient onChain:(DSChain*)chain {
    //this is the initialization of a non local blockchain identity
    if (!(self = [super init])) return nil;
    NSAssert(!uint256_is_zero(uniqueId), @"uniqueId must not be null");
    _uniqueID = uniqueId;
    _isLocal = FALSE;
    _isTransient = isTransient;
    _keysCreated = 0;
    _currentMainKeyIndex = 0;
    _currentMainKeyType = DSKeyType_ECDSA;
    self.usernameStatuses = [NSMutableDictionary dictionary];
    self.usernameDomains = [NSMutableDictionary dictionary];
    self.keyInfoDictionaries = [NSMutableDictionary dictionary];
    _registrationStatus = DSBlockchainIdentityRegistrationStatus_Registered;
    _identityQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.identity.%@",uint256_base58(uniqueId)] UTF8String], DISPATCH_QUEUE_SERIAL);
    self.chain = chain;
    return self;
}

-(void)applyIdentityEntity:(DSBlockchainIdentityEntity*)blockchainIdentityEntity {
    for (DSBlockchainIdentityUsernameEntity * usernameEntity in blockchainIdentityEntity.usernames) {
        NSData * salt = usernameEntity.salt;
        if (salt) {
            [self.usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_PROPER:usernameEntity.stringValue, BLOCKCHAIN_USERNAME_DOMAIN:usernameEntity.domain?usernameEntity.domain:@"", BLOCKCHAIN_USERNAME_STATUS:@(usernameEntity.status), BLOCKCHAIN_USERNAME_SALT:usernameEntity.salt} forKey:[self fullPathForUsername:usernameEntity.stringValue inDomain:usernameEntity.domain]];
            [self.usernameSalts setObject:usernameEntity.salt forKey:usernameEntity.stringValue];
        } else {
            [self.usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_PROPER:usernameEntity.stringValue, BLOCKCHAIN_USERNAME_DOMAIN:usernameEntity.domain?usernameEntity.domain:@"", BLOCKCHAIN_USERNAME_STATUS:@(usernameEntity.status)} forKey:[self fullPathForUsername:usernameEntity.stringValue inDomain:usernameEntity.domain]];
        }
    }
    _creditBalance = blockchainIdentityEntity.creditBalance;
    _registrationStatus = blockchainIdentityEntity.registrationStatus;
    
    _lastCheckedProfileTimestamp = blockchainIdentityEntity.lastCheckedProfileTimestamp;
    _lastCheckedUsernamesTimestamp = blockchainIdentityEntity.lastCheckedUsernamesTimestamp;
    _lastCheckedIncomingContactsTimestamp = blockchainIdentityEntity.lastCheckedIncomingContactsTimestamp;
    _lastCheckedOutgoingContactsTimestamp = blockchainIdentityEntity.lastCheckedOutgoingContactsTimestamp;
    
    self.dashpaySyncronizationBlockHash = blockchainIdentityEntity.dashpaySyncronizationBlockHash.UInt256;
    for (DSBlockchainIdentityKeyPathEntity * keyPath in blockchainIdentityEntity.keyPaths) {
        NSIndexPath *keyIndexPath = (NSIndexPath *)[keyPath path];
        if (keyIndexPath) {
            NSIndexPath *nonHardenedKeyIndexPath = [keyIndexPath softenAllItems];
            BOOL success = [self registerKeyWithStatus:keyPath.keyStatus atIndexPath:nonHardenedKeyIndexPath ofType:keyPath.keyType];
            if (!success) {
                DSKey * key = [DSKey keyWithPublicKeyData:keyPath.publicKeyData forKeyType:keyPath.keyType];
                [self registerKey:key withStatus:keyPath.keyStatus atIndex:keyPath.keyID ofType:keyPath.keyType];
            }
        } else {
            DSKey * key = [DSKey keyWithPublicKeyData:keyPath.publicKeyData forKeyType:keyPath.keyType];
            [self registerKey:key withStatus:keyPath.keyStatus atIndex:keyPath.keyID ofType:keyPath.keyType];
        }
    }
    if (self.isLocal) {
        if (blockchainIdentityEntity.registrationFundingTransaction) {
            self.registrationCreditFundingTransaction = (DSCreditFundingTransaction *)[blockchainIdentityEntity.registrationFundingTransaction transactionForChain:self.chain];
        } else {
            NSData * transactionHashData = uint256_data(uint256_reverse(self.lockedOutpoint.hash));
            DSTransactionEntity * creditRegitrationTransactionEntity = [DSTransactionEntity anyObjectInContext:blockchainIdentityEntity.managedObjectContext matching:@"transactionHash.txHash == %@",transactionHashData];
            if (creditRegitrationTransactionEntity) {
                self.registrationCreditFundingTransaction = (DSCreditFundingTransaction *)[creditRegitrationTransactionEntity transactionForChain:self.chain];
                BOOL correctIndex = [self.registrationCreditFundingTransaction checkDerivationPathIndexForWallet:self.wallet isIndex:self.index];
                if (!correctIndex) {
                    NSAssert(FALSE,@"We should implement this");
                }
                //The following should not be needed (and actually causes identities to be recreated on launch each launch, leaving as comment for now
//                else {
//                    if (![self isRegisteredInWallet]) {
//                        [self registerInWallet];
//                    }
//                }
            }
        }
    }
    self.matchingDashpayUserInViewContext = [[NSManagedObjectContext viewContext] objectWithID:blockchainIdentityEntity.matchingDashpayUser.objectID];
    self.matchingDashpayUserInPlatformContext = [[NSManagedObjectContext platformContext] objectWithID:blockchainIdentityEntity.matchingDashpayUser.objectID];
}

-(instancetype)initWithBlockchainIdentityEntity:(DSBlockchainIdentityEntity*)blockchainIdentityEntity {
    if (!(self = [self initWithUniqueId:blockchainIdentityEntity.uniqueID.UInt256 isTransient:FALSE onChain:blockchainIdentityEntity.chain.chain])) return nil;
    [self applyIdentityEntity:blockchainIdentityEntity];
    
    return self;
}

-(instancetype)initAtIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet withBlockchainIdentityEntity:(DSBlockchainIdentityEntity*)blockchainIdentityEntity {
    if (!(self = [self initAtIndex:index withLockedOutpoint:lockedOutpoint inWallet:wallet])) return nil;
    [self applyIdentityEntity:blockchainIdentityEntity];
    return self;
}

-(instancetype)initAtIndex:(uint32_t)index inWallet:(DSWallet*)wallet {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);
    
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isLocal = YES;
    self.isTransient = FALSE;
    self.keysCreated = 0;
    self.currentMainKeyIndex = 0;
    self.currentMainKeyType = DSKeyType_ECDSA;
    self.index = index;
    self.usernameStatuses = [NSMutableDictionary dictionary];
    self.keyInfoDictionaries = [NSMutableDictionary dictionary];
    self.registrationStatus = DSBlockchainIdentityRegistrationStatus_Unknown;
    self.usernameSalts = [NSMutableDictionary dictionary];
    self.chain = wallet.chain;
    return self;
}

-(instancetype)initAtIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet {
    if (!(self = [self initAtIndex:index inWallet:wallet])) return nil;
    NSAssert(!dsutxo_is_zero(lockedOutpoint), @"utxo must not be nil");
    self.lockedOutpoint = lockedOutpoint;
    self.uniqueID = [dsutxo_data(lockedOutpoint) SHA256_2];
    _identityQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.identity.%@",uint256_base58(self.uniqueID)] UTF8String], DISPATCH_QUEUE_SERIAL);
    return self;
}

-(instancetype)initAtIndex:(uint32_t)index withFundingTransaction:(DSCreditFundingTransaction*)transaction inWallet:(DSWallet*)wallet {
    NSParameterAssert(wallet);
    if (![transaction isCreditFundingTransaction]) return nil;
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [self initAtIndex:index withLockedOutpoint:transaction.lockedOutpoint inWallet:wallet])) return nil;
    
    self.registrationCreditFundingTransaction = transaction;
    
    return self;
}

-(instancetype)initAtIndex:(uint32_t)index  withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> *)usernameDictionary inWallet:(DSWallet*)wallet {
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [self initAtIndex:index withFundingTransaction:transaction inWallet:wallet])) return nil;
    
    if (usernameDictionary) {
        NSMutableDictionary * usernameSalts = [NSMutableDictionary dictionary];
        for (NSString * username in usernameDictionary) {
            NSDictionary * subDictionary = usernameDictionary[username];
            NSData * salt = [subDictionary objectForKey:BLOCKCHAIN_USERNAME_SALT];
            if (salt) {
                [usernameSalts setObject:salt forKey:username];
            }
        }
        self.usernameStatuses = [usernameDictionary mutableCopy];
        self.usernameSalts = usernameSalts;
    }
    return self;
}

-(instancetype)initAtIndex:(uint32_t)index  withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> * _Nullable)usernameDictionary havingCredits:(uint64_t)credits registrationStatus:(DSBlockchainIdentityRegistrationStatus)registrationStatus inWallet:(DSWallet*)wallet {
    if (!(self = [self initAtIndex:index withFundingTransaction:transaction withUsernameDictionary:usernameDictionary inWallet:wallet])) return nil;
    
    self.creditBalance = credits;
    self.registrationStatus = registrationStatus;
    
    return self;
}

// MARK: - Full Registration agglomerate

-(DSBlockchainIdentityRegistrationStep)stepsCompleted {
    DSBlockchainIdentityRegistrationStep stepsCompleted = DSBlockchainIdentityRegistrationStep_None;
    if (self.isRegistered) {
        stepsCompleted = DSBlockchainIdentityRegistrationStep_RegistrationSteps;
        if ([self usernameFullPathsWithStatus:DSBlockchainIdentityUsernameStatus_Confirmed].count) {
            stepsCompleted |= DSBlockchainIdentityRegistrationStep_Username;
        }
    } else if (self.registrationCreditFundingTransaction) {
        stepsCompleted |= DSBlockchainIdentityRegistrationStep_FundingTransactionCreation;
        DSAccount * account = [self.chain firstAccountThatCanContainTransaction:self.registrationCreditFundingTransaction];
        if (self.registrationCreditFundingTransaction.blockHeight != TX_UNCONFIRMED || [account transactionIsVerified:self.registrationCreditFundingTransaction]) {
            stepsCompleted |= DSBlockchainIdentityRegistrationStep_FundingTransactionPublishing;
        }
    }
    if ([self isRegisteredInWallet]) {
        stepsCompleted |= DSBlockchainIdentityRegistrationStep_LocalInWalletPersistence;
    }
    return stepsCompleted;
}

-(void)continueRegisteringProfileOnNetwork:(DSBlockchainIdentityRegistrationStep)steps stepsCompleted:(DSBlockchainIdentityRegistrationStep)stepsAlreadyCompleted stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion {
    
    __block DSBlockchainIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
        
    if (!(steps & DSBlockchainIdentityRegistrationStep_Profile)) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(stepsCompleted, nil);
            });
        }
        return;
    }
    //todo:we need to still do profile
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(stepsCompleted, nil);
        });
    }
        
}


-(void)continueRegisteringUsernamesOnNetwork:(DSBlockchainIdentityRegistrationStep)steps stepsCompleted:(DSBlockchainIdentityRegistrationStep)stepsAlreadyCompleted stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion {
    
    __block DSBlockchainIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
        
    if (!(steps & DSBlockchainIdentityRegistrationStep_Username)) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(stepsCompleted, nil);
            });
        }
        return;
    }
    
    [self registerUsernamesWithCompletion:^(BOOL success, NSError * _Nonnull error) {
        if (!success) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(stepsCompleted, error);
                });
            }
            return;
        }
        if (stepCompletion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                stepCompletion(DSBlockchainIdentityRegistrationStep_Username);
            });
        }
        stepsCompleted |= DSBlockchainIdentityRegistrationStep_Username;
        
        [self continueRegisteringProfileOnNetwork:steps stepsCompleted:stepsCompleted stepCompletion:stepCompletion completion:completion];
    }];
}

-(void)continueRegisteringIdentityOnNetwork:(DSBlockchainIdentityRegistrationStep)steps stepsCompleted:(DSBlockchainIdentityRegistrationStep)stepsAlreadyCompleted stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion {
    
    __block DSBlockchainIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    if (!(steps & DSBlockchainIdentityRegistrationStep_Identity)) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(stepsCompleted, nil);
            });
        }
        return;
    }
    
    
    [self createAndPublishRegistrationTransitionWithCompletion:^(NSDictionary * _Nullable successInfo, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(stepsCompleted, error);
                });
            }
            return;
        }
        if (stepCompletion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                stepCompletion(DSBlockchainIdentityRegistrationStep_Identity);
            });
        }
        stepsCompleted |= DSBlockchainIdentityRegistrationStep_Identity;
        
        [self continueRegisteringUsernamesOnNetwork:steps stepsCompleted:stepsCompleted stepCompletion:stepCompletion completion:completion];
    }];
}

-(void)continueRegisteringOnNetwork:(DSBlockchainIdentityRegistrationStep)steps withFundingAccount:(DSAccount*)fundingAccount forTopupAmount:(uint64_t)topupDuffAmount stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion {
    [self continueRegisteringOnNetwork:steps withFundingAccount:fundingAccount forTopupAmount:topupDuffAmount inContext:self.platformContext stepCompletion:stepCompletion completion:completion];
}

-(void)continueRegisteringOnNetwork:(DSBlockchainIdentityRegistrationStep)steps withFundingAccount:(DSAccount*)fundingAccount forTopupAmount:(uint64_t)topupDuffAmount inContext:(NSManagedObjectContext*)context stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion {
    if (!self.registrationCreditFundingTransaction) {
        [self registerOnNetwork:steps withFundingAccount:fundingAccount forTopupAmount:topupDuffAmount stepCompletion:stepCompletion completion:completion];
    } else if (self.registrationStatus != DSBlockchainIdentityRegistrationStatus_Registered) {
        [self continueRegisteringIdentityOnNetwork:steps stepsCompleted:DSBlockchainIdentityRegistrationStep_L1Steps stepCompletion:stepCompletion completion:completion];
    } else if ([self.unregisteredUsernameFullPaths count]) {
        [self continueRegisteringUsernamesOnNetwork:steps stepsCompleted:DSBlockchainIdentityRegistrationStep_L1Steps | DSBlockchainIdentityRegistrationStep_Identity stepCompletion:stepCompletion completion:completion];
    } else if ([self matchingDashpayUserInContext:context].remoteProfileDocumentRevision < 1) {
        [self continueRegisteringProfileOnNetwork:steps stepsCompleted:DSBlockchainIdentityRegistrationStep_L1Steps | DSBlockchainIdentityRegistrationStep_Identity stepCompletion:stepCompletion completion:completion];
    }
}


-(void)registerOnNetwork:(DSBlockchainIdentityRegistrationStep)steps withFundingAccount:(DSAccount*)fundingAccount forTopupAmount:(uint64_t)topupDuffAmount stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion {
    __block DSBlockchainIdentityRegistrationStep stepsCompleted = DSBlockchainIdentityRegistrationStep_None;
    if (![self hasBlockchainIdentityExtendedPublicKeys]) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(stepsCompleted, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey: DSLocalizedString(@"The blockchain identity extended public keys need to be registered before you can register a blockchain identity.", nil)}]);
            });
        }
        return;
    }
    if (!(steps & DSBlockchainIdentityRegistrationStep_FundingTransactionCreation)) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(stepsCompleted, nil);
            });
        }
        return;
    }
    NSString * creditFundingRegistrationAddress = [self registrationFundingAddress];
    [self fundingTransactionForTopupAmount:topupDuffAmount toAddress:creditFundingRegistrationAddress fundedByAccount:fundingAccount completion:^(DSCreditFundingTransaction * _Nonnull fundingTransaction) {
        if (!fundingTransaction) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(stepsCompleted, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey: DSLocalizedString(@"Funding transaction could not be created", nil)}]);
                });
            }
            return;
        }
        [fundingAccount signTransaction:fundingTransaction withPrompt:@"Would you like to create this user?" completion:^(BOOL signedTransaction, BOOL cancelled) {
            if (!signedTransaction) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (cancelled) {
                            stepsCompleted |= DSBlockchainIdentityRegistrationStep_Cancelled;
                        }
                        completion(stepsCompleted, cancelled?nil:[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey: DSLocalizedString(@"Transaction could not be signed", nil)}]);
                    });
                }
                return;
            }
            if (stepCompletion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    stepCompletion(DSBlockchainIdentityRegistrationStep_FundingTransactionCreation);
                });
            }
            stepsCompleted |= DSBlockchainIdentityRegistrationStep_FundingTransactionCreation;
            if (!(steps & DSBlockchainIdentityRegistrationStep_FundingTransactionPublishing)) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(stepsCompleted, nil);
                    });
                }
                return;
            }
            
            //In wallet registration occurs now
            
            if (!(steps & DSBlockchainIdentityRegistrationStep_LocalInWalletPersistence)) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(stepsCompleted, nil);
                    });
                }
                return;
            }
            [self registerInWalletForRegistrationFundingTransaction:fundingTransaction];
            if (stepCompletion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    stepCompletion(DSBlockchainIdentityRegistrationStep_LocalInWalletPersistence);
                });
            }
            stepsCompleted |= DSBlockchainIdentityRegistrationStep_LocalInWalletPersistence;
            
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            __block BOOL transactionSuccessfullyPublished = FALSE;
            
            __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil
                                                                                     queue:nil usingBlock:^(NSNotification *note) {
                DSTransaction *tx = [note.userInfo objectForKey:DSTransactionManagerNotificationTransactionKey];
                if ([tx isEqual:fundingTransaction]) {
                    NSDictionary * changes = [note.userInfo objectForKey:DSTransactionManagerNotificationTransactionChangesKey];
                    if (changes) {
                        NSNumber * accepted = [changes objectForKey:DSTransactionManagerNotificationInstantSendTransactionAcceptedStatusKey];
                        NSNumber * lockVerified = [changes objectForKey:DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey];
                        if ([accepted boolValue] || [lockVerified boolValue]) {
                            transactionSuccessfullyPublished = TRUE;
                            dispatch_semaphore_signal(sem);
                        }
                    }
                }
            }];
            
            [self.chain.chainManager.transactionManager publishTransaction:fundingTransaction completion:^(NSError * _Nullable error) {
                if (error) {
                    [[NSNotificationCenter defaultCenter] removeObserver:observer];
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(stepsCompleted, error);
                        });
                    }
                    return;
                }
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{
                    
                    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_SEC));
                    
                    [[NSNotificationCenter defaultCenter] removeObserver:observer];
                    
                    if (!transactionSuccessfullyPublished) {
                        if (completion) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(stepsCompleted, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"Timeout while waiting for funding transaction to be accepted by network", nil)}]);
                            });
                        }
                        return;
                    }
                    
                    if (stepCompletion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            stepCompletion(DSBlockchainIdentityRegistrationStep_FundingTransactionPublishing);
                        });
                    }
                    stepsCompleted |= DSBlockchainIdentityRegistrationStep_FundingTransactionPublishing;
                    
                    [self continueRegisteringIdentityOnNetwork:steps stepsCompleted:stepsCompleted stepCompletion:stepCompletion completion:completion];
                });
            }];
        }];
    }];
}

// MARK: - Local Registration and Generation

-(BOOL)hasBlockchainIdentityExtendedPublicKeys {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return FALSE;
    DSAuthenticationKeysDerivationPath * derivationPathBLS = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
    DSAuthenticationKeysDerivationPath * derivationPathECDSA = [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:self.wallet];
    DSCreditFundingDerivationPath * derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:self.wallet];
    DSCreditFundingDerivationPath * derivationPathTopupFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityTopupFundingDerivationPathForWallet:self.wallet];
    if ([derivationPathBLS hasExtendedPublicKey] && [derivationPathECDSA hasExtendedPublicKey] && [derivationPathRegistrationFunding hasExtendedPublicKey] && [derivationPathTopupFunding hasExtendedPublicKey]) {
        return YES;
    } else {
        return NO;
    }
}

-(void)generateBlockchainIdentityExtendedPublicKeysWithPrompt:(NSString*)prompt completion:(void (^ _Nullable)(BOOL registered))completion {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    __block DSAuthenticationKeysDerivationPath * derivationPathBLS = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
    __block DSAuthenticationKeysDerivationPath * derivationPathECDSA = [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:self.wallet];
    __block DSCreditFundingDerivationPath * derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:self.wallet];
    __block DSCreditFundingDerivationPath * derivationPathTopupFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityTopupFundingDerivationPathForWallet:self.wallet];
    if ([derivationPathBLS hasExtendedPublicKey] && [derivationPathECDSA hasExtendedPublicKey] && [derivationPathRegistrationFunding hasExtendedPublicKey] && [derivationPathTopupFunding hasExtendedPublicKey]) {
        completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        [derivationPathBLS generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
        [derivationPathECDSA generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
        [derivationPathRegistrationFunding generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
        [derivationPathTopupFunding generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
        completion(YES);
    }];
}

-(void)registerInWalletForRegistrationFundingTransaction:(DSCreditFundingTransaction*)fundingTransaction {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    self.registrationCreditFundingTransaction = fundingTransaction;
    self.lockedOutpoint = fundingTransaction.lockedOutpoint;
    [self registerInWalletForBlockchainIdentityUniqueId:fundingTransaction.creditBurnIdentityIdentifier];
    
    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [fundingTransaction markAddressAsUsedInWallet:self.wallet];
}

-(void)registerInWalletForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    self.uniqueID = blockchainIdentityUniqueId;
    if (!self.identityQueue) {
        _identityQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.identity.%@",uint256_base58(blockchainIdentityUniqueId)] UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    [self registerInWallet];
}

-(BOOL)isRegisteredInWallet {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return FALSE;
    if (!self.wallet) return FALSE;
    return [self.wallet containsBlockchainIdentity:self];
}

-(void)registerInWallet {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    [self.wallet registerBlockchainIdentity:self];
    [self saveInitial];
}

-(BOOL)unregisterLocally {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return FALSE;
    if (self.isRegistered) return FALSE; //if it is already registered we can not unregister it from the wallet
    [self.wallet unregisterBlockchainIdentity:self];
    [self deletePersistentObjectAndSave:YES inContext:self.platformContext];
    return TRUE;
}

// MARK: - Read Only Property Helpers

-(DSDashpayUserEntity*)matchingDashpayUserInViewContext {
    if (!_matchingDashpayUserInViewContext) {
        _matchingDashpayUserInViewContext = [self matchingDashpayUserInContext:[NSManagedObjectContext viewContext]];
    }
    return _matchingDashpayUserInViewContext;
}

-(DSDashpayUserEntity*)matchingDashpayUserInPlatformContext {
    if (!_matchingDashpayUserInPlatformContext) {
        _matchingDashpayUserInPlatformContext = [self matchingDashpayUserInContext:[NSManagedObjectContext platformContext]];
    }
    return _matchingDashpayUserInPlatformContext;
}

-(DSDashpayUserEntity*)matchingDashpayUserInContext:(NSManagedObjectContext*)context {
    if (_matchingDashpayUserInViewContext || _matchingDashpayUserInPlatformContext) {
        if (context == [_matchingDashpayUserInPlatformContext managedObjectContext]) return _matchingDashpayUserInPlatformContext;
        if (context == [_matchingDashpayUserInViewContext managedObjectContext]) return _matchingDashpayUserInViewContext;
        if (_matchingDashpayUserInPlatformContext) {
            return [context objectWithID:_matchingDashpayUserInPlatformContext.objectID];
        } else {
            return [context objectWithID:_matchingDashpayUserInViewContext.objectID];
        }
    } else {
        __block DSDashpayUserEntity * dashpayUserEntity = nil;
        [context performBlockAndWait:^{
            dashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentity.uniqueID == %@",uint256_data(self.uniqueID)];
        }];
        return dashpayUserEntity;
    }
}

-(NSData*)uniqueIDData {
    return uint256_data(self.uniqueID);
}

-(NSData*)lockedOutpointData {
    return dsutxo_data(self.lockedOutpoint);
}

-(NSString*)currentDashpayUsername {
    return [self.dashpayUsernames firstObject];
}


-(NSArray<DSDerivationPath*>*)derivationPaths {
    if (!_isLocal) return nil;
    return [[DSDerivationPathFactory sharedInstance] unloadedSpecializedDerivationPathsForWallet:self.wallet];
}

//-(void)loadTransitions {
//    if (_wallet.isTransient) return;
////    [self.managedObjectContext performBlockAndWait:^{
////        [DSTransitionEntity setContext:self.managedObjectContext];
////        [DSBlockchainIdentityRegistrationTransitionEntity setContext:self.managedObjectContext];
////        [DSDerivationPathEntity setContext:self.managedObjectContext];
////        NSArray<DSTransitionEntity *>* specialTransactionEntities = [DSTransitionEntity objectsInContext:context matching:@"(blockchainIdentity.uniqueId == %@)",self.uniqueIDData];
////        for (DSTransitionEntity *e in specialTransactionEntities) {
////            DSTransition *transition = [e transitionForChain:self.chain];
////
////            if (! transition) continue;
////            if ([transition isMemberOfClass:[DSBlockchainIdentityRegistrationTransition class]]) {
////                self.blockchainIdentityRegistrationTransition = (DSBlockchainIdentityRegistrationTransition*)transition;
////            } else if ([transition isMemberOfClass:[DSBlockchainIdentityTopupTransition class]]) {
////                [self.blockchainIdentityTopupTransitions addObject:(DSBlockchainIdentityTopupTransition*)transition];
////            } else if ([transition isMemberOfClass:[DSBlockchainIdentityUpdateTransition class]]) {
////                [self.blockchainIdentityUpdateTransitions addObject:(DSBlockchainIdentityUpdateTransition*)transition];
////            } else if ([transition isMemberOfClass:[DSBlockchainIdentityCloseTransition class]]) {
////                [self.blockchainIdentityCloseTransitions addObject:(DSBlockchainIdentityCloseTransition*)transition];
////            } else if ([transition isMemberOfClass:[DSDocumentTransition class]]) {
////                [self.documentTransitions addObject:(DSDocumentTransition*)transition];
////            } else { //the other ones don't have addresses in payload
////                NSAssert(FALSE, @"Unknown special transaction type");
////            }
////        }
////    }];
//}
//
//
//
//-(void)topupTransitionForFundingTransaction:(DSTransaction*)fundingTransaction completion:(void (^ _Nullable)(DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction))completion {
//    NSParameterAssert(fundingTransaction);
//
//    //    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to topup %@ and spend %@ on credits?", nil),self.username,[[DSPriceManager sharedInstance] stringForDashAmount:topupAmount]];
//    //    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:topupAmount forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
//    //        if (!seed) {
//    //            completion(nil);
//    //            return;
//    //        }
//    //        DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction = [[DSBlockchainIdentityTopupTransition alloc] initWithBlockchainIdentityTopupTransactionVersion:1 registrationTransactionHash:self.registrationTransitionHash onChain:self.chain];
//    //
//    //        NSMutableData * opReturnScript = [NSMutableData data];
//    //        [opReturnScript appendUInt8:OP_RETURN];
//    //        [fundingAccount updateTransaction:blockchainIdentityTopupTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO];
//    //
//    //        completion(blockchainIdentityTopupTransaction);
//    //    }];
//    //
//}
//
//-(void)updateTransitionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainIdentityUpdateTransition * blockchainIdentityUpdateTransition))completion {
//
//}

//-(void)resetTransactionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainIdentityUpdateTransition * blockchainIdentityResetTransaction))completion {
//    NSString * question = DSLocalizedString(@"Are you sure you would like to reset this user?", nil);
//    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:0 forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
//        if (!seed) {
//            completion(nil);
//            return;
//        }
//        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
//        DSECDSAKey * oldPrivateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:self.index fromSeed:seed];
//        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:index fromSeed:seed];
//        
//        DSBlockchainIdentityUpdateTransition * blockchainIdentityResetTransaction = [[DSBlockchainIdentityUpdateTransition alloc] initWithBlockchainIdentityResetTransactionVersion:1 registrationTransactionHash:self.registrationTransitionHash previousBlockchainIdentityTransactionHash:self.lastTransitionHash replacementPublicKeyHash:[privateKey.publicKeyData hash160] creditFee:1000 onChain:self.chain];
//        [blockchainIdentityResetTransaction signPayloadWithKey:oldPrivateKey];
//        DSDLog(@"%@",blockchainIdentityResetTransaction.toData);
//        completion(blockchainIdentityResetTransaction);
//    }];
//}

//-(void)updateWithTopupTransition:(DSBlockchainIdentityTopupTransition*)blockchainIdentityTopupTransition save:(BOOL)save {
//    NSParameterAssert(blockchainIdentityTopupTransition);
//
//    if (![_blockchainIdentityTopupTransitions containsObject:blockchainIdentityTopupTransition]) {
//        [_blockchainIdentityTopupTransitions addObject:blockchainIdentityTopupTransition];
//        if (save) {
//            [self.managedObjectContext performBlockAndWait:^{
//                DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
//                [entity addTransitionsObject:blockchainIdentityTopupTransition.transitionEntity];
//                [DSBlockchainIdentityEntity saveContext];
//            }];
//        }
//    }
//}
//
//-(void)updateWithUpdateTransition:(DSBlockchainIdentityUpdateTransition*)blockchainIdentityUpdateTransition save:(BOOL)save {
//    NSParameterAssert(blockchainIdentityUpdateTransition);
//
//    if (![_blockchainIdentityUpdateTransitions containsObject:blockchainIdentityUpdateTransition]) {
//        [_blockchainIdentityUpdateTransitions addObject:blockchainIdentityUpdateTransition];
//        [_allTransitions addObject:blockchainIdentityUpdateTransition];
//        if (save) {
//            [self.managedObjectContext performBlockAndWait:^{
//                DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
//                [entity addTransitionsObject:blockchainIdentityUpdateTransition.transitionEntity];
//                [DSBlockchainIdentityEntity saveContext];
//            }];
//        }
//    }
//}
//
//-(void)updateWithCloseTransition:(DSBlockchainIdentityCloseTransition*)blockchainIdentityCloseTransition save:(BOOL)save {
//    NSParameterAssert(blockchainIdentityCloseTransition);
//
//    if (![_blockchainIdentityCloseTransitions containsObject:blockchainIdentityCloseTransition]) {
//        [_blockchainIdentityCloseTransitions addObject:blockchainIdentityCloseTransition];
//        [_allTransitions addObject:blockchainIdentityCloseTransition];
//        if (save) {
//            [self.managedObjectContext performBlockAndWait:^{
//                DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
//                [entity addTransitionsObject:blockchainIdentityCloseTransition.transitionEntity];
//                [DSBlockchainIdentityEntity saveContext];
//            }];
//        }
//    }
//}
//
//-(void)updateWithTransition:(DSDocumentTransition*)transition save:(BOOL)save {
//    NSParameterAssert(transition);
//
//    if (![_documentTransitions containsObject:transition]) {
//        [_documentTransitions addObject:transition];
//        [_allTransitions addObject:transition];
//        if (save) {
//            [self.managedObjectContext performBlockAndWait:^{
//                DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
//                [entity addTransitionsObject:transition.transitionEntity];
//                [DSBlockchainIdentityEntity saveContext];
//            }];
//        }
//    }
//}

-(NSString*)uniqueIdString {
    return [uint256_data(self.uniqueID) base58String];
}


-(dispatch_queue_t)networkingQueue {
    return self.chain.networkingQueue;
}

-(NSManagedObjectContext*)platformContext {
    return [NSManagedObjectContext platformContext];
}

-(DSIdentitiesManager*)identitiesManager {
    return self.chain.chainManager.identitiesManager;
}

// MARK: - Keys

-(void)createFundingPrivateKeyWithSeed:(NSData*)seed completion:(void (^ _Nullable)(BOOL success))completion {
    DSCreditFundingDerivationPath * derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:self.wallet];
    
    self.registrationFundingPrivateKey = (DSECDSAKey *)[derivationPathRegistrationFunding privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];
    if (self.registrationFundingPrivateKey) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES);
            });
        }
    } else {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
            });
        }
    }
}

-(void)createFundingPrivateKeyWithPrompt:(NSString*)prompt completion:(void (^ _Nullable)(BOOL success, BOOL cancelled))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
            if (!seed) {
                if (completion) {
                    completion(NO,cancelled);
                }
                return;
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self createFundingPrivateKeyWithSeed:seed completion:^(BOOL success) {
                    if (completion) {
                        completion(success,NO);
                    }
                }];
            });
        }];
    });
}

-(BOOL)activePrivateKeysAreLoadedWithFetchingError:(NSError**)error {
    BOOL loaded = TRUE;
    for (NSNumber * index in self.keyInfoDictionaries) {
        NSDictionary * keyDictionary = self.keyInfoDictionaries[index];
        DSBlockchainIdentityKeyStatus status = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyStatus)] unsignedIntValue];
        DSKeyType keyType = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyType)] unsignedIntValue];
        if (status == DSBlockchainIdentityKeyStatus_Registered) {
            loaded &= [self hasPrivateKeyAtIndex:[index unsignedIntValue] ofType:keyType error:error];
            if (*error) return FALSE;
        }
    }
    return loaded;
}

-(uint32_t)activeKeyCount {
    uint32_t rActiveKeys = 0;
    for (NSNumber * index in self.keyInfoDictionaries) {
        NSDictionary * keyDictionary = self.keyInfoDictionaries[index];
        DSBlockchainIdentityKeyStatus status = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyStatus)] unsignedIntValue];
        if (status == DSBlockchainIdentityKeyStatus_Registered) rActiveKeys++;
    }
    return rActiveKeys;
}

-(uint32_t)totalKeyCount {
    return (uint32_t)self.keyInfoDictionaries.count;
}

-(uint32_t)keyCountForKeyType:(DSKeyType)keyType {
    uint32_t keyCount = 0;
    for (NSNumber * index in self.keyInfoDictionaries) {
        NSDictionary * keyDictionary = self.keyInfoDictionaries[index];
        DSKeyType type = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyType)] unsignedIntValue];
        if (type == keyType) keyCount++;
    }
    return keyCount;
}

-(NSArray*)activeKeysForKeyType:(DSKeyType)keyType {
    NSMutableArray * activeKeys = [NSMutableArray array];
    for (NSNumber * index in self.keyInfoDictionaries) {
        NSDictionary * keyDictionary = self.keyInfoDictionaries[index];
        DSKeyType type = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyType)] unsignedIntValue];
        if (type == keyType) {
            [activeKeys addObject:keyDictionary[@(DSBlockchainIdentityKeyDictionary_Key)]];
        }
    }
    return [activeKeys copy];
}

-(DSBlockchainIdentityKeyStatus)statusOfKeyAtIndex:(NSUInteger)index {
    return [[[self.keyInfoDictionaries objectForKey:@(index)] objectForKey:@(DSBlockchainIdentityKeyDictionary_KeyStatus)] unsignedIntValue];
}

-(DSKeyType)typeOfKeyAtIndex:(NSUInteger)index {
    return [[[self.keyInfoDictionaries objectForKey:@(index)] objectForKey:@(DSBlockchainIdentityKeyDictionary_KeyType)] unsignedIntValue];
}

-(DSKey*)keyAtIndex:(NSUInteger)index {
    return [[self.keyInfoDictionaries objectForKey:@(index)] objectForKey:@(DSBlockchainIdentityKeyDictionary_Key)];
}

-(NSString*)localizedStatusOfKeyAtIndex:(NSUInteger)index {
    DSBlockchainIdentityKeyStatus status = [self statusOfKeyAtIndex:index];
    return [[self class] localizedStatusOfKeyForBlockchainIdentityKeyStatus:status];
}

+(NSString*)localizedStatusOfKeyForBlockchainIdentityKeyStatus:(DSBlockchainIdentityKeyStatus)status {
    switch (status) {
        case DSBlockchainIdentityKeyStatus_Unknown:
            return DSLocalizedString(@"Unknown", @"Status of Key or Username is Unknown");
        case DSBlockchainIdentityKeyStatus_Registered:
            return DSLocalizedString(@"Registered", @"Status of Key or Username is Registered");
        case DSBlockchainIdentityKeyStatus_Registering:
            return DSLocalizedString(@"Registering", @"Status of Key or Username is Registering");
        case DSBlockchainIdentityKeyStatus_NotRegistered:
            return DSLocalizedString(@"Not Registered", @"Status of Key or Username is Not Registered");
        case DSBlockchainIdentityKeyStatus_Revoked:
            return DSLocalizedString(@"Revoked", @"Status of Key or Username is Revoked");
        default:
            return @"";
    }
    
}

-(DSAuthenticationKeysDerivationPath*)derivationPathForType:(DSKeyType)type {
    if (!_isLocal) return nil;
    if (type == DSKeyType_ECDSA) {
        return [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:self.wallet];
    } else if (type == DSKeyType_BLS) {
        return [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
    }
    return nil;
}

-(BOOL)hasPrivateKeyAtIndex:(uint32_t)index ofType:(DSKeyType)type error:(NSError**)error {
    if (!_isLocal) return NO;
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    return hasKeychainData([self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath], error);
}

-(DSKey*)privateKeyAtIndex:(uint32_t)index ofType:(DSKeyType)type {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    NSError * error = nil;
    NSData * keySecret = getKeychainData([self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath], &error);
    
    NSAssert(keySecret, @"This should be present");
    
    if (!keySecret || error) return nil;
    
    return [DSKey keyWithPrivateKeyData:keySecret forKeyType:type];
}

-(DSKey*)derivePrivateKeyAtIdentityKeyIndex:(uint32_t)index ofType:(DSKeyType)type {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index, index};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    return [self derivePrivateKeyAtIndexPath:indexPath ofType:type];
}

-(DSKey*)derivePrivateKeyAtIndexPath:(NSIndexPath*)indexPath ofType:(DSKeyType)type {
    if (!_isLocal) return nil;
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    return [derivationPath privateKeyAtIndexPath:[indexPath hardenAllItems]];
}

-(DSKey*)privateKeyAtIndex:(uint32_t)index ofType:(DSKeyType)type forSeed:(NSData*)seed {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    return [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
}

-(DSKey*)publicKeyAtIndex:(uint32_t)index ofType:(DSKeyType)type {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath * hardenedIndexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    return [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
}

-(DSKey*)createNewKeyOfType:(DSKeyType)type saveKey:(BOOL)saveKey returnIndex:(uint32_t *)rIndex {
    return [self createNewKeyOfType:type saveKey:saveKey returnIndex:rIndex inContext:[NSManagedObjectContext viewContext]];
}

-(DSKey*)createNewKeyOfType:(DSKeyType)type saveKey:(BOOL)saveKey returnIndex:(uint32_t *)rIndex inContext:(NSManagedObjectContext*)context {
    if (!_isLocal) return nil;
    uint32_t keyIndex = self.keysCreated;
    const NSUInteger indexes[] = {_index | BIP32_HARD, keyIndex | BIP32_HARD};
    NSIndexPath * hardenedIndexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    DSKey * publicKey = [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
    NSAssert([derivationPath hasExtendedPrivateKey], @"The derivation path should have an extended private key");
    DSKey * privateKey = [derivationPath privateKeyAtIndexPath:hardenedIndexPath];
    NSAssert(privateKey,@"The private key should have been derived");
    NSAssert([publicKey.publicKeyData isEqualToData:privateKey.publicKeyData],@"These should be equal");
    self.keysCreated++;
    if (rIndex) {
        *rIndex = keyIndex;
    }
    NSDictionary * keyDictionary = @{@(DSBlockchainIdentityKeyDictionary_Key):publicKey, @(DSBlockchainIdentityKeyDictionary_KeyType):@(type), @(DSBlockchainIdentityKeyDictionary_KeyStatus):@(DSBlockchainIdentityKeyStatus_Registering)};
    [self.keyInfoDictionaries setObject:keyDictionary forKey:@(keyIndex)];
    if (saveKey) {
        [self saveNewKey:publicKey atPath:hardenedIndexPath withStatus:DSBlockchainIdentityKeyStatus_Registering fromDerivationPath:derivationPath inContext:context];
    }
    return publicKey;
}

-(uint32_t)firstIndexOfKeyOfType:(DSKeyType)type createIfNotPresent:(BOOL)createIfNotPresent saveKey:(BOOL)saveKey {
    for (NSNumber * indexNumber in self.keyInfoDictionaries) {
        NSDictionary * keyDictionary = self.keyInfoDictionaries[indexNumber];
        DSKeyType keyTypeAtIndex = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyType)] unsignedIntValue];
        if (keyTypeAtIndex == type) {
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

-(DSKey*)keyOfType:(DSKeyType)type atIndex:(uint32_t)index {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath * hardenedIndexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    DSKey * key = [derivationPath publicKeyAtIndexPath:hardenedIndexPath];
    return key;
}

-(void)addKey:(DSKey*)key atIndex:(uint32_t)index ofType:(DSKeyType)type withStatus:(DSBlockchainIdentityKeyStatus)status save:(BOOL)save {
    [self addKey:key atIndex:index ofType:type withStatus:status save:save inContext:self.platformContext];
}

-(void)addKey:(DSKey*)key atIndex:(uint32_t)index ofType:(DSKeyType)type withStatus:(DSBlockchainIdentityKeyStatus)status save:(BOOL)save inContext:(NSManagedObjectContext*)context {
    if (self.isLocal) {
        const NSUInteger indexes[] = {_index, index};
        NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
        [self addKey:key atIndexPath:indexPath ofType:type withStatus:status save:save];
    } else {
        if (self.keyInfoDictionaries[@(index)]) {
            NSDictionary * keyDictionary = self.keyInfoDictionaries[@(index)];
            DSKey * keyToCheckInDictionary = keyDictionary[@(DSBlockchainIdentityKeyDictionary_Key)];
            DSBlockchainIdentityKeyStatus keyToCheckInDictionaryStatus = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyStatus)] unsignedIntegerValue];
            if ([keyToCheckInDictionary.publicKeyData isEqualToData:key.publicKeyData]) {
                if (save && status != keyToCheckInDictionaryStatus) {
                    [self updateStatus:status forKeyWithIndexID:index inContext:context];
                }
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSDLog(@"these should really match up");
                return;
            }
        } else {
            self.keysCreated = MAX(self.keysCreated,index + 1);
            if (save) {
                [self saveNewRemoteIdentityKey:key forKeyWithIndexID:index withStatus:status inContext:context];
            }
        }
        NSDictionary * keyDictionary = @{@(DSBlockchainIdentityKeyDictionary_Key):key, @(DSBlockchainIdentityKeyDictionary_KeyType):@(type), @(DSBlockchainIdentityKeyDictionary_KeyStatus):@(status)};
        [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
    }
}

-(void)addKey:(DSKey*)key atIndexPath:(NSIndexPath*)indexPath ofType:(DSKeyType)type withStatus:(DSBlockchainIdentityKeyStatus)status save:(BOOL)save {
    [self addKey:key atIndexPath:indexPath ofType:type withStatus:status save:save inContext:self.platformContext];
}

-(void)addKey:(DSKey*)key atIndexPath:(NSIndexPath*)indexPath ofType:(DSKeyType)type withStatus:(DSBlockchainIdentityKeyStatus)status save:(BOOL)save inContext:(NSManagedObjectContext*)context {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal) return;
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    //derivationPath will be nil if not local
    
    DSKey * keyToCheck = [derivationPath publicKeyAtIndexPath:[indexPath hardenAllItems]];
    NSAssert(keyToCheck != nil, @"This key should be found");
    if ([keyToCheck.publicKeyData isEqualToData:key.publicKeyData]) { //if it isn't local we shouldn't verify
        uint32_t index = (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1];
        if (self.keyInfoDictionaries[@(index)]) {
            NSDictionary * keyDictionary = self.keyInfoDictionaries[@(index)];
            DSKey * keyToCheckInDictionary = keyDictionary[@(DSBlockchainIdentityKeyDictionary_Key)];
            if ([keyToCheckInDictionary.publicKeyData isEqualToData:key.publicKeyData]) {
                if (save) {
                    [self updateStatus:status forKeyAtPath:indexPath fromDerivationPath:derivationPath inContext:context];
                }
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSDLog(@"these should really match up");
                return;
            }
        } else {
            self.keysCreated = MAX(self.keysCreated,index + 1);
            if (save) {
                [self saveNewKey:key atPath:indexPath withStatus:status fromDerivationPath:derivationPath inContext:context];
            }
        }
        NSDictionary * keyDictionary = @{@(DSBlockchainIdentityKeyDictionary_Key):key, @(DSBlockchainIdentityKeyDictionary_KeyType):@(type), @(DSBlockchainIdentityKeyDictionary_KeyStatus):@(status)};
        [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
    } else {
        DSDLog(@"these should really match up");
    }
}

-(BOOL)registerKeyWithStatus:(DSBlockchainIdentityKeyStatus)status atIndexPath:(NSIndexPath*)indexPath ofType:(DSKeyType)type {
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    DSKey * key = [derivationPath publicKeyAtIndexPath:[indexPath hardenAllItems]];
    if (!key) return FALSE;
    uint32_t index = (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1];
    self.keysCreated = MAX(self.keysCreated,index + 1);
    NSDictionary * keyDictionary = @{@(DSBlockchainIdentityKeyDictionary_Key):key, @(DSBlockchainIdentityKeyDictionary_KeyType):@(type), @(DSBlockchainIdentityKeyDictionary_KeyStatus):@(status)};
    [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
    return TRUE;
}

-(void)registerKey:(DSKey*)key withStatus:(DSBlockchainIdentityKeyStatus)status atIndex:(uint32_t)index ofType:(DSKeyType)type {
    self.keysCreated = MAX(self.keysCreated,index + 1);
    NSDictionary * keyDictionary = @{@(DSBlockchainIdentityKeyDictionary_Key):key, @(DSBlockchainIdentityKeyDictionary_KeyType):@(type), @(DSBlockchainIdentityKeyDictionary_KeyStatus):@(status)};
    [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
}

// MARK: From Remote/Network

-(DSKey*)keyFromKeyDictionary:(NSDictionary*)dictionary rType:(uint32_t*)rType rIndex:(uint32_t*)rIndex {
    NSString * dataString = dictionary[@"data"];
    NSNumber * keyId = dictionary[@"id"];
    NSNumber * isEnabled = dictionary[@"isEnabled"];
    NSNumber * type = dictionary[@"type"];
    if (dataString && keyId && isEnabled && type) {
        DSKey * rKey = nil;
        NSData * data = [dataString base64ToData];
        if ([type intValue] == DSKeyType_BLS) {
            rKey = [DSBLSKey keyWithPublicKey:data.UInt384];
        } else if ([type intValue] == DSKeyType_ECDSA) {
            rKey = [DSECDSAKey keyWithPublicKeyData:data];
        }
        *rIndex = [keyId unsignedIntValue];
        *rType = [type unsignedIntValue];
        return rKey;
    }
    return nil;
}

-(void)addKeyFromKeyDictionary:(NSDictionary*)dictionary save:(BOOL)save inContext:(NSManagedObjectContext*)context {
    uint32_t index = 0;
    uint32_t type = 0;
    DSKey * key = [self keyFromKeyDictionary:dictionary rType:&type rIndex:&index];
    if (key) {
        [self addKey:key atIndex:index ofType:type withStatus:DSBlockchainIdentityKeyStatus_Registered save:save inContext:context];
    }
}

// MARK: - Funding

-(NSString*)registrationFundingAddress {
    if (self.registrationCreditFundingTransaction) {
        return [uint160_data(self.registrationCreditFundingTransaction.creditBurnPublicKeyHash) addressFromHash160DataForChain:self.chain];
    } else {
        DSCreditFundingDerivationPath * derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:self.wallet];
        return [derivationPathRegistrationFunding addressAtIndex:self.index];
    }
}

-(void)fundingTransactionForTopupAmount:(uint64_t)topupAmount toAddress:(NSString*)address fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSCreditFundingTransaction * fundingTransaction))completion {
    DSCreditFundingTransaction * fundingTransaction = [fundingAccount creditFundingTransactionFor:topupAmount to:address withFee:YES];
    completion(fundingTransaction);
}

// MARK: - Registration

// MARK: Helpers

-(BOOL)isRegistered {
    return self.registrationStatus == DSBlockchainIdentityRegistrationStatus_Registered;
}

-(NSString*)localizedRegistrationStatusString {
    switch (self.registrationStatus) {
        case DSBlockchainIdentityRegistrationStatus_Registered:
            return DSLocalizedString(@"Registered", @"The Dash Identity is registered");
            break;
        case DSBlockchainIdentityRegistrationStatus_Unknown:
            return DSLocalizedString(@"Unknown", @"It is Unknown if the Dash Identity is registered");
            break;
        case DSBlockchainIdentityRegistrationStatus_Registering:
            return DSLocalizedString(@"Registering", @"The Dash Identity is being registered");
            break;
        case DSBlockchainIdentityRegistrationStatus_NotRegistered:
            return DSLocalizedString(@"Not Registered", @"The Dash Identity is not registered");
            break;
            
        default:
            break;
    }
    return @"";
}

-(void)applyIdentityDictionary:(NSDictionary*)identityDictionary save:(BOOL)save inContext:(NSManagedObjectContext*)context  {
    if (identityDictionary[@"credits"]) {
        uint64_t creditBalance = (uint64_t)[identityDictionary[@"credits"] longLongValue];
        _creditBalance = creditBalance;
    }
    if (identityDictionary[@"publicKeys"]) {
        for (NSDictionary * dictionary in identityDictionary[@"publicKeys"]) {
            [self addKeyFromKeyDictionary:dictionary save:save inContext:context];
        }
    }
}

// MARK: Transition

-(void)registrationTransitionSignedByPrivateKey:(DSKey*)privateKey registeringPublicKeys:(NSDictionary <NSNumber*,DSKey*>*)publicKeys usingCreditFundingTransaction:(DSCreditFundingTransaction*)creditFundingTransaction completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition))completion {
    DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition = [[DSBlockchainIdentityRegistrationTransition alloc] initWithVersion:1 registeringPublicKeys:publicKeys usingLockedOutpoint:self.lockedOutpoint onChain:self.chain];
    [blockchainIdentityRegistrationTransition signWithKey:privateKey atIndex:UINT32_MAX fromIdentity:self];
    if (completion) {
        completion(blockchainIdentityRegistrationTransition);
    }
}

-(void)registrationTransitionWithCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * _Nullable blockchainIdentityRegistrationTransaction, NSError * _Nullable error))completion {
    if (!self.registrationFundingPrivateKey) {
        if (completion) {
            completion(nil,[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"The blockchain identity funding private key should be first created with createFundingPrivateKeyWithCompletion", nil)}]);
        }
        return;
    }
    
    uint32_t index = [self firstIndexOfKeyOfType:DSKeyType_ECDSA createIfNotPresent:YES saveKey:!self.wallet.isTransient];
    
    DSKey * publicKey = [self keyAtIndex:index];
    
    NSAssert((index & ~(BIP32_HARD)) == 0, @"The index should be 0 here");
    
    NSAssert(self.registrationCreditFundingTransaction, @"The registration credit funding transaction must be known");
    
    [self registrationTransitionSignedByPrivateKey:self.registrationFundingPrivateKey registeringPublicKeys:@{@(index):publicKey} usingCreditFundingTransaction:self.registrationCreditFundingTransaction  completion:^(DSBlockchainIdentityRegistrationTransition *blockchainIdentityRegistrationTransaction) {
        if (completion) {
            completion(blockchainIdentityRegistrationTransaction, nil);
        }
    }];
}

// MARK: Registering

-(void)createAndPublishRegistrationTransitionWithCompletion:(void (^)(NSDictionary *, NSError *))completion {
    [self registrationTransitionWithCompletion:^(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition, NSError * registrationTransitionError) {
        if (blockchainIdentityRegistrationTransition) {
            [self.DAPIClient publishTransition:blockchainIdentityRegistrationTransition success:^(NSDictionary * _Nonnull successDictionary) {
                [self monitorForBlockchainIdentityWithRetryCount:5 retryAbsentCount:5 delay:4 retryDelayType:DSBlockchainIdentityRetryDelayType_Linear options:DSBlockchainIdentityMonitorOptions_None inContext:self.platformContext completion:^(BOOL success, NSError * error) {
                    if (completion) {
                        completion(successDictionary,error);
                    }
                }];
            } failure:^(NSError * _Nonnull error) {
                if (error) {
                    [self monitorForBlockchainIdentityWithRetryCount:1 retryAbsentCount:1 delay:4 retryDelayType:DSBlockchainIdentityRetryDelayType_Linear options:DSBlockchainIdentityMonitorOptions_None inContext:self.platformContext completion:^(BOOL success, NSError * error) {
                        if (completion) {
                            completion(nil,error);
                        }
                    }];
                } else {
                    if (completion) {
                        completion(nil,[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                    DSLocalizedString(@"Unable to register registration transition", nil)}]);
                    }
                }
            }];
        } else {
            if (completion) {
                NSError * error = [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                               DSLocalizedString(@"Unable to create registration transition", nil)}];
                completion(nil,registrationTransitionError?registrationTransitionError:error);
            }
        }
    }];
    
}

// MARK: Retrieval

-(void)fetchIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success, NSError * error))completion {
    [self fetchIdentityNetworkStateInformationInContext:self.platformContext withCompletion:completion];
}

-(void)fetchIdentityNetworkStateInformationInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(BOOL success, NSError * error))completion {
    //a local identity might not have been published yet
    [self monitorForBlockchainIdentityWithRetryCount:5 retryAbsentCount:0 delay:3 retryDelayType:DSBlockchainIdentityRetryDelayType_SlowingDown50Percent options:self.isLocal?DSBlockchainIdentityMonitorOptions_AcceptNotFoundAsNotAnError:DSBlockchainIdentityMonitorOptions_None inContext:context completion:completion];
}

-(void)fetchAllNetworkStateInformationWithCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    [self fetchAllNetworkStateInformationInContext:self.platformContext withCompletion:completion];
}

-(void)fetchAllNetworkStateInformationInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    dispatch_async(self.identityQueue, ^{
        DSBlockchainIdentityQueryStep query = DSBlockchainIdentityQueryStep_None;
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_BlockchainIdentities) {
            query |= DSBlockchainIdentityQueryStep_Identity;
        }
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS) {
            query |= DSBlockchainIdentityQueryStep_Username;
        }
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
            query |= DSBlockchainIdentityQueryStep_Profile;
            if (self.isLocal) {
                query |= DSBlockchainIdentityQueryStep_ContactRequests;
            }
        }
        [self fetchNetworkStateInformation:query inContext:context withCompletion:completion];
    });
}

-(void)fetchL3NetworkStateInformation:(DSBlockchainIdentityQueryStep)queryStep withCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    [self fetchL3NetworkStateInformation:queryStep inContext:self.platformContext withCompletion:completion];
}

-(void)fetchL3NetworkStateInformation:(DSBlockchainIdentityQueryStep)queryStep inContext:(NSManagedObjectContext*)context withCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    if (!(queryStep & DSBlockchainIdentityQueryStep_Identity) && (!self.activeKeyCount)) {
        //We need to fetch keys if we want to query other information
        if (completion) {
            completion(DSBlockchainIdentityQueryStep_BadQuery,@[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"Attempt to query DAPs for blockchain identity with no active keys", nil)}]]);
        }
        return;
    }
    
    __block DSBlockchainIdentityQueryStep failureStep = DSBlockchainIdentityQueryStep_None;
    __block NSMutableArray * groupedErrors = [NSMutableArray array];
    dispatch_group_t dispatchGroup = dispatch_group_create();
    if (queryStep & DSBlockchainIdentityQueryStep_Username) {
        dispatch_group_enter(dispatchGroup);
        [self fetchUsernamesInContext:context withCompletion:^(BOOL success, NSError * error) {
            failureStep |= success & DSBlockchainIdentityQueryStep_Username;
            if (error) {
                [groupedErrors addObject:error];
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    if (queryStep & DSBlockchainIdentityQueryStep_Profile) {
        dispatch_group_enter(dispatchGroup);
        [self fetchProfileInContext:context withCompletion:^(BOOL success, NSError * error) {
            failureStep |= success & DSBlockchainIdentityQueryStep_Profile;
            if (error) {
                [groupedErrors addObject:error];
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    if (queryStep & DSBlockchainIdentityQueryStep_OutgoingContactRequests) {
        dispatch_group_enter(dispatchGroup);
        [self fetchOutgoingContactRequestsInContext:context withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
            failureStep |= success & DSBlockchainIdentityQueryStep_OutgoingContactRequests;
            if ([errors count]) {
                [groupedErrors addObjectsFromArray:errors];
                dispatch_group_leave(dispatchGroup);
            } else {
                if (queryStep & DSBlockchainIdentityQueryStep_IncomingContactRequests) {
                    [self fetchIncomingContactRequestsInContext:context withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
                        failureStep |= success & DSBlockchainIdentityQueryStep_IncomingContactRequests;
                        if ([errors count]) {
                            [groupedErrors addObjectsFromArray:errors];
                        }
                        dispatch_group_leave(dispatchGroup);
                    }];
                } else {
                    dispatch_group_leave(dispatchGroup);
                }
            }
        }];
    } else if (queryStep & DSBlockchainIdentityQueryStep_IncomingContactRequests) {
        dispatch_group_enter(dispatchGroup);
        [self fetchIncomingContactRequestsInContext:context withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
            failureStep |= success & DSBlockchainIdentityQueryStep_IncomingContactRequests;
            if ([errors count]) {
                [groupedErrors addObjectsFromArray:errors];
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
        
//    if (queryStep & DSBlockchainIdentityQueryStep_IncomingContactRequests) {
//        dispatch_group_enter(dispatchGroup);
//        [self fetchIncomingContactRequestsInContext:context withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
//            failureStep |= success & DSBlockchainIdentityQueryStep_IncomingContactRequests;
//            if ([errors count]) {
//                [groupedErrors addObjectsFromArray:errors];
//            }
//            dispatch_group_leave(dispatchGroup);
//        }];
//    }
        
    __weak typeof(self) weakSelf = self;
    if (completion) {
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
            DSDLog(@"Completed fetching of blockchain identity information for user %@ (query %lu - failures %lu)",self.currentDashpayUsername?self.currentDashpayUsername:self.uniqueIdString,(unsigned long)queryStep,failureStep);
            if (!(failureStep & DSBlockchainIdentityQueryStep_ContactRequests)) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                //todo This needs to be eventually set with the blockchain returned by platform.
                strongSelf.dashpaySyncronizationBlockHash = strongSelf.chain.lastTerminalBlock.blockHash;
            }
            completion(failureStep,[groupedErrors copy]);
        });
    }
}

-(void)fetchNetworkStateInformation:(DSBlockchainIdentityQueryStep)querySteps withCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    [self fetchNetworkStateInformation:querySteps inContext:self.platformContext withCompletion:completion];
}

-(void)fetchNetworkStateInformation:(DSBlockchainIdentityQueryStep)querySteps inContext:(NSManagedObjectContext*)context withCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    if (querySteps & DSBlockchainIdentityQueryStep_Identity) {
        [self fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
            if (!success) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(DSBlockchainIdentityQueryStep_Identity, @[error]);
                    });
                }
                return;
            }
            [self fetchL3NetworkStateInformation:querySteps inContext:context withCompletion:completion];
        }];
    } else {
        NSAssert([self blockchainIdentityEntityInContext:context], @"Blockchain identity entity should be known");
        [self fetchL3NetworkStateInformation:querySteps inContext:context withCompletion:completion];
    }
}

-(void)fetchIfNeededNetworkStateInformation:(DSBlockchainIdentityQueryStep)querySteps inContext:(NSManagedObjectContext*)context withCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    dispatch_async(self.identityQueue, ^{
        if (!self.activeKeyCount) {
            if (self.isLocal) {
                [self fetchNetworkStateInformation:querySteps inContext:context withCompletion:completion];
            } else {
                DSBlockchainIdentityQueryStep stepsNeeded = DSBlockchainIdentityQueryStep_None;
                if ([DSOptionsManager sharedInstance].syncType & DSSyncType_BlockchainIdentities) {
                    stepsNeeded |= DSBlockchainIdentityQueryStep_Identity;
                }
                if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS) {
                    stepsNeeded |= DSBlockchainIdentityQueryStep_Username;
                }
                if ((self.lastCheckedProfileTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
                    stepsNeeded |= DSBlockchainIdentityQueryStep_Profile;
                }
                if (stepsNeeded == DSBlockchainIdentityQueryStep_None) {
                    if (completion) {
                        completion(DSBlockchainIdentityQueryStep_None,@[]);
                    }
                } else {
                    [self fetchNetworkStateInformation:stepsNeeded & querySteps inContext:context withCompletion:completion];
                }
            }
        } else {
            DSBlockchainIdentityQueryStep stepsNeeded = DSBlockchainIdentityQueryStep_None;
            if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS) {
                stepsNeeded |= DSBlockchainIdentityQueryStep_Username;
            }
            if (![[self matchingDashpayUserInContext:context] createdAt] && (self.lastCheckedProfileTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
                stepsNeeded |= DSBlockchainIdentityQueryStep_Profile;
            }
            if (self.isLocal && (self.lastCheckedIncomingContactsTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
                stepsNeeded |= DSBlockchainIdentityQueryStep_IncomingContactRequests;
            }
            if (self.isLocal && (self.lastCheckedOutgoingContactsTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
                stepsNeeded |= DSBlockchainIdentityQueryStep_OutgoingContactRequests;
            }
            if (stepsNeeded == DSBlockchainIdentityQueryStep_None) {
                if (completion) {
                    completion(DSBlockchainIdentityQueryStep_None,@[]);
                }
            } else {
                [self fetchNetworkStateInformation:stepsNeeded & querySteps inContext:context withCompletion:completion];
            }
        }
    });
}

-(void)fetchNeededNetworkStateInformationWithCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    [self fetchNeededNetworkStateInformationInContext:self.platformContext withCompletion:completion];
}

-(void)fetchNeededNetworkStateInformationInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * errors))completion {
    dispatch_async(self.identityQueue, ^{
        if (!self.activeKeyCount) {
            if (self.isLocal) {
                [self fetchAllNetworkStateInformationWithCompletion:completion];
            } else {
                DSBlockchainIdentityQueryStep stepsNeeded = DSBlockchainIdentityQueryStep_None;
                if ([DSOptionsManager sharedInstance].syncType & DSSyncType_BlockchainIdentities) {
                    stepsNeeded |= DSBlockchainIdentityQueryStep_Identity;
                }
                if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS) {
                    stepsNeeded |= DSBlockchainIdentityQueryStep_Username;
                }
                if ((self.lastCheckedProfileTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
                    stepsNeeded |= DSBlockchainIdentityQueryStep_Profile;
                }
                if (stepsNeeded == DSBlockchainIdentityQueryStep_None) {
                    if (completion) {
                        completion(DSBlockchainIdentityQueryStep_None,@[]);
                    }
                } else {
                    [self fetchNetworkStateInformation:stepsNeeded inContext:context withCompletion:completion];
                }
            }
        } else {
            DSBlockchainIdentityQueryStep stepsNeeded = DSBlockchainIdentityQueryStep_None;
            if (![self.dashpayUsernameFullPaths count] && self.lastCheckedUsernamesTimestamp == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS) {
                stepsNeeded |= DSBlockchainIdentityQueryStep_Username;
            }
            if (![[self matchingDashpayUserInContext:context] createdAt] && (self.lastCheckedProfileTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
                stepsNeeded |= DSBlockchainIdentityQueryStep_Profile;
            }
            if (self.isLocal && (self.lastCheckedIncomingContactsTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
                stepsNeeded |= DSBlockchainIdentityQueryStep_IncomingContactRequests;
            }
            if (self.isLocal && (self.lastCheckedOutgoingContactsTimestamp < [[NSDate date] timeIntervalSince1970] - HOUR_TIME_INTERVAL) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
                stepsNeeded |= DSBlockchainIdentityQueryStep_OutgoingContactRequests;
            }
            if (stepsNeeded == DSBlockchainIdentityQueryStep_None) {
                if (completion) {
                    completion(DSBlockchainIdentityQueryStep_None,@[]);
                }
            } else {
                [self fetchNetworkStateInformation:stepsNeeded inContext:context withCompletion:completion];
            }
        }
    });
}

// MARK: - Platform Helpers

-(DPDocumentFactory*)dashpayDocumentFactory {
    if (!_dashpayDocumentFactory) {
        DPContract * contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
        NSAssert(contract,@"Contract must be defined");
        self.dashpayDocumentFactory = [[DPDocumentFactory alloc] initWithBlockchainIdentity:self contract:contract onChain:self.chain];
    }
    return _dashpayDocumentFactory;
}

-(DPDocumentFactory*)dpnsDocumentFactory {
    if (!_dpnsDocumentFactory) {
        DPContract * contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
        NSAssert(contract,@"Contract must be defined");
        self.dpnsDocumentFactory = [[DPDocumentFactory alloc] initWithBlockchainIdentity:self contract:contract onChain:self.chain];
    }
    return _dpnsDocumentFactory;
}

-(DSDAPIClient*)DAPIClient {
    return self.chain.chainManager.DAPIClient;
}

-(DSDAPINetworkService*)DAPINetworkService {
    return self.DAPIClient.DAPINetworkService;
}

// MARK: - Signing and Encryption

-(void)signStateTransition:(DSTransition*)transition forKeyIndex:(uint32_t)keyIndex ofType:(DSKeyType)signingAlgorithm completion:(void (^ _Nullable)(BOOL success))completion {
    NSParameterAssert(transition);
            
    DSKey * privateKey = [self privateKeyAtIndex:keyIndex ofType:signingAlgorithm];
    NSAssert(privateKey, @"The private key should exist");
    NSAssert([privateKey.publicKeyData isEqualToData:[self publicKeyAtIndex:keyIndex ofType:signingAlgorithm].publicKeyData], @"These should be equal");
    //        NSLog(@"%@",uint160_hex(self.blockchainIdentityRegistrationTransition.pubkeyHash));
    //        NSAssert(uint160_eq(privateKey.publicKeyData.hash160,self.blockchainIdentityRegistrationTransition.pubkeyHash),@"Keys aren't ok");
    [transition signWithKey:privateKey atIndex:keyIndex fromIdentity:self];
    if (completion) {
        completion(YES);
    }
}

-(void)signStateTransition:(DSTransition*)transition completion:(void (^ _Nullable)(BOOL success))completion {
    if (!self.keysCreated) {
        uint32_t index;
        [self createNewKeyOfType:DEFAULT_SIGNING_ALGORITH saveKey:!self.wallet.isTransient returnIndex:&index];
    }
    return [self signStateTransition:transition forKeyIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType completion:completion];
    
}

-(BOOL)verifySignature:(NSData*)signature ofType:(DSKeyType)signingAlgorithm forMessageDigest:(UInt256)messageDigest {
    for (DSKey * publicKey in [self activeKeysForKeyType:signingAlgorithm]) {
        BOOL verified = [publicKey verify:messageDigest signatureData:signature];
        if (verified) {
            return TRUE;
        }
    }
    return FALSE;
}

-(BOOL)verifySignature:(NSData*)signature forKeyIndex:(uint32_t)keyIndex ofType:(DSKeyType)signingAlgorithm forMessageDigest:(UInt256)messageDigest {
    DSKey * publicKey = [self publicKeyAtIndex:keyIndex ofType:signingAlgorithm];
    return [publicKey verify:messageDigest signatureData:signature];
}

-(void)encryptData:(NSData*)data withKeyAtIndex:(uint32_t)index forRecipientKey:(DSKey*)recipientPublicKey completion:(void (^ _Nullable)(NSData* encryptedData))completion {
    NSParameterAssert(data);
    NSParameterAssert(recipientPublicKey);
    DSKey * privateKey = [self privateKeyAtIndex:index ofType:recipientPublicKey.keyType];
    NSData * encryptedData = [data encryptWithSecretKey:privateKey forPublicKey:recipientPublicKey];
    if (completion) {
        completion(encryptedData);
    }

}

-(void)decryptData:(NSData*)encryptedData withKeyAtIndex:(uint32_t)index fromSenderKey:(DSKey*)senderPublicKey completion:(void (^ _Nullable)(NSData* decryptedData))completion {
    DSKey * privateKey = [self privateKeyAtIndex:index ofType:senderPublicKey.keyType];
    NSData * data = [encryptedData decryptWithSecretKey:privateKey fromPublicKey:senderPublicKey];
    if (completion) {
        completion(data);
    }
}

// MARK: - Contracts

-(void)fetchAndUpdateContract:(DPContract*)contract {
    return [self fetchAndUpdateContract:contract inContext:self.platformContext];
}

-(void)fetchAndUpdateContract:(DPContract*)contract inContext:(NSManagedObjectContext*)context {
    __weak typeof(contract) weakContract = contract;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        BOOL isDPNSEmpty = [contract.name isEqual:@"DPNS"] && uint256_is_zero(self.chain.dpnsContractID);
        BOOL isDashpayEmpty = [contract.name isEqual:@"DashPay"] && uint256_is_zero(self.chain.dashpayContractID);
        if (((isDPNSEmpty || isDashpayEmpty) && uint256_is_zero(contract.registeredBlockchainIdentityUniqueID)) || contract.contractState == DPContractState_NotRegistered) {
            [contract registerCreator:self inContext:context];
            __block DSContractTransition * transition = [contract contractRegistrationTransitionForIdentity:self];
            [self signStateTransition:transition completion:^(BOOL success) {
                if (success) {
                    [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                        __strong typeof(weakContract) strongContract = weakContract;
                        if (!strongContract) {
                            return;
                        }
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                            return;
                        }
                        [strongContract setContractState:DPContractState_Registering inContext:context];
                        [strongSelf monitorForContract:strongContract withRetryCount:2 inContext:context completion:^(BOOL success, NSError * error) {
                            
                        }];
                    } failure:^(NSError * _Nonnull error) {
                        //maybe it was already registered
                        __strong typeof(weakContract) strongContract = weakContract;
                        if (!strongContract) {
                            return;
                        }
                        [strongContract setContractState:DPContractState_Unknown inContext:context];
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                            return;
                        }
                        [strongSelf monitorForContract:strongContract withRetryCount:2 inContext:context completion:^(BOOL success, NSError * error) {
                            
                        }];
                    }];
                }
            }];
            
        } else if (contract.contractState == DPContractState_Registered || contract.contractState == DPContractState_Registering) {
            DSDLog(@"Fetching contract for verification %@",contract.base58ContractId);
            [self.DAPINetworkService fetchContractForId:contract.base58ContractId success:^(NSDictionary * _Nonnull contractDictionary) {
                __strong typeof(weakContract) strongContract = weakContract;
                if (!weakContract) {
                    return;
                }
                if (!contractDictionary[@"documents"]) {
                    [strongContract setContractState:DPContractState_NotRegistered inContext:context];
                    return;
                }
                if (strongContract.contractState == DPContractState_Registered) {
                    NSSet *set1 = [NSSet setWithArray:[contractDictionary[@"documents"] allKeys]];
                    NSSet *set2 = [NSSet setWithArray:[strongContract.documents allKeys]];
                    
                    if (![set1 isEqualToSet:set2]) {
                        [strongContract setContractState:DPContractState_NotRegistered inContext:context];
                    }
                    DSDLog(@"Contract dictionary is %@",contractDictionary);
                }
            } failure:^(NSError * _Nonnull error) {
                NSString * debugDescription1 = [error.userInfo objectForKey:@"NSDebugDescription"];
                NSError *jsonError;
                NSData *objectData = [debugDescription1 dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary * debugDescription = [NSJSONSerialization JSONObjectWithData:objectData options:0 error:&jsonError];
                //NSDictionary * debugDescription =
                NSString * errorMessage = [debugDescription objectForKey:@"grpc_message"];
                if (TRUE) {//[errorMessage isEqualToString:@"Invalid argument: Contract not found"]) {
                    __strong typeof(weakContract) strongContract = weakContract;
                    if (!strongContract) {
                        return;
                    }
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) {
                        return;
                    }
                    [strongContract setContractState:DPContractState_NotRegistered inContext:context];
                }
            }];
        }
    });
}

-(void)fetchAndUpdateContractWithIdentifier:(NSString*)identifier {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        
        [self.DAPINetworkService fetchContractForId:identifier success:^(NSDictionary * _Nonnull contract) {
            //[DPContract contr]
            
        } failure:^(NSError * _Nonnull error) {
            
        }];
    });
}

// MARK: - DPNS

// MARK: Usernames

-(void)addDashpayUsername:(NSString*)username save:(BOOL)save {
    [self addUsername:username inDomain:[self dashpayDomainName] status:DSBlockchainIdentityUsernameStatus_Initial save:save registerOnNetwork:YES];
}

-(void)addUsername:(NSString*)username inDomain:(NSString*)domain save:(BOOL)save {
    [self addUsername:username inDomain:domain status:DSBlockchainIdentityUsernameStatus_Initial save:save registerOnNetwork:YES];
}

-(void)addUsername:(NSString*)username inDomain:(NSString*)domain status:(DSBlockchainIdentityUsernameStatus)status save:(BOOL)save registerOnNetwork:(BOOL)registerOnNetwork {
    [self.usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(DSBlockchainIdentityUsernameStatus_Initial), BLOCKCHAIN_USERNAME_PROPER:username, BLOCKCHAIN_USERNAME_DOMAIN:domain} forKey:[self fullPathForUsername:username inDomain:domain]];
    if (save) {
        [self saveNewUsername:username inDomain:domain status:DSBlockchainIdentityUsernameStatus_Initial inContext:self.platformContext];
        if (registerOnNetwork && self.registered && status != DSBlockchainIdentityUsernameStatus_Confirmed) {
            [self registerUsernamesWithCompletion:^(BOOL success, NSError * _Nonnull error) {
                
            }];
        }
    }
}

-(DSBlockchainIdentityUsernameStatus)statusOfUsername:(NSString*)username inDomain:(NSString*)domain {
    return [self statusOfUsernameFullPath:[self fullPathForUsername:username inDomain:domain]];
}

-(DSBlockchainIdentityUsernameStatus)statusOfDashpayUsername:(NSString*)username {
    return [self statusOfUsernameFullPath:[self fullPathForUsername:username inDomain:[self dashpayDomainName]]];
}

-(DSBlockchainIdentityUsernameStatus)statusOfUsernameFullPath:(NSString*)usernameFullPath {
    return [[[self.usernameStatuses objectForKey:usernameFullPath] objectForKey:BLOCKCHAIN_USERNAME_STATUS] unsignedIntegerValue];
}

-(NSString*)usernameOfUsernameFullPath:(NSString*)usernameFullPath {
    return [[self.usernameStatuses objectForKey:usernameFullPath] objectForKey:BLOCKCHAIN_USERNAME_PROPER];
}

-(NSString*)domainOfUsernameFullPath:(NSString*)usernameFullPath {
    return [[self.usernameStatuses objectForKey:usernameFullPath] objectForKey:BLOCKCHAIN_USERNAME_DOMAIN];
}

-(NSString*)fullPathForUsername:(NSString*)username inDomain:(NSString*)domain {
    NSString * fullPath = [[username lowercaseString] stringByAppendingFormat:@".%@",[domain lowercaseString]];
    return fullPath;
}

-(NSArray<NSString*>*)dashpayUsernameFullPaths {
    return [self.usernameStatuses allKeys];
}

-(NSArray<NSString*>*)dashpayUsernames {
    NSMutableArray * usernameArray = [NSMutableArray array];
    for (NSString * usernameFullPath in self.usernameStatuses) {
        [usernameArray addObject:[self usernameOfUsernameFullPath:usernameFullPath]];
    }
    return [usernameArray copy];
}

-(NSArray<NSString*>*)unregisteredUsernameFullPaths {
    return [self usernameFullPathsWithStatus:DSBlockchainIdentityUsernameStatus_Initial];
}

-(NSArray<NSString*>*)usernameFullPathsWithStatus:(DSBlockchainIdentityUsernameStatus)usernameStatus {
    NSMutableArray * unregisteredUsernames = [NSMutableArray array];
    for (NSString * username in self.usernameStatuses) {
        NSDictionary * usernameInfo = self.usernameStatuses[username];
        DSBlockchainIdentityUsernameStatus status = [[usernameInfo objectForKey:BLOCKCHAIN_USERNAME_STATUS] unsignedIntegerValue];
        if (status == usernameStatus) {
            [unregisteredUsernames addObject:username];
        }
    }
    return [unregisteredUsernames copy];
}

-(NSArray<NSString*>*)preorderedUsernameFullPaths {
    NSMutableArray * unregisteredUsernames = [NSMutableArray array];
    for (NSString * username in self.usernameStatuses) {
        NSDictionary * usernameInfo = self.usernameStatuses[username];
        DSBlockchainIdentityUsernameStatus status = [[usernameInfo objectForKey:BLOCKCHAIN_USERNAME_STATUS] unsignedIntegerValue];
        if (status == DSBlockchainIdentityUsernameStatus_Preordered) {
            [unregisteredUsernames addObject:username];
        }
    }
    return [unregisteredUsernames copy];
}

// MARK: Username Helpers

-(NSData*)saltForUsernameFullPath:(NSString*)usernameFullPath saveSalt:(BOOL)saveSalt inContext:(NSManagedObjectContext*)context {
    NSData * salt;
    if ([self statusOfUsernameFullPath:usernameFullPath] == DSBlockchainIdentityUsernameStatus_Initial || !(salt = [self.usernameSalts objectForKey:usernameFullPath])) {
        UInt256 random256 = uint256_RANDOM;
        salt = uint256_data(random256);
        [self.usernameSalts setObject:salt forKey:usernameFullPath];
        if (saveSalt) {
            [self saveUsername:[self usernameOfUsernameFullPath:usernameFullPath] inDomain:[self domainOfUsernameFullPath:usernameFullPath] status:[self statusOfUsernameFullPath:usernameFullPath] salt:salt commitSave:YES inContext:context];
        }
    } else {
        salt = [self.usernameSalts objectForKey:usernameFullPath];
    }
    return salt;
}

-(NSMutableDictionary<NSString*,NSData*>*)saltedDomainHashesForUsernameFullPaths:(NSArray*)usernameFullPaths inContext:(NSManagedObjectContext*)context {
    NSMutableDictionary * mSaltedDomainHashes = [NSMutableDictionary dictionary];
    for (NSString * unregisteredUsernameFullPath in usernameFullPaths) {
        NSMutableData * saltedDomain = [NSMutableData data];
        NSData * salt = [self saltForUsernameFullPath:unregisteredUsernameFullPath saveSalt:YES inContext:context];
        NSData * usernameDomainData = [unregisteredUsernameFullPath dataUsingEncoding:NSUTF8StringEncoding];
        [saltedDomain appendData:salt];
        [saltedDomain appendData:usernameDomainData];
        [mSaltedDomainHashes setObject:uint256_data([saltedDomain SHA256_2]) forKey:unregisteredUsernameFullPath];
        [self.usernameSalts setObject:salt forKey:unregisteredUsernameFullPath];
    }
    return [mSaltedDomainHashes copy];
}

-(NSString*)dashpayDomainName {
    return @"dash";
}

// MARK: Documents

-(NSArray<DPDocument*>*)preorderDocumentsForUnregisteredUsernameFullPaths:(NSArray*)unregisteredUsernameFullPaths usingEntropyString:(NSString*)entropyString inContext:(NSManagedObjectContext*)context error:(NSError**)error {
    NSMutableArray * usernamePreorderDocuments = [NSMutableArray array];
    for (NSData * saltedDomainHashData in [[self saltedDomainHashesForUsernameFullPaths:unregisteredUsernameFullPaths inContext:context] allValues]) {
        DSStringValueDictionary * dataDictionary = @{
            @"saltedDomainHash": saltedDomainHashData
        };
        DPDocument * document = [self.dpnsDocumentFactory documentOnTable:@"preorder" withDataDictionary:dataDictionary usingEntropy:entropyString  error:error];
        if (*error) {
            return nil;
        }
        [usernamePreorderDocuments addObject:document];
    }
    return usernamePreorderDocuments;
}

-(NSArray<DPDocument*>*)domainDocumentsForUnregisteredUsernameFullPaths:(NSArray*)unregisteredUsernameFullPaths usingEntropyString:(NSString*)entropyString inContext:(NSManagedObjectContext*)context error:(NSError**)error {
    NSMutableArray * usernameDomainDocuments = [NSMutableArray array];
    for (NSString * usernameFullPath in [self saltedDomainHashesForUsernameFullPaths:unregisteredUsernameFullPaths inContext:context]) {
        NSString * username = [self usernameOfUsernameFullPath:usernameFullPath];
        NSString * domain = [self domainOfUsernameFullPath:usernameFullPath];
        DSStringValueDictionary * dataDictionary = @{
            @"label":username,
            @"normalizedLabel": [username lowercaseString],
            @"normalizedParentDomainName":domain,
            @"preorderSalt": [self.usernameSalts objectForKey:usernameFullPath],
            @"records" : @{@"dashUniqueIdentityId":uint256_base58(self.uniqueID)},
            @"subdomainRules" : @{@"allowSubdomains":@NO}
        };
        DPDocument * document = [self.dpnsDocumentFactory documentOnTable:@"domain" withDataDictionary:dataDictionary usingEntropy:entropyString error:error];
        if (*error) {
            return nil;
        }
        [usernameDomainDocuments addObject:document];
    }
    return usernameDomainDocuments;
}

// MARK: Transitions

-(DSDocumentTransition*)preorderTransitionForUnregisteredUsernameFullPaths:(NSArray*)unregisteredUsernameFullPaths inContext:(NSManagedObjectContext*)context error:(NSError**)error  {
    NSString * entropyString = [DSKey randomAddressForChain:self.chain];
    NSArray * usernamePreorderDocuments = [self preorderDocumentsForUnregisteredUsernameFullPaths:unregisteredUsernameFullPaths usingEntropyString:entropyString inContext:context error:error];
    if (![usernamePreorderDocuments count]) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:usernamePreorderDocuments withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID usingEntropyString:entropyString onChain:self.chain];
    return transition;
}

-(DSDocumentTransition*)domainTransitionForUnregisteredUsernameFullPaths:(NSArray*)unregisteredUsernameFullPaths inContext:(NSManagedObjectContext*)context error:(NSError**)error {
    NSString * entropyString = [DSKey randomAddressForChain:self.chain];
    NSArray * usernamePreorderDocuments = [self domainDocumentsForUnregisteredUsernameFullPaths:unregisteredUsernameFullPaths usingEntropyString:entropyString inContext:context error:error];
    if (![usernamePreorderDocuments count]) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:usernamePreorderDocuments withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID usingEntropyString:entropyString onChain:self.chain];
    return transition;
}

// MARK: Registering

-(void)registerUsernamesWithCompletion:(void (^ _Nullable)(BOOL success, NSError * error))completion {
    [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Initial inContext:self.platformContext completion:completion];
}

-(void)registerUsernamesAtStage:(DSBlockchainIdentityUsernameStatus)blockchainIdentityUsernameStatus inContext:(NSManagedObjectContext*)context completion:(void (^ _Nullable)(BOOL success, NSError * error))completion {
    DSDLog(@"registerUsernamesAtStage %lu",(unsigned long)blockchainIdentityUsernameStatus);
    switch (blockchainIdentityUsernameStatus) {
        case DSBlockchainIdentityUsernameStatus_Initial:
        {
            NSArray * usernameFullPaths = [self usernameFullPathsWithStatus:DSBlockchainIdentityUsernameStatus_Initial];
            if (usernameFullPaths.count) {
                [self registerPreorderedSaltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context completion:^(BOOL success, NSError * error) {
                    if (success) {
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending inContext:context completion:completion];
                    } else {
                        if (completion) {
                            completion(NO,error);
                        }
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending inContext:context completion:completion];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending:
        {
            NSArray * usernameFullPaths = [self usernameFullPathsWithStatus:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending];
            NSDictionary<NSString*,NSData *>* saltedDomainHashes = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
            if (saltedDomainHashes.count) {
                [self monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:2 inContext:context completion:^(BOOL allFound, NSError * error) {
                    if (allFound) {
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Preordered inContext:context completion:completion];
                    } else {
                        if (completion) {
                            completion(NO,error);
                        }
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Preordered inContext:context completion:completion];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_Preordered:
        {
            NSArray * usernameFullPaths = [self usernameFullPathsWithStatus:DSBlockchainIdentityUsernameStatus_Preordered];
            if (usernameFullPaths.count) {
                [self registerUsernameDomainsForUsernameFullPaths:usernameFullPaths inContext:context completion:^(BOOL success, NSError * error) {
                    if (success) {
                        [self saveUsernameFullPaths:usernameFullPaths toStatus:DSBlockchainIdentityUsernameStatus_RegistrationPending inContext:context];
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_RegistrationPending inContext:context completion:completion];
                    } else {
                        if (completion) {
                            completion(NO,error);
                        }
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_RegistrationPending inContext:context completion:completion];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_RegistrationPending:
        {
            NSArray * usernameFullPaths = [self usernameFullPathsWithStatus:DSBlockchainIdentityUsernameStatus_RegistrationPending];
            if (usernameFullPaths.count) {
                [self monitorForDPNSUsernameFullPaths:usernameFullPaths withRetryCount:2 inContext:context completion:completion];
            } else {
                if (completion) {
                    completion(NO,nil);
                }
            }
            break;
        }
        default:
            if (completion) {
                completion(NO,nil);
            }
            break;
    }
}

//Preorder stage
-(void)registerPreorderedSaltedDomainHashesForUsernameFullPaths:(NSArray*)usernameFullPaths inContext:(NSManagedObjectContext*)context completion:(void (^ _Nullable)(BOOL success, NSError * error))completion {
    NSError * error = nil;
    DSDocumentTransition * transition = [self preorderTransitionForUnregisteredUsernameFullPaths:usernameFullPaths inContext:context error:&error];
    if (error || !transition) {
        if (completion) {
            completion(NO,error);
        }
        return;
    }
    [self signStateTransition:transition completion:^(BOOL success) {
        if (success) {
            [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (NSString * string in usernameFullPaths) {
                        NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:string] mutableCopy];
                        if (!usernameStatusDictionary) {
                            usernameStatusDictionary = [NSMutableDictionary dictionary];
                        }
                        [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending) forKey:BLOCKCHAIN_USERNAME_STATUS];
                        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:string];
                    }
                    [self saveUsernameFullPaths:usernameFullPaths toStatus:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending inContext:context];
                    if (completion) {
                        completion(YES,nil);
                    }
                });
                
            } failure:^(NSError * _Nonnull error) {
                DSDLog(@"%@", error);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(NO,error);
                    }
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO,[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                               DSLocalizedString(@"Unable to sign transition", nil)}]);
                }
            });
        }
    }];
}

-(void)registerUsernameDomainsForUsernameFullPaths:(NSArray*)usernameFullPaths inContext:(NSManagedObjectContext*)context completion:(void (^ _Nullable)(BOOL success, NSError * error))completion {
    NSError * error = nil;
    DSDocumentTransition * transition = [self domainTransitionForUnregisteredUsernameFullPaths:usernameFullPaths inContext:context error:&error];
    if (error || !transition) {
        if (completion) {
            completion(NO,error);
        }
        return;
    }
    [self signStateTransition:transition completion:^(BOOL success) {
        if (success) {
            [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (NSString * string in usernameFullPaths) {
                        NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:string] mutableCopy];
                        if (!usernameStatusDictionary) {
                            usernameStatusDictionary = [NSMutableDictionary dictionary];
                        }
                        [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_RegistrationPending) forKey:BLOCKCHAIN_USERNAME_STATUS];
                        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:string];
                    }
                    if (completion) {
                        completion(YES,nil);
                    }
                });
                
            } failure:^(NSError * _Nonnull error) {
                DSDLog(@"%@", error);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(NO,error);
                    }
                });
            }];
        }
    }];
}

// MARK: Retrieval

- (void)fetchUsernamesWithCompletion:(void (^)(BOOL, NSError * _Nonnull))completion {
    [self fetchUsernamesInContext:self.platformContext withCompletion:completion];
}

- (void)fetchUsernamesInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(BOOL success, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    DPContract * contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    if (contract.contractState != DPContractState_Registered) {
        if (completion) {
            completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                        DSLocalizedString(@"DPNS Contract is not yet registered on network", nil)}]);
        }
        return;
    }
    [self.DAPINetworkService getDPNSDocumentsForIdentityWithUserId:self.uniqueIdString success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Internal memory allocation error", nil)}]);
            }
            return;
        }
        if (![documents count]) {
            if (completion) {
                completion(YES, nil);
            }
            return;
        }
        //todo verify return is true
        for (NSDictionary * nameDictionary in documents) {
            NSString * username = nameDictionary[@"label"];
            NSString * lowercaseUsername = nameDictionary[@"normalizedLabel"];
            NSString * domain = nameDictionary[@"normalizedParentDomainName"];
            if (username && lowercaseUsername && domain) {
                NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:[self fullPathForUsername:lowercaseUsername inDomain:domain]] mutableCopy];
                BOOL isNew = FALSE;
                if (!usernameStatusDictionary) {
                    usernameStatusDictionary = [NSMutableDictionary dictionary];
                    isNew = TRUE;
                    [usernameStatusDictionary setObject:domain forKey:BLOCKCHAIN_USERNAME_DOMAIN];
                    [usernameStatusDictionary setObject:username forKey:BLOCKCHAIN_USERNAME_PROPER];
                }
                [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_Confirmed) forKey:BLOCKCHAIN_USERNAME_STATUS];
                [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:[self fullPathForUsername:username inDomain:domain]];
                if (isNew) {
                    [self saveNewUsername:username inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed inContext:context];
                } else {
                    [self saveUsername:username inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed salt:nil commitSave:YES inContext:context];
                }
            }
        }
        if (completion) {
            completion(YES, nil);
        }
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            completion(NO, error);
        }
    }];
}



// MARK: - Monitoring

-(void)updateCreditBalance {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        
        [self.DAPINetworkService getIdentityById:self.uniqueIdString success:^(NSDictionary * _Nullable profileDictionary) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            uint64_t creditBalance = (uint64_t)[profileDictionary[@"credits"] longLongValue];
            strongSelf.creditBalance = creditBalance;
        } failure:^(NSError * _Nonnull error) {
            
        }];
    });
}

-(void)monitorForBlockchainIdentityWithRetryCount:(uint32_t)retryCount retryAbsentCount:(uint32_t)retryAbsentCount delay:(NSTimeInterval)delay retryDelayType:(DSBlockchainIdentityRetryDelayType)retryDelayType options:(DSBlockchainIdentityMonitorOptions)options inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL success, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getIdentityById:self.uniqueIdString success:^(NSDictionary * _Nonnull identityDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (identityDictionary.count) {
            [strongSelf applyIdentityDictionary:identityDictionary save:!self.isTransient inContext:context];
            strongSelf.registrationStatus = DSBlockchainIdentityRegistrationStatus_Registered;
            [self saveInContext:context];
        }
        
        if (completion) {
            completion(YES,nil);
        }
    } failure:^(NSError * _Nonnull error) {
        uint32_t nextRetryAbsentCount = retryAbsentCount;
        if ([[error localizedDescription] isEqualToString:@"Identity not found"]) {
            if (!retryAbsentCount) {
                if (completion) {
                    if (options & DSBlockchainIdentityMonitorOptions_AcceptNotFoundAsNotAnError) {
                        completion(YES,nil);
                    } else {
                        completion(NO,error);
                    }
                }
                return;
            }
            nextRetryAbsentCount--;
        }
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSTimeInterval nextDelay = delay;
                switch (retryDelayType) {
                    case DSBlockchainIdentityRetryDelayType_SlowingDown20Percent:
                        nextDelay = delay*1.2;
                        break;
                    case DSBlockchainIdentityRetryDelayType_SlowingDown50Percent:
                        nextDelay = delay*1.5;
                        break;
                        
                    default:
                        break;
                }
                [self monitorForBlockchainIdentityWithRetryCount:retryCount - 1 retryAbsentCount:nextRetryAbsentCount delay:nextDelay retryDelayType:retryDelayType options:options inContext:context completion:completion];
            });
        } else {
            completion(FALSE,error);
        }
    }];
}

-(void)monitorForDPNSUsernameFullPaths:(NSArray*)usernameFullPaths withRetryCount:(uint32_t)retryCount inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL allFound, NSError * error))completion {
    NSMutableDictionary * domains = [NSMutableDictionary dictionary];
    for (NSString * usernameFullPath in usernameFullPaths) {
        NSArray * components = [usernameFullPath componentsSeparatedByString:@"."];
        NSString * domain = @"";
        NSString * name = [components objectAtIndex:0];
        if (components.count > 1) {
            NSArray * domainComponents = [components subarrayWithRange:NSMakeRange(1, components.count - 1)];
            domain = [domainComponents componentsJoinedByString:@"."];
        }
        if (!domains[domain]) {
            domains[domain] = [NSMutableArray array];
        }
        
        [domains[domain] addObject:name];
    }
    __block BOOL finished = FALSE;
    __block NSUInteger countAllFound = 0;
    __block NSUInteger countReturned = 0;
    for (NSString * domain in domains) {
        [self monitorForDPNSUsernames:domains[domain] inDomain:domain withRetryCount:retryCount inContext:context completion:^(BOOL allFound, NSError *error) {
            if (finished) return;
            if (error && !finished) {
                finished = TRUE;
                if (completion) {
                    completion(NO,error);
                }
                return;
            }
            if (allFound) {
                countAllFound++;
            }
            countReturned++;
            if (countReturned == domains.count) {
                finished = TRUE;
                if (completion) {
                    completion(countAllFound == domains.count,nil);
                }
            }
        }];
    }
}

-(void)monitorForDPNSUsernames:(NSArray*)usernames inDomain:(NSString*)domain withRetryCount:(uint32_t)retryCount inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL allFound, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDPNSDocumentsForUsernames:usernames inDomain:domain success:^(id _Nonnull domainDocumentArray) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if ([domainDocumentArray isKindOfClass:[NSArray class]]) {
            NSMutableArray * usernamesLeft = [usernames mutableCopy];
            for (NSString * username in usernames) {
                for (NSDictionary * domainDocument in domainDocumentArray) {
                    NSString * normalizedLabel = [domainDocument objectForKey:@"normalizedLabel"];
                    NSString * label = [domainDocument objectForKey:@"label"];
                    NSString * normalizedParentDomainName = [domainDocument objectForKey:@"normalizedParentDomainName"];
                    if ([normalizedLabel isEqualToString:[username lowercaseString]]) {
                        NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:username] mutableCopy];
                        if (!usernameStatusDictionary) {
                            usernameStatusDictionary = [NSMutableDictionary dictionary];
                            [usernameStatusDictionary setObject:normalizedParentDomainName forKey:BLOCKCHAIN_USERNAME_DOMAIN];
                            [usernameStatusDictionary setObject:label forKey:BLOCKCHAIN_USERNAME_PROPER];
                        }
                        [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_Confirmed) forKey:BLOCKCHAIN_USERNAME_STATUS];
                        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:[self fullPathForUsername:username inDomain:[self dashpayDomainName]]];
                        [strongSelf saveUsername:username inDomain:normalizedParentDomainName status:DSBlockchainIdentityUsernameStatus_Confirmed salt:nil commitSave:YES inContext:context];
                        [usernamesLeft removeObject:username];
                    }
                }
            }
            if ([usernamesLeft count] && retryCount > 0) {
                [strongSelf monitorForDPNSUsernames:usernamesLeft inDomain:domain withRetryCount:retryCount - 1 inContext:context completion:completion];
            } else if ([usernamesLeft count]) {
                if (completion) {
                    completion(FALSE, [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                   DSLocalizedString(@"Requested username domain documents not present on platform after timeout", nil)}]);
                }
            } else {
                if (completion) {
                    completion(TRUE, nil);
                }
            }
        } else if (retryCount > 0) {
            [strongSelf monitorForDPNSUsernames:usernames inDomain:domain withRetryCount:retryCount - 1 inContext:context completion:completion];
        } else {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Malformed platform response", nil)}]);
            }
        }
    } failure:^(NSError * _Nonnull error) {
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                [strongSelf monitorForDPNSUsernames:usernames inDomain:domain withRetryCount:retryCount - 1 inContext:context completion:completion];
            });
        } else {
            completion(FALSE, error);
        }
    }];
}

-(void)monitorForDPNSPreorderSaltedDomainHashes:(NSDictionary*)saltedDomainHashes withRetryCount:(uint32_t)retryCount inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL allFound, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDPNSDocumentsForPreorderSaltedDomainHashes:[saltedDomainHashes allValues] success:^(id _Nonnull preorderDocumentArray) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Internal memory allocation error", nil)}]);
            }
            return;
        }
        if ([preorderDocumentArray isKindOfClass:[NSArray class]]) {
            NSMutableArray * usernamesLeft = [[saltedDomainHashes allKeys] mutableCopy];
            for (NSString * usernameFullPath in saltedDomainHashes) {
                NSData * saltedDomainHashData = saltedDomainHashes[usernameFullPath];
                for (NSDictionary * preorderDocument in preorderDocumentArray) {
                    if ([[preorderDocument objectForKey:@"saltedDomainHash"] isEqualToData:saltedDomainHashData]) {
                        NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:usernameFullPath] mutableCopy];
                        if (!usernameStatusDictionary) {
                            usernameStatusDictionary = [NSMutableDictionary dictionary];
                        }
                        [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_Preordered) forKey:BLOCKCHAIN_USERNAME_STATUS];
                        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:usernameFullPath];
                        [strongSelf saveUsernameFullPath:usernameFullPath status:DSBlockchainIdentityUsernameStatus_Preordered salt:nil commitSave:YES inContext:context];
                        [usernamesLeft removeObject:usernameFullPath];
                    }
                }
            }
            if ([usernamesLeft count] && retryCount > 0) {
                NSDictionary * saltedDomainHashesLeft = [saltedDomainHashes dictionaryWithValuesForKeys:usernamesLeft];
                [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashesLeft withRetryCount:retryCount - 1 inContext:context completion:completion];
            } else if ([usernamesLeft count]) {
                if (completion) {
                    completion(FALSE, [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                   DSLocalizedString(@"Requested username preorder documents not present on platform after timeout", nil)}]);
                }
            } else {
                if (completion) {
                    completion(TRUE, nil);
                }
            }
        } else if (retryCount > 0) {
            [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:retryCount - 1 inContext:context completion:completion];
        } else {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Malformed platform response", nil)}]);
            }
        }
    } failure:^(NSError * _Nonnull error) {
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    if (completion) {
                        completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                    DSLocalizedString(@"Internal memory allocation error", nil)}]);
                    }
                    return;
                }
                [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:retryCount - 1 inContext:context completion:completion];
            });
        } else {
            if (completion) {
                completion(FALSE,error);
            }
        }
    }];
}

-(void)monitorForContract:(DPContract*)contract withRetryCount:(uint32_t)retryCount inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL success, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    NSParameterAssert(contract);
    if (!contract) return;
    [self.DAPINetworkService fetchContractForId:contract.base58ContractId success:^(id _Nonnull contractDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Internal memory allocation error", nil)}]);
            }
            return;
        }
        DSDLog(@"Contract dictionary is %@",contractDictionary);
        if ([contractDictionary isKindOfClass:[NSDictionary class]] && [contractDictionary[@"$id"] isEqualToString:contract.base58ContractId]) {
            [contract setContractState:DPContractState_Registered inContext:context];
            if (completion) {
                completion(TRUE,nil);
            }
        } else if (retryCount > 0) {
            [strongSelf monitorForContract:contract withRetryCount:retryCount - 1 inContext:context completion:completion];
        } else {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Malformed platform response", nil)}]);
            }
        }
    } failure:^(NSError * _Nonnull error) {
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    if (completion) {
                        completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                    DSLocalizedString(@"Internal memory allocation error", nil)}]);
                    }
                    return;
                }
                [strongSelf monitorForContract:contract withRetryCount:retryCount - 1 inContext:context completion:completion];
            });
        } else {
            if (completion) {
                completion(FALSE,error);
            }
        }
    }];
}

//-(void)registerContract:(DPContract*)contract {
//    __weak typeof(self) weakSelf = self;
//    [self.DAPINetworkService getUserById:self.uniqueIdString success:^(NSDictionary * _Nonnull profileDictionary) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) {
//            return;
//        }
//        uint64_t creditBalance = (uint64_t)[profileDictionary[@"credits"] longLongValue];
//        strongSelf.creditBalance = creditBalance;
//        strongSelf.registrationStatus = DSBlockchainIdentityRegistrationStatus_Registered;
//        [self save];
//    } failure:^(NSError * _Nonnull error) {
//        if (retryCount > 0) {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                [self monitorForBlockchainIdentityWithRetryCount:retryCount - 1];
//            });
//        }
//    }];
//}

// MARK: - Dashpay

// MARK: Helpers

- (BOOL)isDashpayReady {
    if (self.activeKeyCount == 0) {
        return NO;
    }
    if (!self.isRegistered) {
        return NO;
    }
    return YES;
}

-(DPDocument*)matchingDashpayUserProfileDocumentForEntropyString:(NSString*)entropyString inContext:(NSManagedObjectContext*)context {
    //The revision must be at least at 1, otherwise nothing was ever done
    DSDashpayUserEntity * matchingDashpayUser = [self matchingDashpayUserInContext:context];
    if (matchingDashpayUser && matchingDashpayUser.localProfileDocumentRevision) {
        __block DSStringValueDictionary * dataDictionary = nil;
        
        [context performBlockAndWait:^{
            dataDictionary = @{
                @"publicMessage": matchingDashpayUser.publicMessage?matchingDashpayUser.publicMessage:@"",
                @"avatarUrl": matchingDashpayUser.avatarPath?matchingDashpayUser.avatarPath:@"https://api.adorable.io/avatars/120/example",
                @"displayName": matchingDashpayUser.displayName?matchingDashpayUser.displayName:(self.currentDashpayUsername?self.currentDashpayUsername:@""),
                @"$revision": @(matchingDashpayUser.localProfileDocumentRevision)
            };
        }];
        NSError * error = nil;
        DPDocument * document = [self.dashpayDocumentFactory documentOnTable:@"profile" withDataDictionary:dataDictionary usingEntropy:entropyString error:&error];
        return document;
    } else {
        return nil;
    }
}


- (DSBlockchainIdentityFriendshipStatus)friendshipStatusForRelationshipWithBlockchainIdentity:(DSBlockchainIdentity*)otherBlockchainIdentity {
    if (!self.matchingDashpayUserInViewContext) return DSBlockchainIdentityFriendshipStatus_Unknown;
    __block BOOL isIncoming;
    __block BOOL isOutgoing;
    [self.matchingDashpayUserInViewContext.managedObjectContext performBlockAndWait:^{
        isIncoming = !![self.matchingDashpayUserInViewContext.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact.associatedBlockchainIdentity.uniqueID == %@", uint256_data(otherBlockchainIdentity.uniqueID)]].count;
        isOutgoing = !![self.matchingDashpayUserInViewContext.outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact.associatedBlockchainIdentity.uniqueID == %@", uint256_data(otherBlockchainIdentity.uniqueID)]].count;
    }];
    return ((isIncoming << 1) | isOutgoing );
}


// MARK: Sending a Friend Request


-(void)setDashpaySyncronizationBlockHash:(UInt256)dashpaySyncronizationBlockHash {
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

// MARK: Sending a Friend Request

- (void)sendNewFriendRequestToBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity completion:(void (^)(BOOL success, NSArray<NSError *> * _Nullable errors))completion {
    [self sendNewFriendRequestToBlockchainIdentity:blockchainIdentity inContext:self.platformContext completion:completion];
}

- (void)sendNewFriendRequestToBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL success, NSArray<NSError *> * _Nullable errors))completion {
    if (blockchainIdentity.isTransient) {
        blockchainIdentity.isTransient = FALSE;
        [self.identitiesManager registerForeignBlockchainIdentity:blockchainIdentity];
    }
    [blockchainIdentity fetchNeededNetworkStateInformationWithCompletion:^(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * _Nullable errors) {
        if (failureStep && failureStep != DSBlockchainIdentityQueryStep_Profile) { //if profile fails we can still continue on
            completion(NO, errors);
            return;
        }
        if (![blockchainIdentity isDashpayReady]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"User has actions to complete before being able to use Dashpay", nil)}]]);
            });
            
            return;
        }
        uint32_t destinationKeyIndex = [blockchainIdentity firstIndexOfKeyOfType:self.currentMainKeyType createIfNotPresent:NO saveKey:NO];
        uint32_t sourceKeyIndex = [self firstIndexOfKeyOfType:self.currentMainKeyType createIfNotPresent:NO saveKey:NO];
        
        
        DSAccount * account = [self.wallet accountWithNumber:0];
        if (sourceKeyIndex == UINT32_MAX) { //not found
            //to do register a new key
            NSAssert(FALSE, @"we shouldn't be getting here");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO,@[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                               DSLocalizedString(@"Internal key handling error", nil)}]]);
                });
            }
            return;
        }
        DSPotentialOneWayFriendship * potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationBlockchainIdentity:blockchainIdentity destinationKeyIndex:destinationKeyIndex sourceBlockchainIdentity:self sourceKeyIndex:sourceKeyIndex account:account];
        
        [potentialFriendship createDerivationPathWithCompletion:^(BOOL success, DSIncomingFundsDerivationPath * _Nonnull incomingFundsDerivationPath) {
            if (!success) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(NO,@[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                   DSLocalizedString(@"Internal key handling error", nil)}]]);
                    });
                }
                return;
            }
            [potentialFriendship encryptExtendedPublicKeyWithCompletion:^(BOOL success) {
                if (!success) {
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(NO,@[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                       DSLocalizedString(@"Internal key handling error", nil)}]]);
                        });
                    }
                    return;
                }
                [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship inContext:context completion:completion];
            }];
            
        }];
    }];
}

- (void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL success, NSArray<NSError *> * _Nullable errors))completion {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getIdentityByName:potentialContact.username inDomain:[self dashpayDomainName] success:^(NSDictionary *_Nonnull blockchainIdentityDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO, @[[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Internal memory allocation error", nil)}]]);
            }
            return;
        }
        NSString * base58String = nil;
        if (!blockchainIdentityDictionary || !(base58String = blockchainIdentityDictionary[@"id"])) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                DSLocalizedString(@"Malformed platform response", nil)}]]);
                });
            }
            return;
        }
        
        UInt256 blockchainIdentityContactUniqueId = base58String.base58ToData.UInt256;
        
        NSAssert(!uint256_is_zero(blockchainIdentityContactUniqueId), @"blockchainIdentityContactUniqueId should not be null");
        
        DSBlockchainIdentityEntity * potentialContactBlockchainIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:self.platformContext matching:@"uniqueID == %@",uint256_data(blockchainIdentityContactUniqueId)];
        
        DSBlockchainIdentity * potentialContactBlockchainIdentity = nil;
        
        if (potentialContactBlockchainIdentityEntity) {
            potentialContactBlockchainIdentity = [self.chain blockchainIdentityForUniqueId:blockchainIdentityContactUniqueId];
            if (!potentialContactBlockchainIdentity) {
                potentialContactBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:potentialContactBlockchainIdentityEntity];
            }
        } else {
            potentialContactBlockchainIdentity = [self.identitiesManager foreignBlockchainIdentityWithUniqueId:blockchainIdentityContactUniqueId createIfMissing:YES inContext:self.platformContext];
        }
        [potentialContactBlockchainIdentity applyIdentityDictionary:blockchainIdentityDictionary save:YES inContext:self.platformContext];
        [potentialContactBlockchainIdentity saveInContext:self.platformContext];
        
        [self sendNewFriendRequestToBlockchainIdentity:potentialContactBlockchainIdentity completion:completion];
    } failure:^(NSError *_Nonnull error) {
        DSDLog(@"%@", error);
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO,@[error]);
            });
        }
    }];
}

- (void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialOneWayFriendship*)potentialFriendship completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship inContext:self.platformContext completion:completion];
}

- (void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialOneWayFriendship*)potentialFriendship inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    DSDashpayUserEntity * destinationDashpayUser = [potentialFriendship.destinationBlockchainIdentity matchingDashpayUserInContext:context];
    if (!destinationDashpayUser) {
        NSAssert([potentialFriendship.destinationBlockchainIdentity matchingDashpayUserInContext:context], @"There must be a destination contact if the destination blockchain identity is not known");
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    NSString * entropyString = [DSKey randomAddressForChain:self.chain];
    DPDocument * document = [potentialFriendship contactRequestDocumentWithEntropy:entropyString];
    [self.DAPIClient sendDocument:document forIdentity:self contract:contract usingEntropyString:entropyString completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @[[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                DSLocalizedString(@"Internal memory allocation error", nil)}]]);
                });
            }
            return;
        }
        
        BOOL success = error == nil;
        
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @[error]);
            });
            return;
        }
        
        [context performBlockAndWait:^{
            [self addFriendship:potentialFriendship inContext:context completion:^(BOOL success, NSError *error) {
                
            }];
//            [self addFriendshipFromSourceBlockchainIdentity:potentialFriendship.sourceBlockchainIdentity sourceKeyIndex:potentialFriendship.so toRecipientBlockchainIdentity:<#(DSBlockchainIdentity *)#> recipientKeyIndex:<#(uint32_t)#> inContext:<#(NSManagedObjectContext *)#>]
//             DSFriendRequestEntity * friendRequest = [potentialFriendship outgoingFriendRequestForDashpayUserEntity:potentialFriendship.destinationBlockchainIdentity.matchingDashpayUser];
//                   [strongSelf.matchingDashpayUser addOutgoingRequestsObject:friendRequest];
//
//                   if ([[friendRequest.destinationContact.outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact == %@",strongSelf.matchingDashpayUser]] count]) {
//                       [strongSelf.matchingDashpayUser addFriendsObject:friendRequest.destinationContact];
//                   }
//                   [potentialFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequest];
//                   [DSFriendRequestEntity saveContext];
//                   if (completion) {
//                       dispatch_async(dispatch_get_main_queue(), ^{
//                           completion(success,error);
//                       });
//                   }
        }];
        
        [self fetchOutgoingContactRequestsInContext:context withCompletion:^(BOOL success, NSArray<NSError *> * _Nonnull errors) {
           if (completion) {
               dispatch_async(dispatch_get_main_queue(), ^{
                   completion(success,errors);
               });
           }
        }];
    }];
}

-(void)acceptFriendRequestFromBlockchainIdentity:(DSBlockchainIdentity*)otherBlockchainIdentity completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    [self acceptFriendRequestFromBlockchainIdentity:otherBlockchainIdentity inContext:self.platformContext completion:completion];
}

-(void)acceptFriendRequestFromBlockchainIdentity:(DSBlockchainIdentity*)otherBlockchainIdentity inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) {
        if (completion) {
            completion(NO,@[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                   DSLocalizedString(@"Accepting a friend request should only happen from a local blockchain identity", nil)}]]);
        }
        return;
    }

    [context performBlockAndWait:^{
        DSDashpayUserEntity * matchingDashpayUser = [self matchingDashpayUserInContext:context];
        DSFriendRequestEntity * friendRequest = [[matchingDashpayUser.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact.associatedBlockchainIdentity.uniqueID == %@", uint256_data(otherBlockchainIdentity.uniqueID)]] anyObject];
        if (!friendRequest) {
            if (completion) {
                completion(NO,@[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                       DSLocalizedString(@"You can only accept a friend request from blockchain identity who has sent you one, and none were found", nil)}]]);
            }
        } else {
            [self acceptFriendRequest:friendRequest completion:completion];
        }
    }];
}

-(void)acceptFriendRequest:(DSFriendRequestEntity*)friendRequest completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) {
        if (completion) {
            completion(NO,@[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                   DSLocalizedString(@"Accepting a friend request should only happen from a local blockchain identity", nil)}]]);
        }
        return;
    }
    DSAccount * account = [self.wallet accountWithNumber:0];
    DSDashpayUserEntity * otherDashpayUser = friendRequest.sourceContact;
    DSBlockchainIdentity * otherBlockchainIdentity = [self.chain blockchainIdentityForUniqueId:otherDashpayUser.associatedBlockchainIdentity.uniqueID.UInt256];
    
    if (!otherBlockchainIdentity) {
        otherBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:otherDashpayUser.associatedBlockchainIdentity];
    }
    //    DSPotentialContact *contact = [[DSPotentialContact alloc] initWithUsername:friendRequest.sourceContact.username avatarPath:friendRequest.sourceContact.avatarPath
    //                                                                 publicMessage:friendRequest.sourceContact.publicMessage];
    //    [contact setAssociatedBlockchainIdentityUniqueId:friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID.UInt256];
    //    DSKey * friendsEncyptionKey = [otherBlockchainIdentity keyOfType:friendRequest.sourceEncryptionPublicKeyIndex atIndex:friendRequest.sourceEncryptionPublicKeyIndex];
    //[DSKey keyWithPublicKeyData:friendRequest.sourceContact.encryptionPublicKey forKeyType:friendRequest.sourceContact.encryptionPublicKeyType onChain:self.chain];
    //    [contact addPublicKey:friendsEncyptionKey atIndex:friendRequest.sourceContact.encryptionPublicKeyIndex];
    //    uint32_t sourceKeyIndex = [self firstIndexOfKeyOfType:friendRequest.sourceContact.encryptionPublicKeyType createIfNotPresent:NO];
    //    if (sourceKeyIndex == UINT32_MAX) { //not found
    //        //to do register a new key
    //        NSAssert(FALSE, @"we shouldn't be getting here");
    //        return;
    //    }
    DSPotentialOneWayFriendship *potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationBlockchainIdentity:otherBlockchainIdentity destinationKeyIndex:friendRequest.sourceKeyIndex sourceBlockchainIdentity:self sourceKeyIndex:friendRequest.destinationKeyIndex account:account];
    [potentialFriendship createDerivationPathWithCompletion:^(BOOL success, DSIncomingFundsDerivationPath * _Nonnull incomingFundsDerivationPath) {
        if (success) {
            [potentialFriendship encryptExtendedPublicKeyWithCompletion:^(BOOL success) {
                if (!success) {
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(NO,@[[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                       DSLocalizedString(@"Internal key handling error", nil)}]]);
                        });
                    }
                    return;
                }
                [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship inContext:friendRequest.managedObjectContext completion:completion];
            }];
        } else {
            if (completion) {
                completion(NO, @[[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                DSLocalizedString(@"Count not create friendship derivation path", nil)}]]);
            }
        }
    }];
    
    
    
}

// MARK: Profile

-(DSDocumentTransition*)profileDocumentTransitionInContext:(NSManagedObjectContext*)context {
    NSString * entropyString = [DSKey randomAddressForChain:self.chain];
    DPDocument * profileDocument = [self matchingDashpayUserProfileDocumentForEntropyString:entropyString inContext:context];
    if (!profileDocument) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:@[profileDocument] withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID usingEntropyString:entropyString onChain:self.chain];
    return transition;
}

- (void)updateDashpayProfileWithDisplayName:(NSString*)displayName publicMessage:(NSString*)publicMessage avatarURLString:(NSString *)avatarURLString {
    [self updateDashpayProfileWithDisplayName:displayName publicMessage:publicMessage avatarURLString:avatarURLString inContext:self.platformContext];
}

- (void)updateDashpayProfileWithDisplayName:(NSString*)displayName publicMessage:(NSString*)publicMessage avatarURLString:(NSString *)avatarURLString inContext:(NSManagedObjectContext*)context {
    [context performBlockAndWait:^{
        DSDashpayUserEntity * matchingDashpayUser = [self matchingDashpayUserInContext:context];
        matchingDashpayUser.displayName = displayName;
        matchingDashpayUser.publicMessage = publicMessage;
        matchingDashpayUser.avatarPath = avatarURLString;
        matchingDashpayUser.localProfileDocumentRevision++;
        [context ds_save];
    }];
}

-(void)signedProfileDocumentTransitionInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(DSTransition * transition, BOOL cancelled, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    DSDocumentTransition * transition = [self profileDocumentTransitionInContext:context];
    if (!transition) {
        if (completion) {
            completion(nil, NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Transition had nothing to update", nil)}]);
        }
        return;
    }
    [self signStateTransition:transition completion:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(nil, NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                DSLocalizedString(@"Internal memory allocation error", nil)}]);
            }
            return;
        }
        if (success) {
            completion(transition,NO,nil);
        }
    }];
}

- (void)signAndPublishProfileWithCompletion:(void (^)(BOOL success, BOOL cancelled, NSError * error))completion {
    [self signAndPublishProfileInContext:self.platformContext withCompletion:completion];
}

- (void)signAndPublishProfileInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(BOOL success, BOOL cancelled, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    __block uint32_t profileDocumentRevision;
    [context performBlockAndWait:^{
        profileDocumentRevision = [self matchingDashpayUserInContext:context].localProfileDocumentRevision;
        [context ds_save];
    }];
    [self signedProfileDocumentTransitionInContext:context withCompletion:^(DSTransition *transition, BOOL cancelled, NSError *error) {
        if (!transition) {
            if (completion) {
                completion(NO, cancelled, error);
            }
            return;
        }
        [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                if (completion) {
                    completion(NO, NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                    DSLocalizedString(@"Internal memory allocation error", nil)}]);
                }
                return;
            }
            [context performBlockAndWait:^{
                [self matchingDashpayUserInContext:context].remoteProfileDocumentRevision = profileDocumentRevision;
                [context ds_save];
            }];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, NO, nil);
                });
            }
        } failure:^(NSError * _Nonnull error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, NO, error);
                });
            }
        }];
    }];
}

//

// MARK: Fetching

- (void)fetchProfileWithCompletion:(void (^)(BOOL success, NSError * error))completion {
    [self fetchProfileInContext:self.platformContext withCompletion:completion];
}

- (void)fetchProfileInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(BOOL success, NSError * error))completion {
    
    DPContract * dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Dashpay Contract is not yet registered on network", nil)}]);
            });
        }
        return;
    }
    
    [self fetchProfileForBlockchainIdentityUniqueId:self.uniqueID saveReturnedProfile:TRUE inContext:context completion:^(BOOL success, NSError * error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
            });
        }
    }];
}

- (void)fetchProfileForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId saveReturnedProfile:(BOOL)saveReturnedProfile inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL success, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    
    DPContract * dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"The Dashpay contract is not properly set up", nil)}]);
            });
        }
        return;
    }
    
    [self.DAPINetworkService getDashpayProfileForUserId:uint256_base58(blockchainIdentityUniqueId) success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Internal memory allocation error", nil)}]);
            }
            return;
        }
        dispatch_async(self.identityQueue, ^{
        
            NSDictionary * contactDictionary = [documents firstObject];
            [context performBlockAndWait:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    if (completion) {
                        completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                    DSLocalizedString(@"Internal memory allocation error", nil)}]);
                    }
                    return;
                }
                DSDashpayUserEntity * contact = [[self blockchainIdentityEntityInContext:context] matchingDashpayUser];
                if (!contact) {
                    NSAssert(FALSE, @"It is weird to get here");
                    contact = [DSDashpayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentity.uniqueID == %@", uint256_data(blockchainIdentityUniqueId)];
                }
                if (!contact || [[contactDictionary objectForKey:@"$revision"] intValue] != contact.localProfileDocumentRevision) {
                    
                    if (!contact) {
                        contact = [DSDashpayUserEntity managedObjectInContext:context];
                        contact.chain = [strongSelf.wallet.chain chainEntityInContext:context];
                        DSBlockchainIdentity * blockchainIdentity;
                        if (uint256_eq(blockchainIdentityUniqueId, strongSelf.uniqueID) && (![strongSelf matchingDashpayUserInContext:context])) {
                            NSAssert([strongSelf blockchainIdentityEntityInContext:context], @"blockchainIdentityEntity must exist");
                            contact.associatedBlockchainIdentity = [strongSelf blockchainIdentityEntityInContext:context];
                            if (saveReturnedProfile) {
                                [context ds_save];
                            }
                        } else if ((blockchainIdentity = [strongSelf.wallet blockchainIdentityForUniqueId:blockchainIdentityUniqueId]) && ![blockchainIdentity matchingDashpayUserInContext:context]) {
                            //this means we are fetching a contact for another blockchain user on the device
                            DSBlockchainIdentity * blockchainIdentity = [strongSelf.wallet blockchainIdentityForUniqueId:blockchainIdentityUniqueId];
                            contact.associatedBlockchainIdentity = [blockchainIdentity blockchainIdentityEntityInContext:context];
                            NSAssert(contact.associatedBlockchainIdentity, @"blockchainIdentityEntity must exist");
                        }
                    }
                    if (contactDictionary) {
                        contact.localProfileDocumentRevision = [[contactDictionary objectForKey:@"$revision"] intValue];
                        contact.remoteProfileDocumentRevision = [[contactDictionary objectForKey:@"$revision"] intValue];
                        contact.avatarPath = [contactDictionary objectForKey:@"avatarUrl"];
                        contact.publicMessage = [contactDictionary objectForKey:@"about"];
                        contact.displayName = [contactDictionary objectForKey:@"displayName"];
                        contact.createdAt = 1; //[contactDictionary objectForKey:@"createdAt"]; //todo
                        contact.updatedAt = 1; //[contactDictionary objectForKey:@"updatedAt"];
                    }
                    
                    if (saveReturnedProfile) {
                        [context ds_save];
                    }
                }
                
                [self.platformContext performBlockAndWait:^{
                    self.lastCheckedProfileTimestamp = [[NSDate date] timeIntervalSince1970];
                    //[self saveInContext:self.platformContext];
                }];
                
                if (completion) {

                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(YES,nil);
                    });
                }
            }];
        });
        
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO,error);
            });
        }
    }];
}

-(void)fetchContactRequests:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    [self fetchContactRequestsInContext:self.platformContext withCompletion:completion];
}

-(void)fetchContactRequestsInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    __weak typeof(self) weakSelf = self;
    [self fetchIncomingContactRequestsInContext:context withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO, @[[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                            DSLocalizedString(@"Internal memory allocation error", nil)}]]);
            }
            return;
        }
        if (!success) {
            if (completion) {
                completion(success, errors);
            }
            return;
        }
    
        [strongSelf fetchOutgoingContactRequestsInContext:context withCompletion:completion];
    }];
}

- (void)fetchIncomingContactRequests:(void (^ _Nullable)(BOOL success, NSArray<NSError *> *errors))completion {
    [self fetchIncomingContactRequestsInContext:self.platformContext withCompletion:completion];
}

- (void)fetchIncomingContactRequestsInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    DPContract * dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if (dashpayContract.contractState != DPContractState_Registered) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @[[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                              DSLocalizedString(@"The Dashpay contract is not properly set up", nil)}]]);
            });
        }
        return;
    }
    NSError * error = nil;
    if (![self activePrivateKeysAreLoadedWithFetchingError:&error]) {
        //The blockchain identity hasn't been intialized on the device, ask the user to activate the blockchain user, this action allows private keys to be cached on the blockchain identity level
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @[error?error:[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                              DSLocalizedString(@"The blockchain identity hasn't yet been locally activated", nil)}]]);
            });
        }
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDashpayIncomingContactRequestsForUserId:self.uniqueIDData since:self.lastCheckedIncomingContactsTimestamp?(self.lastCheckedIncomingContactsTimestamp - HOUR_TIME_INTERVAL):0 success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        //todo chance the since parameter
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @[[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                  DSLocalizedString(@"Internal memory allocation error", nil)}]]);
                });
            }
            return;
        }
        
        [strongSelf handleContactRequestObjects:documents context:context completion:^(BOOL success, NSArray<NSError *> *errors) {
            [self.platformContext performBlockAndWait:^{
                self.lastCheckedIncomingContactsTimestamp = [[NSDate date] timeIntervalSince1970];
                //[self saveInContext:self.platformContext];
            }];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(success, errors);
                });
            }
        }];
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @[error]);
            });
        }
    }];
}

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success,  NSArray<NSError *> *errors))completion {
    [self fetchOutgoingContactRequestsInContext:self.platformContext withCompletion:completion];
}

- (void)fetchOutgoingContactRequestsInContext:(NSManagedObjectContext*)context withCompletion:(void (^)(BOOL success,  NSArray<NSError *> *errors))completion {
    
    DPContract * dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if (dashpayContract.contractState != DPContractState_Registered) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @[[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                              DSLocalizedString(@"The Dashpay contract is not properly set up", nil)}]]);
            });
        }
        return;
    }
    NSError * error = nil;
    if (![self activePrivateKeysAreLoadedWithFetchingError:&error]) {
        //The blockchain identity hasn't been intialized on the device, ask the user to activate the blockchain user, this action allows private keys to be cached on the blockchain identity level
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @[error?error:[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                              DSLocalizedString(@"The blockchain identity hasn't yet been locally activated", nil)}]]);
            });
        }
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDashpayOutgoingContactRequestsForUserId:self.uniqueIdString since:self.lastCheckedOutgoingContactsTimestamp?(self.lastCheckedOutgoingContactsTimestamp - HOUR_TIME_INTERVAL):0 success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        //todo chance the since parameter
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @[[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                  DSLocalizedString(@"Internal memory allocation error", nil)}]]);
                });
            }
            return;
        }
        
        [strongSelf handleContactRequestObjects:documents context:context completion:^(BOOL success, NSArray<NSError *> *errors) {
            dispatch_async(self.identityQueue, ^{
                [self.platformContext performBlockAndWait:^{
                    self.lastCheckedOutgoingContactsTimestamp = [[NSDate date] timeIntervalSince1970];
                    //[self saveInContext:self.platformContext];
                }];
            });
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success,errors);
            });
        }];
        
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO,@[error]);
            });
        }
    }];
}

// MARK: Response Processing

/// Handle an array of contact requests. This method will split contact requests into either incoming contact requests or outgoing contact requests and then call methods for handling them if applicable.
/// @param rawContactRequests A dictionary of rawContactRequests, these are returned by the network.
/// @param context The managed object context in which to process results.
/// @param completion Completion callback with success boolean.
- (void)handleContactRequestObjects:(NSArray<NSDictionary *> *)rawContactRequests context:(NSManagedObjectContext *)context completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    NSMutableArray <DSContactRequest *> *incomingNewRequests = [NSMutableArray array];
    NSMutableArray <DSContactRequest *> *outgoingNewRequests = [NSMutableArray array];
    __block NSMutableArray * rErrors = [NSMutableArray array];
    for (NSDictionary *rawContact in rawContactRequests) {
        DSContactRequest * contactRequest = [DSContactRequest contactRequestFromDictionary:rawContact onBlockchainIdentity:self];
        
        if (uint256_eq(contactRequest.recipientBlockchainIdentityUniqueId, self.uniqueID)) {
            //we are the recipient, this is an incoming request
            DSFriendRequestEntity * friendRequest = [DSFriendRequestEntity anyObjectInContext:context matching:@"destinationContact == %@ && sourceContact.associatedBlockchainIdentity.uniqueID == %@",[self matchingDashpayUserInContext:context],uint256_data(contactRequest.senderBlockchainIdentityUniqueId)];
            if (!friendRequest) {
                [incomingNewRequests addObject:contactRequest];
            } else if (friendRequest.sourceContact == nil) {
                
            }
        } else if (uint256_eq(contactRequest.senderBlockchainIdentityUniqueId, self.uniqueID)) {
            //we are the sender, this is an outgoing request
            BOOL isNew = ![DSFriendRequestEntity countObjectsInContext:context matching:@"sourceContact == %@ && destinationContact.associatedBlockchainIdentity.uniqueID == %@",[self matchingDashpayUserInContext:context],[NSData dataWithUInt256:contactRequest.recipientBlockchainIdentityUniqueId]];
            if (isNew) {
                [outgoingNewRequests addObject:contactRequest];
            }
        } else {
            //we should not have received this
            NSAssert(FALSE, @"the contact request needs to be either outgoing or incoming");
        }
    }
    
    __block BOOL succeeded = YES;
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    if ([incomingNewRequests count]) {
        dispatch_group_enter(dispatchGroup);
        [self handleIncomingRequests:incomingNewRequests context:context completion:^(BOOL success, NSArray<NSError *> * errors) {
            if (!success) {
                succeeded = NO;
                [rErrors addObjectsFromArray:errors];
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
    if ([outgoingNewRequests count]) {
        dispatch_group_enter(dispatchGroup);
        [self handleOutgoingRequests:outgoingNewRequests context:context completion:^(BOOL success, NSArray<NSError *> * errors) {
            if (!success) {
                succeeded = NO;
                [rErrors addObjectsFromArray:errors];
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        if (completion) {
            completion(succeeded,[rErrors copy]);
        }
    });
}

- (void)handleIncomingRequests:(NSArray <DSContactRequest*> *)incomingRequests
                       context:(NSManagedObjectContext *)context
                    completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    [context performBlockAndWait:^{
        
        __block BOOL succeeded = YES;
        __block NSMutableArray * errors = [NSMutableArray array];
        dispatch_group_t dispatchGroup = dispatch_group_create();
        
        for (DSContactRequest * contactRequest in incomingRequests) {
            DSBlockchainIdentityEntity * externalBlockchainIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@",uint256_data(contactRequest.senderBlockchainIdentityUniqueId)];
            if (!externalBlockchainIdentityEntity) {
                //no externalBlockchainIdentity exists yet, which means no dashpay user
                dispatch_group_enter(dispatchGroup);
                DSBlockchainIdentity * senderBlockchainIdentity = [self.identitiesManager foreignBlockchainIdentityWithUniqueId:contactRequest.senderBlockchainIdentityUniqueId createIfMissing:YES inContext:context];
                
                [senderBlockchainIdentity fetchNeededNetworkStateInformationWithCompletion:^(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * _Nullable networkErrors) {
                    if (!failureStep) {
                        DSKey * senderPublicKey = [senderBlockchainIdentity keyAtIndex:contactRequest.senderKeyIndex];
                        NSData * extendedPublicKeyData = [contactRequest decryptedPublicKeyDataWithKey:senderPublicKey];
                        DSECDSAKey * extendedPublicKey = [DSECDSAKey keyWithExtendedPublicKeyData:extendedPublicKeyData];
                        if (!extendedPublicKey) {
                            succeeded = FALSE;
                            [errors addObject:[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                           DSLocalizedString(@"Incorrect key format after contact request decryption", nil)}]];
                        } else {
                            DSDashpayUserEntity * senderDashpayUserEntity = [senderBlockchainIdentity blockchainIdentityEntityInContext:context].matchingDashpayUser;
                            NSAssert(senderDashpayUserEntity, @"The sender should exist");
                            [self addIncomingRequestFromContact:senderDashpayUserEntity
                                           forExtendedPublicKey:extendedPublicKey
                                                    atTimestamp:contactRequest.createdAt];
                        }
                    } else {
                        [errors addObjectsFromArray:networkErrors];
                    }
                    dispatch_group_leave(dispatchGroup);
                }];
                
            } else {
                if ([self.chain blockchainIdentityForUniqueId:externalBlockchainIdentityEntity.uniqueID.UInt256]) {
                    //it's also local (aka both contacts are local to this device), we should store the extended public key for the destination
                    DSBlockchainIdentity * sourceBlockchainIdentity = [self.chain blockchainIdentityForUniqueId:externalBlockchainIdentityEntity.uniqueID.UInt256];
                    
                    DSAccount * account = [sourceBlockchainIdentity.wallet accountWithNumber:0];
                    
                    DSPotentialOneWayFriendship * potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationBlockchainIdentity:self destinationKeyIndex:contactRequest.recipientKeyIndex sourceBlockchainIdentity:sourceBlockchainIdentity sourceKeyIndex:contactRequest.senderKeyIndex account:account];
                    
                    dispatch_group_enter(dispatchGroup);
                    [potentialFriendship createDerivationPathWithCompletion:^(BOOL success, DSIncomingFundsDerivationPath * _Nonnull incomingFundsDerivationPath) {
                        if (success) {
                            DSDashpayUserEntity * matchingDashpayUserInContext = [self matchingDashpayUserInContext:context];
                            DSFriendRequestEntity * friendRequest = [potentialFriendship outgoingFriendRequestForDashpayUserEntity:matchingDashpayUserInContext atTimestamp:contactRequest.createdAt];
                            [potentialFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequest];
                            [matchingDashpayUserInContext addIncomingRequestsObject:friendRequest];
                            
                            if ([[friendRequest.sourceContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",matchingDashpayUserInContext]] count]) {
                                [matchingDashpayUserInContext addFriendsObject:friendRequest.sourceContact];
                            }
                            
                            [account addIncomingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier inContext:context];
                            [context ds_save];
                            [self.chain.chainManager.transactionManager updateTransactionsBloomFilter];
                        } else {
                            succeeded = FALSE;
                            [errors addObject:[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                                                                                                           DSLocalizedString(@"Could not create friendship derivation path", nil)}]];
                        }
                        dispatch_group_leave(dispatchGroup);
                    }];
                    
                } else {
                    DSBlockchainIdentity * sourceBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:externalBlockchainIdentityEntity];
                    NSAssert(sourceBlockchainIdentity, @"This should not be null");
                    if ([sourceBlockchainIdentity activeKeyCount] > 0 && [sourceBlockchainIdentity keyAtIndex:contactRequest.senderKeyIndex]) {
                        //the contact already existed, and has an encryption public key set, create the incoming friend request, add a friendship if an outgoing friend request also exists
                        DSKey * key = [sourceBlockchainIdentity keyAtIndex:contactRequest.senderKeyIndex];
                        NSData * decryptedExtendedPublicKeyData = [contactRequest decryptedPublicKeyDataWithKey:key];
                        NSAssert(decryptedExtendedPublicKeyData, @"Data should be decrypted");
                        DSECDSAKey * extendedPublicKey = [DSECDSAKey keyWithExtendedPublicKeyData:decryptedExtendedPublicKeyData];
                        if (!extendedPublicKey) {
                            succeeded = FALSE;
                            [errors addObject:[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"Contact request extended public key is incorrectly encrypted.", nil)}]];
                            return;
                        }
                        [self addIncomingRequestFromContact:externalBlockchainIdentityEntity.matchingDashpayUser
                                       forExtendedPublicKey:extendedPublicKey
                                                atTimestamp:contactRequest.createdAt];
                        
                        DSDashpayUserEntity * matchingDashpayUserInContext = [self matchingDashpayUserInContext:context];
                        if ([[externalBlockchainIdentityEntity.matchingDashpayUser.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",matchingDashpayUserInContext]] count]) {
                            [matchingDashpayUserInContext addFriendsObject:[externalBlockchainIdentityEntity matchingDashpayUser]];
                            [context ds_save];
                        }
                        
                    } else {
                        //the blockchain identity is already known, but needs to updated to get the right key, create the incoming friend request, add a friendship if an outgoing friend request also exists
                        dispatch_group_enter(dispatchGroup);
                        [sourceBlockchainIdentity fetchNeededNetworkStateInformationWithCompletion:^(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * _Nullable networkStateInformationErrors) {
                            if (!failureStep) {
                                DSKey * key = [sourceBlockchainIdentity keyAtIndex:contactRequest.senderKeyIndex];
                                NSData * decryptedExtendedPublicKeyData = [contactRequest decryptedPublicKeyDataWithKey:key];
                                NSAssert(decryptedExtendedPublicKeyData, @"Data should be decrypted");
                                DSECDSAKey * extendedPublicKey = [DSECDSAKey keyWithExtendedPublicKeyData:decryptedExtendedPublicKeyData];
                                NSAssert(extendedPublicKey, @"A key should be recovered");
                                [self addIncomingRequestFromContact:externalBlockchainIdentityEntity.matchingDashpayUser
                                               forExtendedPublicKey:extendedPublicKey
                                                        atTimestamp:contactRequest.createdAt];
                                DSDashpayUserEntity * matchingDashpayUserInContext = [self matchingDashpayUserInContext:context];
                                if ([[externalBlockchainIdentityEntity.matchingDashpayUser.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",matchingDashpayUserInContext]] count]) {
                                    [matchingDashpayUserInContext addFriendsObject:externalBlockchainIdentityEntity.matchingDashpayUser];
                                    [context ds_save];
                                }
                            } else {
                                succeeded = FALSE;
                                [errors addObjectsFromArray:networkStateInformationErrors];
                            }
                            dispatch_group_leave(dispatchGroup);
                        }];
                    }
                }
            }
        }
        
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
            if (completion) {
                completion(succeeded,[errors copy]);
            }
        });
    }];
}

-(void)addFriendship:(DSPotentialOneWayFriendship*)friendship inContext:(NSManagedObjectContext*)context completion:(void (^)(BOOL success, NSError * error))completion  {
    
    //DSFriendRequestEntity * friendRequestEntity = [friendship outgoingFriendRequestForDashpayUserEntity:friendship.destinationBlockchainIdentity.matchingDashpayUser];
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObjectInContext:context];
    friendRequestEntity.sourceContact = [friendship.sourceBlockchainIdentity matchingDashpayUserInContext:context];
    friendRequestEntity.destinationContact = [friendship.destinationBlockchainIdentity matchingDashpayUserInContext:context];
    friendRequestEntity.timestamp = friendship.createdAt;
    NSAssert(friendRequestEntity.sourceContact != friendRequestEntity.destinationContact, @"This must be different contacts");

    DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueIDString index:0 onChain:self.chain inContext:context];

    friendRequestEntity.account = accountEntity;

    [friendRequestEntity finalizeWithFriendshipIdentifier];
    
    [friendship createDerivationPathWithCompletion:^(BOOL success, DSIncomingFundsDerivationPath * _Nonnull incomingFundsDerivationPath) {
        if (!success) {
            return;
        }
        DSAccount * account = [self.wallet accountWithNumber:0];
        if (friendship.destinationBlockchainIdentity.isLocal) { //the destination is also local
            NSAssert(friendship.destinationBlockchainIdentity.wallet, @"Wallet should be known");
            DSAccount * recipientAccount = [friendship.destinationBlockchainIdentity.wallet accountWithNumber:0];
            NSAssert(recipientAccount, @"Recipient Wallet should exist");
            [recipientAccount addIncomingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier inContext:context];
            if (recipientAccount != account) {
                [account addOutgoingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier inContext:context];
            }
        } else {
            //todo update outgoing derivation paths to incoming derivation paths as blockchain users come in
            [account addIncomingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier inContext:context];
        }
        
        friendRequestEntity.derivationPath = [friendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequestEntity];
        
        NSAssert(friendRequestEntity.derivationPath, @"derivation path must be present");
        
        DSDashpayUserEntity * dashpayUserInChildContext = [self matchingDashpayUserInContext:context];
        
        [dashpayUserInChildContext addOutgoingRequestsObject:friendRequestEntity];
        
        if ([[[friendship.destinationBlockchainIdentity matchingDashpayUserInContext:context].outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact == %@",dashpayUserInChildContext]] count]) {
            [dashpayUserInChildContext addFriendsObject:[friendship.destinationBlockchainIdentity matchingDashpayUserInContext:context]];
        }
        NSError * savingError = nil;
        [context save:&savingError];
        [self.chain.chainManager.transactionManager updateTransactionsBloomFilter];
        if (completion) {
            completion(savingError?NO:YES,savingError);
        }
        
    }];
}

-(void)addFriendshipFromSourceBlockchainIdentity:(DSBlockchainIdentity*)sourceBlockchainIdentity sourceKeyIndex:(uint32_t)sourceKeyIndex toRecipientBlockchainIdentity:(DSBlockchainIdentity*)recipientBlockchainIdentity recipientKeyIndex:(uint32_t)recipientKeyIndex atTimestamp:(NSTimeInterval)timestamp inContext:(NSManagedObjectContext*)context {
    
    DSAccount * account = [self.wallet accountWithNumber:0];
    
    DSPotentialOneWayFriendship * realFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationBlockchainIdentity:recipientBlockchainIdentity destinationKeyIndex:recipientKeyIndex sourceBlockchainIdentity:self sourceKeyIndex:sourceKeyIndex account:account createdAt:timestamp];
    
    [self addFriendship:realFriendship inContext:context completion:nil];
    
    
}

- (void)handleOutgoingRequests:(NSArray <DSContactRequest *>  *)outgoingRequests
                       context:(NSManagedObjectContext *)context
                    completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    [context performBlockAndWait:^{
        __block NSMutableArray * errors = [NSMutableArray array];
        
        __block BOOL succeeded = YES;
        dispatch_group_t dispatchGroup = dispatch_group_create();
        
        for (DSContactRequest * contactRequest in outgoingRequests) {
            DSBlockchainIdentityEntity * recipientBlockchainIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@",uint256_data(contactRequest.recipientBlockchainIdentityUniqueId)];
            if (!recipientBlockchainIdentityEntity) {
                //no contact exists yet
                dispatch_group_enter(dispatchGroup);
                DSBlockchainIdentity * recipientBlockchainIdentity = [self.identitiesManager foreignBlockchainIdentityWithUniqueId:contactRequest.recipientBlockchainIdentityUniqueId createIfMissing:YES inContext:context];
                NSAssert([recipientBlockchainIdentity blockchainIdentityEntityInContext:context], @"Entity should now exist");
                [recipientBlockchainIdentity fetchNeededNetworkStateInformationWithCompletion:^(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * _Nullable networkErrors) {
                    if (!failureStep) {
                        dispatch_async(self.chain.networkingQueue, ^{
                            [self addFriendshipFromSourceBlockchainIdentity:self sourceKeyIndex:contactRequest.senderKeyIndex toRecipientBlockchainIdentity:recipientBlockchainIdentity recipientKeyIndex:contactRequest.recipientKeyIndex atTimestamp:contactRequest.createdAt inContext:context];
                        });
                    } else {
                        succeeded = FALSE;
                        [errors addObjectsFromArray:networkErrors];
                    }
                    dispatch_group_leave(dispatchGroup);
                }];
            } else {
                //the recipient blockchain identity is already known, meaning they had made a friend request to us before, and on another device we had accepted
                //or the recipient blockchain identity is also local to the device
                
                [context ds_save];
                DSWallet * recipientWallet = nil;
                DSBlockchainIdentity * recipientBlockchainIdentity = [self.chain blockchainIdentityForUniqueId:recipientBlockchainIdentityEntity.uniqueID.UInt256 foundInWallet:&recipientWallet];
                BOOL isLocal = TRUE;
                if (!recipientBlockchainIdentity) {
                    //this is not local
                    recipientBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:recipientBlockchainIdentityEntity];
                    isLocal = FALSE;
                }
                
                dispatch_group_enter(dispatchGroup);
                [recipientBlockchainIdentity fetchIfNeededNetworkStateInformation:DSBlockchainIdentityQueryStep_Profile & DSBlockchainIdentityQueryStep_Username & DSBlockchainIdentityQueryStep_Identity inContext:context withCompletion:^(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> * _Nullable networkErrors) {
                    if (!failureStep) {
                        [self addFriendshipFromSourceBlockchainIdentity:self sourceKeyIndex:contactRequest.senderKeyIndex toRecipientBlockchainIdentity:recipientBlockchainIdentity recipientKeyIndex:contactRequest.recipientKeyIndex atTimestamp:contactRequest.createdAt inContext:context];
                    } else {
                        succeeded = FALSE;
                        [errors addObjectsFromArray:networkErrors];
                    }
                    dispatch_group_leave(dispatchGroup);
                }];
            }
        }
        
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
            if (completion) {
                completion(succeeded,[errors copy]);
            }
        });
    }];
}

-(void)addIncomingRequestFromContact:(DSDashpayUserEntity*)dashpayUserEntity
                forExtendedPublicKey:(DSKey*)extendedPublicKey
                         atTimestamp:(NSTimeInterval)timestamp {
    NSManagedObjectContext * context = dashpayUserEntity.managedObjectContext;
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObjectInContext:context];
    friendRequestEntity.sourceContact = dashpayUserEntity;
    friendRequestEntity.destinationContact = [self matchingDashpayUserInContext:dashpayUserEntity.managedObjectContext];
    friendRequestEntity.timestamp = timestamp;
    NSAssert(friendRequestEntity.sourceContact != friendRequestEntity.destinationContact, @"This must be different contacts");
    
    DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity managedObjectInContext:context];
    derivationPathEntity.chain = [self.chain chainEntityInContext:context];
    
    friendRequestEntity.derivationPath = derivationPathEntity;
    
    NSAssert(friendRequestEntity.derivationPath, @"There must be a derivation path");
    
    DSAccount * account = [self.wallet accountWithNumber:0];
    
    DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueIDString index:account.accountNumber onChain:self.chain inContext:dashpayUserEntity.managedObjectContext];
    
    derivationPathEntity.account = accountEntity;
    
    friendRequestEntity.account = accountEntity;
    
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    
    DSIncomingFundsDerivationPath * derivationPath = [DSIncomingFundsDerivationPath externalDerivationPathWithExtendedPublicKey:extendedPublicKey withDestinationBlockchainIdentityUniqueId:[self matchingDashpayUserInContext:dashpayUserEntity.managedObjectContext].associatedBlockchainIdentity.uniqueID.UInt256 sourceBlockchainIdentityUniqueId:dashpayUserEntity.associatedBlockchainIdentity.uniqueID.UInt256 onChain:self.chain];
    
    derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
    
    [derivationPath storeExternalDerivationPathExtendedPublicKeyToKeyChain];
    
    //incoming request uses an outgoing derivation path
    [account addOutgoingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier inContext:dashpayUserEntity.managedObjectContext];
    
    DSDashpayUserEntity * matchingDashpayUser = [self matchingDashpayUserInContext:dashpayUserEntity.managedObjectContext];
    [matchingDashpayUser addIncomingRequestsObject:friendRequestEntity];
    
    if ([[friendRequestEntity.sourceContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",matchingDashpayUser]] count]) {
        [matchingDashpayUser addFriendsObject:friendRequestEntity.sourceContact];
    }
    
    [context ds_save];
    [self.chain.chainManager.transactionManager updateTransactionsBloomFilter];
}

// MARK: - Persistence

// MARK: Saving

-(void)saveInitial {
    [self saveInitialInContext:self.platformContext];
}

-(void)saveInitialInContext:(NSManagedObjectContext*)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * entity = [DSBlockchainIdentityEntity managedObjectInContext:context];
        entity.uniqueID = uint256_data(self.uniqueID);
        entity.isLocal = self.isLocal;
        if (self.isLocal) {
            NSData * transactionHash = uint256_data(self.registrationCreditFundingTransaction.txHash);
            DSCreditFundingTransactionEntity * transactionEntity = (DSCreditFundingTransactionEntity*)[DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", transactionHash];
            entity.registrationFundingTransaction = transactionEntity;
        }
        entity.chain = [self.chain chainEntityInContext:context];
        for (NSString * usernameFullPath in self.usernameStatuses) {
            DSBlockchainIdentityUsernameEntity * usernameEntity = [DSBlockchainIdentityUsernameEntity managedObjectInContext:context];
            usernameEntity.status = [self statusOfUsernameFullPath:usernameFullPath];
            usernameEntity.stringValue = [self usernameOfUsernameFullPath:usernameFullPath];
            usernameEntity.domain = [self domainOfUsernameFullPath:usernameFullPath];
            usernameEntity.blockchainIdentity = entity;
            [entity addUsernamesObject:usernameEntity];
            [entity setDashpayUsername:usernameEntity];
        }
        DSDashpayUserEntity * dashpayUserEntity = [DSDashpayUserEntity managedObjectInContext:context];
        dashpayUserEntity.chain = [self.chain chainEntityInContext:context];
        entity.matchingDashpayUser = dashpayUserEntity;
        
        [context ds_saveInBlockAndWait];
        [[NSManagedObjectContext viewContext] performBlockAndWait:^{
            self.matchingDashpayUserInViewContext = [[NSManagedObjectContext viewContext] objectWithID:dashpayUserEntity.objectID];
            self.matchingDashpayUserInPlatformContext = [[NSManagedObjectContext platformContext] objectWithID:dashpayUserEntity.objectID];
        }];
        if ([self isLocal]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self}];
            });
        }
    }];
}

-(void)saveInContext:(NSManagedObjectContext*)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        BOOL changeOccured = NO;
        NSMutableArray * updateEvents = [NSMutableArray array];
        DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
        if (entity.creditBalance != self.creditBalance) {
            entity.creditBalance = self.creditBalance;
            changeOccured = YES;
            [updateEvents addObject:DSBlockchainIdentityUpdateEventCreditBalance];
        }
        if (entity.registrationStatus != self.registrationStatus) {
            entity.registrationStatus = self.registrationStatus;
            changeOccured = YES;
            [updateEvents addObject:DSBlockchainIdentityUpdateEventRegistration];
        }

        if (!uint256_eq(entity.dashpaySyncronizationBlockHash.UInt256,self.dashpaySyncronizationBlockHash)) {
            entity.dashpaySyncronizationBlockHash = uint256_data(self.dashpaySyncronizationBlockHash);
            changeOccured = YES;
            [updateEvents addObject:DSBlockchainIdentityUpdateEventDashpaySyncronizationBlockHash];
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
            if (updateEvents.count) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:updateEvents}];
                });
            }
        }
    }];
}

-(NSString*)identifierForKeyAtPath:(NSIndexPath*)path fromDerivationPath:(DSDerivationPath*)derivationPath {
    NSIndexPath * softenedPath = [path softenAllItems];
    return [NSString stringWithFormat:@"%@-%@-%@",self.uniqueIdString,derivationPath.standaloneExtendedPublicKeyUniqueID,[softenedPath indexPathString]];
}

-(void)saveNewKey:(DSKey*)key atPath:(NSIndexPath*)path withStatus:(DSBlockchainIdentityKeyStatus)status fromDerivationPath:(DSDerivationPath*)derivationPath inContext:(NSManagedObjectContext*)context {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal) return;
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * blockchainIdentityEntity = [self blockchainIdentityEntityInContext:context];
        NSAssert(blockchainIdentityEntity, @"Entity should be present");
        DSDerivationPathEntity * derivationPathEntity = [derivationPath derivationPathEntityInContext:context];
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@",blockchainIdentityEntity,derivationPathEntity, path];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInContext:context];
            blockchainIdentityKeyPathEntity.derivationPath = derivationPathEntity;
            blockchainIdentityKeyPathEntity.keyType = key.keyType;
            blockchainIdentityKeyPathEntity.keyStatus = status;
            if (key.privateKeyData) {
                setKeychainData(key.privateKeyData, [self identifierForKeyAtPath:path fromDerivationPath:derivationPath], YES);
                DSDLog(@"Saving key at %@ for user %@",[self identifierForKeyAtPath:path fromDerivationPath:derivationPath],self.currentDashpayUsername);
            } else {
                DSKey * privateKey = [self derivePrivateKeyAtIndexPath:path ofType:key.keyType];
                NSAssert([privateKey.publicKeyData isEqualToData:key.publicKeyData], @"The keys don't seem to match up");
                NSData * privateKeyData = privateKey.privateKeyData;
                NSAssert(privateKeyData, @"Private key data should exist");
                setKeychainData(privateKeyData, [self identifierForKeyAtPath:path fromDerivationPath:derivationPath], YES);
                DSDLog(@"Saving key after rederivation %@ for user %@",[self identifierForKeyAtPath:path fromDerivationPath:derivationPath],self.currentDashpayUsername);
            }

            blockchainIdentityKeyPathEntity.path = path;
            blockchainIdentityKeyPathEntity.publicKeyData = key.publicKeyData;
            blockchainIdentityKeyPathEntity.keyID = (uint32_t)[path indexAtPosition:path.length - 1];
            [blockchainIdentityEntity addKeyPathsObject:blockchainIdentityKeyPathEntity];
            [context ds_save];
        } else {
            DSDLog(@"Already had saved this key %@",path);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:@[DSBlockchainIdentityUpdateEventKeyUpdate]}];
        });
    }];
}

-(void)saveNewRemoteIdentityKey:(DSKey*)key forKeyWithIndexID:(uint32_t)keyID withStatus:(DSBlockchainIdentityKeyStatus)status inContext:(NSManagedObjectContext*)context {
    NSAssert(!self.isLocal, @"This should only be called on non local blockchain identities");
    if (self.isLocal) return;
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * blockchainIdentityEntity = [self blockchainIdentityEntityInContext:context];
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:context matching:@"blockchainIdentity == %@ && keyID == %@",blockchainIdentityEntity,@(keyID)];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInContext:context];
            blockchainIdentityKeyPathEntity.keyType = key.keyType;
            blockchainIdentityKeyPathEntity.keyStatus = status;
            blockchainIdentityKeyPathEntity.keyID = keyID;
            blockchainIdentityKeyPathEntity.publicKeyData = key.publicKeyData;
            [blockchainIdentityEntity addKeyPathsObject:blockchainIdentityKeyPathEntity];
            [context ds_save];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:@[DSBlockchainIdentityUpdateEventKeyUpdate]}];
        });
    }];
}


-(void)updateStatus:(DSBlockchainIdentityKeyStatus)status forKeyAtPath:(NSIndexPath*)path fromDerivationPath:(DSDerivationPath*)derivationPath inContext:(NSManagedObjectContext*)context {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal) return;
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
        DSDerivationPathEntity * derivationPathEntity = [derivationPath derivationPathEntityInContext:context];
        DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@",entity, derivationPathEntity,path] firstObject];
        if (blockchainIdentityKeyPathEntity && (blockchainIdentityKeyPathEntity.keyStatus != status)) {
            blockchainIdentityKeyPathEntity.keyStatus = status;
            [context ds_save];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:@[DSBlockchainIdentityUpdateEventKeyUpdate]}];
        });
    }];
}

-(void)updateStatus:(DSBlockchainIdentityKeyStatus)status forKeyWithIndexID:(uint32_t)keyID inContext:(NSManagedObjectContext*)context {
    NSAssert(!self.isLocal, @"This should only be called on non local blockchain identities");
    if (self.isLocal) return;
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
        DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == NULL && keyID == %@",entity,@(keyID)] firstObject];
        if (blockchainIdentityKeyPathEntity) {
            DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInContext:context];
            blockchainIdentityKeyPathEntity.keyStatus = status;
            [context ds_save];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:@[DSBlockchainIdentityUpdateEventKeyUpdate]}];
        });
    }];
}

-(void)saveNewUsername:(NSString*)username inDomain:(NSString*)domain status:(DSBlockchainIdentityUsernameStatus)status inContext:(NSManagedObjectContext*)context {
    NSAssert(![username containsString:@"."], @"This is most likely an error");
    NSAssert(domain, @"Domain must not be nil");
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
        DSBlockchainIdentityUsernameEntity * usernameEntity = [DSBlockchainIdentityUsernameEntity managedObjectInContext:context];
        usernameEntity.status = status;
        usernameEntity.stringValue = username;
        usernameEntity.salt = [self saltForUsernameFullPath:[self fullPathForUsername:username inDomain:domain] saveSalt:NO inContext:context];
        usernameEntity.domain = domain;
        [entity addUsernamesObject:usernameEntity];
        [entity setDashpayUsername:usernameEntity];
        [context ds_save];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateUsernameStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain, DSBlockchainIdentityKey:self}];
        });
    }];
    
}

-(void)saveUsernameFullPaths:(NSArray*)usernameFullPaths toStatus:(DSBlockchainIdentityUsernameStatus)status inContext:(NSManagedObjectContext*)context {
    [self saveUsernamesInDictionary:[self.usernameStatuses dictionaryWithValuesForKeys:usernameFullPaths] toStatus:status inContext:context];
}

-(void)saveUsernamesInDictionary:(NSDictionary<NSString*,NSDictionary*>*)fullPathUsernamesDictionary toStatus:(DSBlockchainIdentityUsernameStatus)status inContext:(NSManagedObjectContext*)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        for (NSString * fullPathUsername in fullPathUsernamesDictionary) {
            NSString * username = [fullPathUsernamesDictionary[fullPathUsername] objectForKey:BLOCKCHAIN_USERNAME_PROPER];
            NSString * domain = [fullPathUsernamesDictionary[fullPathUsername] objectForKey:BLOCKCHAIN_USERNAME_DOMAIN];
            [self saveUsername:username inDomain:domain status:status salt:nil commitSave:NO inContext:context];
        }
        [context ds_save];
    }];
}

//-(void)saveUsernamesToStatuses:(NSDictionary<NSString*,NSNumber*>*)dictionary {
//    if (self.isTransient) return;
//    [self.managedObjectContext performBlockAndWait:^{
//        for (NSString * username in statusDictionary) {
//            DSBlockchainIdentityUsernameStatus status = [statusDictionary[username] intValue];
//            NSString * domain = domainDictionary[username];
//            [self saveUsername:username inDomain:domain status:status salt:nil commitSave:NO];
//        }
//        [self.managedObjectContext ds_save];
//    }];
//}

-(void)saveUsernameFullPath:(NSString*)usernameFullPath status:(DSBlockchainIdentityUsernameStatus)status salt:(NSData*)salt commitSave:(BOOL)commitSave inContext:(NSManagedObjectContext*)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
        NSSet * usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity * _Nonnull obj, BOOL * _Nonnull stop) {
            if ([[self fullPathForUsername:obj.stringValue inDomain:obj.domain] isEqualToString:usernameFullPath]) {
                *stop = TRUE;
                return TRUE;
                
            } else {
                return FALSE;
            }
        }];
        if ([usernamesPassingTest count]) {
            NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
            DSBlockchainIdentityUsernameEntity * usernameEntity = [usernamesPassingTest anyObject];
            usernameEntity.status = status;
            if (salt) {
                usernameEntity.salt = salt;
            }
            if (commitSave) {
                [context ds_save];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateUsernameStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain, DSBlockchainIdentityKey:self, DSBlockchainIdentityUsernameKey:usernameEntity.stringValue, DSBlockchainIdentityUsernameDomainKey:usernameEntity.stringValue}];
            });
        }
    }];
}

-(void)saveUsername:(NSString*)username inDomain:(NSString*)domain status:(DSBlockchainIdentityUsernameStatus)status salt:(NSData*)salt commitSave:(BOOL)commitSave inContext:(NSManagedObjectContext*)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * entity = [self blockchainIdentityEntityInContext:context];
        NSSet * usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity * _Nonnull obj, BOOL * _Nonnull stop) {
            if ([obj.stringValue isEqualToString:username]) {
                *stop = TRUE;
                return TRUE;
                
            } else {
                return FALSE;
            }
        }];
        if ([usernamesPassingTest count]) {
            NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
            DSBlockchainIdentityUsernameEntity * usernameEntity = [usernamesPassingTest anyObject];
            usernameEntity.status = status;
            if (salt) {
                usernameEntity.salt = salt;
            }
            if (commitSave) {
                [context ds_save];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateUsernameStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain, DSBlockchainIdentityKey:self, DSBlockchainIdentityUsernameKey:username, DSBlockchainIdentityUsernameDomainKey: domain}];
            });
        }
    }];
}

// MARK: Deletion

-(void)deletePersistentObjectAndSave:(BOOL)save inContext:(NSManagedObjectContext*)context {
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity * blockchainIdentityEntity = [self blockchainIdentityEntityInContext:context];
        if (blockchainIdentityEntity) {
            NSSet <DSFriendRequestEntity *>* friendRequests = [blockchainIdentityEntity.matchingDashpayUser outgoingRequests];
            for (DSFriendRequestEntity * friendRequest in friendRequests) {
                uint32_t accountNumber = friendRequest.account.index;
                DSAccount * account = [self.wallet accountWithNumber:accountNumber];
                [account removeIncomingDerivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
            }
            [blockchainIdentityEntity deleteObjectAndWait];
            if (save) {
                [context ds_save];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self}];
        });
    }];
}

// MARK: Entity

-(DSBlockchainIdentityEntity*)blockchainIdentityEntity {
    return [self blockchainIdentityEntityInContext:[NSManagedObjectContext viewContext]];
}

-(DSBlockchainIdentityEntity*)blockchainIdentityEntityInContext:(NSManagedObjectContext*)context {
    __block DSBlockchainIdentityEntity* entity = nil;
    [context performBlockAndWait:^{
        entity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@",self.uniqueIDData];
    }];
    NSAssert(entity, @"An entity should always be found");
    return entity;
}


//-(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransition {
//    if (!_blockchainIdentityRegistrationTransition) {
//        _blockchainIdentityRegistrationTransition = (DSBlockchainIdentityRegistrationTransition*)[self.wallet.specialTransactionsHolder transactionForHash:self.registrationTransitionHash];
//    }
//    return _blockchainIdentityRegistrationTransition;
//}

//-(UInt256)lastTransitionHash {
//    //this is not effective, do this locally in the future
//    return [[self allTransitions] lastObject].transitionHash;
//}


-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@-%@}",self.currentDashpayUsername,self.uniqueIdString]];
}

@end
