//
//  DSBlockchainIdentity.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "DSBlockchainIdentity+Protected.h"
#import "DSChain.h"
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
#import "DSTransactionManager.h"

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

@property(nonatomic,readonly) DSDAPIClient* DAPIClient;
@property(nonatomic,readonly) DSDAPINetworkService* DAPINetworkService;

@property(nonatomic,strong) DPDocumentFactory* dashpayDocumentFactory;
@property(nonatomic,strong) DPDocumentFactory* dpnsDocumentFactory;

@property(nonatomic,strong) DSDashpayUserEntity * matchingDashpayUser;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@property (nonatomic, strong) DSChain * chain;

@end

@implementation DSBlockchainIdentity

// MARK: - Initialization

-(instancetype)initWithUniqueId:(UInt256)uniqueId onChain:(DSChain*)chain inContext:(NSManagedObjectContext*)managedObjectContext {
    //this is the initialization of a non local blockchain identity
    if (!(self = [super init])) return nil;
    NSAssert(!uint256_is_zero(uniqueId), @"uniqueId must not be null");
    _uniqueID = uniqueId;
    _isLocal = FALSE;
    _keysCreated = 0;
    _currentMainKeyIndex = 0;
    _currentMainKeyType = DSKeyType_ECDSA;
    self.usernameStatuses = [NSMutableDictionary dictionary];
    self.keyInfoDictionaries = [NSMutableDictionary dictionary];
    _registrationStatus = DSBlockchainIdentityRegistrationStatus_Registered;
    _type = DSBlockchainIdentityType_Unknown; //we don't yet know the type
    if (managedObjectContext) {
        self.managedObjectContext = managedObjectContext;
    } else {
        self.managedObjectContext = [NSManagedObject context];
    }
    self.chain = chain;
    return self;
}

-(instancetype)initWithBlockchainIdentityEntity:(DSBlockchainIdentityEntity*)blockchainIdentityEntity inContext:(NSManagedObjectContext*)managedObjectContext {
    if (!(self = [self initWithUniqueId:blockchainIdentityEntity.uniqueID.UInt256 onChain:blockchainIdentityEntity.chain.chain inContext:blockchainIdentityEntity.managedObjectContext])) return nil;
    
    for (DSBlockchainIdentityUsernameEntity * usernameEntity in blockchainIdentityEntity.usernames) {
        NSData * salt = usernameEntity.salt;
        if (salt) {
            [self.usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(usernameEntity.status),BLOCKCHAIN_USERNAME_SALT:usernameEntity.salt} forKey:usernameEntity.stringValue];
        } else {
            [self.usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(usernameEntity.status)} forKey:usernameEntity.stringValue];
        }
    }
    _creditBalance = blockchainIdentityEntity.creditBalance;
    _registrationStatus = blockchainIdentityEntity.registrationStatus;
    _type = blockchainIdentityEntity.type;
    for (DSBlockchainIdentityKeyPathEntity * keyPath in blockchainIdentityEntity.keyPaths) {
        if ([keyPath path]) {
            NSIndexPath *keyIndexPath = (NSIndexPath *)[NSKeyedUnarchiver unarchiveObjectWithData:(NSData*)[keyPath path]];
            BOOL success = [self registerKeyWithStatus:keyPath.keyStatus atIndexPath:keyIndexPath ofType:keyPath.keyType];
            if (!success) {
                DSKey * key = [DSKey keyForPublicKeyData:keyPath.publicKeyData forKeyType:keyPath.keyType onChain:self.chain];
                [self registerKey:key withStatus:keyPath.keyStatus atIndex:keyPath.keyID ofType:keyPath.keyType];
            }
        } else {
            DSKey * key = [DSKey keyForPublicKeyData:keyPath.publicKeyData forKeyType:keyPath.keyType onChain:self.chain];
            [self registerKey:key withStatus:keyPath.keyStatus atIndex:keyPath.keyID ofType:keyPath.keyType];
        }
    }
    return self;
}

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);
    
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isLocal = YES;
    self.keysCreated = 0;
    self.currentMainKeyIndex = 0;
    self.currentMainKeyType = DSKeyType_ECDSA;
    self.index = index;
    self.usernameStatuses = [NSMutableDictionary dictionary];
    self.keyInfoDictionaries = [NSMutableDictionary dictionary];
    self.registrationStatus = DSBlockchainIdentityRegistrationStatus_Unknown;
    self.usernameSalts = [NSMutableDictionary dictionary];
    self.type = type;
    if (managedObjectContext) {
        self.managedObjectContext = managedObjectContext;
    } else {
        self.managedObjectContext = [NSManagedObject context];
    }
    self.chain = wallet.chain;
    return self;
}

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext {
    if (!(self = [self initWithType:type atIndex:index inWallet:wallet inContext:managedObjectContext])) return nil;
    NSAssert(!dsutxo_is_zero(lockedOutpoint), @"utxo must not be nil");
    self.lockedOutpoint = lockedOutpoint;
    self.uniqueID = [dsutxo_data(lockedOutpoint) SHA256_2];
    return self;
}

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index withFundingTransaction:(DSCreditFundingTransaction*)transaction inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    NSParameterAssert(wallet);
    if (![transaction isCreditFundingTransaction]) return nil;
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [self initWithType:type atIndex:index withLockedOutpoint:transaction.lockedOutpoint inWallet:wallet inContext:managedObjectContext])) return nil;
    
    self.registrationCreditFundingTransaction = transaction;
    
    //[self loadTransitions];
    
    [self.managedObjectContext performBlockAndWait:^{
        self.matchingDashpayUser = [DSDashpayUserEntity anyObjectMatching:@"associatedBlockchainIdentity.uniqueID == %@",uint256_data(self.uniqueID)];
    }];
    
    //    [self updateCreditBalance];
    
    
    return self;
}

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index  withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> *)usernameDictionary inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [self initWithType:type atIndex:index withFundingTransaction:transaction inWallet:wallet inContext:managedObjectContext])) return nil;
    
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

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index  withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> * _Nullable)usernameDictionary havingCredits:(uint64_t)credits registrationStatus:(DSBlockchainIdentityRegistrationStatus)registrationStatus inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext {
    if (!(self = [self initWithType:type atIndex:index withFundingTransaction:transaction withUsernameDictionary:usernameDictionary inWallet:wallet inContext:managedObjectContext])) return nil;
    
    self.creditBalance = credits;
    self.registrationStatus = registrationStatus;
    
    return self;
}

// MARK: - Full Registration agglomerate

-(void)registerOnNetwork:(DSBlockchainIdentityRegistrationStep)steps withFundingAccount:(DSAccount*)fundingAccount forTopupAmount:(uint64_t)topupDuffAmount stepCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * error))completion {
    __block DSBlockchainIdentityRegistrationStep stepsCompleted = DSBlockchainIdentityRegistrationStep_None;
    if (!(steps & DSBlockchainIdentityRegistrationStep_PublicKeyGeneration)) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(stepsCompleted, nil);
            });
        }
        return;
    }
        [self generateBlockchainIdentityExtendedPublicKeys:^(BOOL exists) {
            if (!exists) {
                 if (completion) {
                     dispatch_async(dispatch_get_main_queue(), ^{
                         completion(stepsCompleted, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey: DSLocalizedString(@"Could not derive public keys from wallet", nil)}]);
                    });
                 }
                return;
            }
                if (stepCompletion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        stepCompletion(DSBlockchainIdentityRegistrationStep_PublicKeyGeneration);
                    });
                }
                stepsCompleted |= DSBlockchainIdentityRegistrationStep_PublicKeyGeneration;
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
                                    completion(stepsCompleted, cancelled?nil:[NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey: DSLocalizedString(@"Transaction could not be signed", nil)}]);
                                });
                            }
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
                                
                                dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
                                
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
                                        stepCompletion(DSBlockchainIdentityRegistrationStep_Identity);
                                    }
                                    stepsCompleted |= DSBlockchainIdentityRegistrationStep_Identity;
                                    
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
                                            stepCompletion(DSBlockchainIdentityRegistrationStep_Username);
                                        }
                                        stepsCompleted |= DSBlockchainIdentityRegistrationStep_Username;
                                        
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
                                        
                                    }];
                                }];
                                });
                            }];
                        }];
                }];
        }];
}

// MARK: - Local Registration and Generation

-(void)generateBlockchainIdentityExtendedPublicKeys:(void (^ _Nullable)(BOOL registered))completion {
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
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"Generate Blockchain Identity" forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        [derivationPathBLS generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
        [derivationPathECDSA generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
        [derivationPathRegistrationFunding generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
        [derivationPathTopupFunding generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
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
    [self registerInWallet];
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
    [self deletePersistentObjectAndSave:YES];
    return TRUE;
}

// MARK: - Setters

-(void)setType:(DSBlockchainIdentityType)type {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (self.type == DSBlockchainIdentityType_Unknown || !self.registered) {
        _type = type;
    } else {
        DSDLog(@"Unable to switch types once set");
    }
}

// MARK: - Read Only Property Helpers

-(DSDashpayUserEntity*)matchingDashpayUserInContext:(NSManagedObjectContext*)context {
    return [context objectWithID:self.matchingDashpayUser.objectID];
}

-(NSData*)uniqueIDData {
    return uint256_data(self.uniqueID);
}

-(NSData*)lockedOutpointData {
    return dsutxo_data(self.lockedOutpoint);
}

-(NSString*)currentUsername {
    return [self.usernames firstObject];
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
////        NSArray<DSTransitionEntity *>* specialTransactionEntities = [DSTransitionEntity objectsMatching:@"(blockchainIdentity.uniqueId == %@)",self.uniqueIDData];
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
//                DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
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
//                DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
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
//                DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
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
//                DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
//                [entity addTransitionsObject:transition.transitionEntity];
//                [DSBlockchainIdentityEntity saveContext];
//            }];
//        }
//    }
//}

-(NSString*)uniqueIdString {
    return [uint256_data(self.uniqueID) base58String];
}

- (NSString*)localizedBlockchainIdentityTypeString {
    return [self.class localizedBlockchainIdentityTypeStringForType:self.type];
}

+ (NSString*)localizedBlockchainIdentityTypeStringForType:(DSBlockchainIdentityType)type {
    switch (type) {
        case DSBlockchainIdentityType_Application:
            return DSLocalizedString(@"Application", @"As a type of Blockchain Identity");
        case DSBlockchainIdentityType_User:
            return DSLocalizedString(@"User", @"As a type of Blockchain Identity");
        case DSBlockchainIdentityType_Unknown:
            return DSLocalizedString(@"Unknown", @"Unknown type of Blockchain Identity");
            
        default:
            break;
    }
}

// MARK: - Keys

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

-(uint32_t)indexOfKey:(DSKey*)key {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return 0;
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:DSKeyType_ECDSA];
    NSUInteger index = [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:key.hash160] addressFromHash160DataForChain:self.chain]];
    if (index == NSNotFound) {
        derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
        index = [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:key.hash160] addressFromHash160DataForChain:self.chain]];
    }
    return (uint32_t)index;
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

-(DSKey*)privateKeyAtIndex:(uint32_t)index ofType:(DSKeyType)type {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index,index};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    NSError * error = nil;
    NSData * keySecret = getKeychainData([self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath], &error);
    
    if (!keySecret || error) return nil;
    
    return [DSKey keyForSecretKeyData:keySecret forKeyType:(DSKeyType)type onChain:self.chain];
}

-(DSKey*)privateKeyAtIndex:(uint32_t)index ofType:(DSKeyType)type forSeed:(NSData*)seed {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index,index};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    return [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
}

-(DSKey*)publicKeyAtIndex:(uint32_t)index ofType:(DSKeyType)type {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index,index};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    return [derivationPath publicKeyAtIndexPath:indexPath onChain:self.chain];
}

-(DSKey*)createNewKeyOfType:(DSKeyType)type returnIndex:(uint32_t *)rIndex {
    if (!_isLocal) return nil;
    uint32_t keyIndex = self.keysCreated;
    const NSUInteger indexes[] = {_index,keyIndex};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    DSKey * key = [derivationPath publicKeyAtIndexPath:indexPath onChain:self.chain];
    self.keysCreated++;
    if (rIndex) {
        *rIndex = keyIndex;
    }
    NSDictionary * keyDictionary = @{@(DSBlockchainIdentityKeyDictionary_Key):key, @(DSBlockchainIdentityKeyDictionary_KeyType):@(type), @(DSBlockchainIdentityKeyDictionary_KeyStatus):@(DSBlockchainIdentityKeyStatus_Registering)};
    [self.keyInfoDictionaries setObject:keyDictionary forKey:@(keyIndex)];
    [self saveNewKey:key atPath:indexPath withStatus:DSBlockchainIdentityKeyStatus_Registering fromDerivationPath:derivationPath];
    return key;
}

-(uint32_t)firstIndexOfKeyOfType:(DSKeyType)type createIfNotPresent:(BOOL)createIfNotPresent {
    for (NSNumber * indexNumber in self.keyInfoDictionaries) {
        NSDictionary * keyDictionary = self.keyInfoDictionaries[indexNumber];
        DSKeyType keyTypeAtIndex = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyType)] unsignedIntValue];
        if (keyTypeAtIndex == type) {
            return [indexNumber unsignedIntValue];
        }
    }
    if (_isLocal && createIfNotPresent) {
        uint32_t rIndex;
        [self createNewKeyOfType:type returnIndex:&rIndex];
        return rIndex;
    } else {
        return UINT32_MAX;
    }
}

-(DSKey*)keyOfType:(DSKeyType)type atIndex:(uint32_t)index {
    if (!_isLocal) return nil;
    const NSUInteger indexes[] = {_index,index};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    DSKey * key = [derivationPath publicKeyAtIndexPath:indexPath onChain:self.chain];
    return key;
}

-(void)addKey:(DSKey*)key atIndex:(uint32_t)index ofType:(DSKeyType)type withStatus:(DSBlockchainIdentityKeyStatus)status save:(BOOL)save {
    if (self.isLocal) {
        const NSUInteger indexes[] = {_index,index};
        NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
        [self addKey:key atIndexPath:indexPath ofType:type withStatus:status save:save];
    } else {
        if (self.keyInfoDictionaries[@(index)]) {
            NSDictionary * keyDictionary = self.keyInfoDictionaries[@(index)];
            DSKey * keyToCheckInDictionary = keyDictionary[@(DSBlockchainIdentityKeyDictionary_Key)];
            DSBlockchainIdentityKeyStatus keyToCheckInDictionaryStatus = [keyDictionary[@(DSBlockchainIdentityKeyDictionary_KeyStatus)] unsignedIntegerValue];
            if ([keyToCheckInDictionary.publicKeyData isEqualToData:key.publicKeyData]) {
                if (save && status != keyToCheckInDictionaryStatus) {
                    [self updateStatus:status forKeyWithIndexID:index];
                }
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSDLog(@"these should really match up");
                return;
            }
        } else {
            self.keysCreated = MAX(self.keysCreated,index + 1);
            if (save) {
                [self saveNewKey:key forKeyWithIndexID:index withStatus:status];
            }
        }
        NSDictionary * keyDictionary = @{@(DSBlockchainIdentityKeyDictionary_Key):key, @(DSBlockchainIdentityKeyDictionary_KeyType):@(type), @(DSBlockchainIdentityKeyDictionary_KeyStatus):@(status)};
        [self.keyInfoDictionaries setObject:keyDictionary forKey:@(index)];
    }
}

-(void)addKey:(DSKey*)key atIndexPath:(NSIndexPath*)indexPath ofType:(DSKeyType)type withStatus:(DSBlockchainIdentityKeyStatus)status save:(BOOL)save {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal) return;
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    //derivationPath will be nil if not local
    
    DSKey * keyToCheck = [derivationPath publicKeyAtIndexPath:indexPath onChain:self.chain];
    if ([keyToCheck.publicKeyData isEqualToData:key.publicKeyData]) { //if it isn't local we shouldn't verify
        uint32_t index = (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1];
        if (self.keyInfoDictionaries[@(index)]) {
            NSDictionary * keyDictionary = self.keyInfoDictionaries[@(index)];
            DSKey * keyToCheckInDictionary = keyDictionary[@(DSBlockchainIdentityKeyDictionary_Key)];
            if ([keyToCheckInDictionary.publicKeyData isEqualToData:key.publicKeyData]) {
                if (save) {
                    [self updateStatus:status forKeyAtPath:indexPath fromDerivationPath:derivationPath];
                }
            } else {
                NSAssert(FALSE, @"these should really match up");
                DSDLog(@"these should really match up");
                return;
            }
        } else {
            self.keysCreated = MAX(self.keysCreated,index + 1);
            if (save) {
                [self saveNewKey:key atPath:indexPath withStatus:status fromDerivationPath:derivationPath];
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
    
    DSKey * key = [derivationPath publicKeyAtIndexPath:indexPath onChain:self.chain];
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
            rKey = [DSBLSKey blsKeyWithPublicKey:data.UInt384 onChain:self.chain];
        } else if ([type intValue] == DSKeyType_ECDSA) {
            rKey = [DSECDSAKey keyWithPublicKey:data];
        }
        *rIndex = [keyId unsignedIntValue] - 1;
        *rType = [type unsignedIntValue];
        return rKey;
    }
    return nil;
}

-(void)addKeyFromKeyDictionary:(NSDictionary*)dictionary {
    uint32_t index = 0;
    uint32_t type = 0;
    DSKey * key = [self keyFromKeyDictionary:dictionary rType:&type rIndex:&index];
    NSLog(@"%@",key.publicKeyData.base64String);
    if (key) {
        [self addKey:key atIndex:index ofType:type withStatus:DSBlockchainIdentityKeyStatus_Registered save:YES];
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
            return DSLocalizedString(@"Registered", @"The Blockchain Identity is registered");
            break;
        case DSBlockchainIdentityRegistrationStatus_Unknown:
            return DSLocalizedString(@"Unknown", @"It is Unknown if the Blockchain Identity is registered");
            break;
        case DSBlockchainIdentityRegistrationStatus_Registering:
            return DSLocalizedString(@"Registering", @"The Blockchain Identity is being registered");
            break;
        case DSBlockchainIdentityRegistrationStatus_NotRegistered:
            return DSLocalizedString(@"Not Registered", @"The Blockchain Identity is not registered");
            break;
            
        default:
            break;
    }
    return @"";
}

-(void)applyIdentityDictionary:(NSDictionary*)identityDictionary {
    if (identityDictionary[@"credits"]) {
        uint64_t creditBalance = (uint64_t)[identityDictionary[@"credits"] longLongValue];
        _creditBalance = creditBalance;
    }
    if (!self.type) {
        _type = identityDictionary[@"type"]?[((NSNumber*)identityDictionary[@"type"]) intValue]:DSBlockchainIdentityType_Unknown;
    }
    if (identityDictionary[@"publicKeys"]) {
        for (NSDictionary * dictionary in identityDictionary[@"publicKeys"]) {
            [self addKeyFromKeyDictionary:dictionary];
        }
    }
}

// MARK: Transition

-(void)registrationTransitionSignedByPrivateKey:(DSKey*)privateKey atIndex:(uint32_t)index registeringPublicKeys:(NSDictionary <NSNumber*,DSKey*>*)publicKeys completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction))completion {
    NSAssert(self.type != 0, @"Identity type should be defined");
    DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition = [[DSBlockchainIdentityRegistrationTransition alloc] initWithVersion:1 forIdentityType:self.type registeringPublicKeys:publicKeys usingLockedOutpoint:self.lockedOutpoint onChain:self.chain];
    [blockchainIdentityRegistrationTransition signWithKey:privateKey atIndex:index fromIdentity:self];
    if (completion) {
        completion(blockchainIdentityRegistrationTransition);
    }
}

-(void)registrationTransitionWithCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction))completion {
    
    NSString * question = DSLocalizedString(@"Do you wish to create this identity?", nil);
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        
        DSCreditFundingDerivationPath * derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:self.wallet];
        
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPathRegistrationFunding privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];
        
        uint32_t index;
        
        DSKey * publicKey = [self createNewKeyOfType:DSKeyType_ECDSA returnIndex:&index];
        
        NSAssert(index == 0, @"The index should be 0 here");
        
        [self registrationTransitionSignedByPrivateKey:privateKey atIndex:index registeringPublicKeys:@{@(index):publicKey} completion:completion];
    }];
}

// MARK: Registering

-(void)createAndPublishRegistrationTransitionWithCompletion:(void (^)(NSDictionary *, NSError *))completion {
    if (self.type == DSBlockchainIdentityType_Unknown) {
        NSError * error = [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                       DSLocalizedString(@"An identity needs to have its type defined before it can be registered.", nil)}];
        completion(nil,error);
        return;
    }
    [self registrationTransitionWithCompletion:^(DSBlockchainIdentityRegistrationTransition * _Nonnull blockchainIdentityRegistrationTransition) {
        if (blockchainIdentityRegistrationTransition) {
            [self.DAPIClient publishTransition:blockchainIdentityRegistrationTransition success:^(NSDictionary * _Nonnull successDictionary) {
                [self monitorForBlockchainIdentityWithRetryCount:5 completion:^(BOOL success, NSError * error) {
                    if (completion) {
                        completion(successDictionary,error);
                    }
                }];
            } failure:^(NSError * _Nonnull error) {
                if (error) {
                    [self monitorForBlockchainIdentityWithRetryCount:1 completion:^(BOOL success, NSError * error) {
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
                completion(nil,error);
            }
        }
    }];
    
}

// MARK: Retrieval

-(void)fetchIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success, NSError * error))completion {
    [self monitorForBlockchainIdentityWithRetryCount:1 completion:completion];
}

-(void)fetchAllNetworkStateInformationWithCompletion:(void (^)(BOOL success, NSError * error))completion {
    [self fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
        if (!success) {
            completion(success, error);
            return;
        }
        [self fetchUsernamesWithCompletion:^(BOOL success, NSError * error) {
            if (!success) {
                completion(success, error);
                return;
            }
            [self fetchProfileWithCompletion:^(BOOL success, NSError * error) {
                completion(success, error);
            }];
        }];
    }];
}

-(void)fetchNeededNetworkStateInformationWithCompletion:(void (^)(BOOL success, NSError * error))completion {
    if (!self.activeKeyCount) {
        [self fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
            if (!success) {
                completion(success,error);
                return;
            }
            if (![self.usernames count]) {
                [self fetchUsernamesWithCompletion:^(BOOL success, NSError * error) {
                    if (!success) {
                        completion(success,error);
                        return;
                    }
                    if (![self.matchingDashpayUser avatarPath]) {
                        [self fetchProfileWithCompletion:^(BOOL success, NSError * error) {
                            completion(success,error);
                        }];
                    }
                }];
            } else if (![self.matchingDashpayUser avatarPath]) {
                [self fetchProfileWithCompletion:^(BOOL success, NSError * error) {
                    completion(success,error);
                }];
            }
        }];
    } else if (![self.usernames count]) {
        [self fetchUsernamesWithCompletion:^(BOOL success, NSError * error) {
            if (!success) {
                completion(success,error);
                return;
            }
            if (![self.matchingDashpayUser avatarPath]) {
                [self fetchProfileWithCompletion:^(BOOL success, NSError * error) {
                    completion(success,error);
                }];
            }
        }];
    } else if (![self.matchingDashpayUser avatarPath]) {
        [self fetchProfileWithCompletion:^(BOOL success, NSError * error) {
            completion(success,error);
        }];
    }
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

-(void)signStateTransition:(DSTransition*)transition forKeyIndex:(uint32_t)keyIndex ofType:(DSKeyType)signingAlgorithm withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion {
    NSParameterAssert(transition);
    
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt forWallet:self.wallet forAmount:0 forceAuthentication:YES completion:^(NSData* _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        
        DSKey * privateKey = [self privateKeyAtIndex:keyIndex ofType:signingAlgorithm forSeed:seed];
        
        //        NSLog(@"%@",uint160_hex(self.blockchainIdentityRegistrationTransition.pubkeyHash));
        //        NSAssert(uint160_eq(privateKey.publicKeyData.hash160,self.blockchainIdentityRegistrationTransition.pubkeyHash),@"Keys aren't ok");
        [transition signWithKey:privateKey atIndex:keyIndex fromIdentity:self];
        completion(YES);
    }];
}

-(void)signStateTransition:(DSTransition*)transition withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion {
    if (!self.keysCreated) {
        uint32_t index;
        [self createNewKeyOfType:DEFAULT_SIGNING_ALGORITH returnIndex:&index];
    }
    return [self signStateTransition:transition forKeyIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType withPrompt:prompt completion:completion];
    
}

-(BOOL)verifySignature:(NSData*)signature forKeyIndex:(uint32_t)keyIndex ofType:(DSKeyType)signingAlgorithm forMessageDigest:(UInt256)messageDigest {
    DSKey * publicKey = [self publicKeyAtIndex:keyIndex ofType:signingAlgorithm];
    return [publicKey verify:messageDigest signatureData:signature];
}

-(void)encryptData:(NSData*)data withKeyAtIndex:(uint32_t)index forRecipientKey:(DSKey*)recipientPublicKey withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(NSData* encryptedData))completion {
    NSParameterAssert(data);
    NSParameterAssert(recipientPublicKey);
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"" forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData* _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        
        DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:(DSKeyType)recipientPublicKey.keyType];
        DSKey * privateKey = [derivationPath privateKeyAtIndex:self.index fromSeed:seed];
        NSData * encryptedData = [data encryptWithSecretKey:privateKey forPeerWithPublicKey:recipientPublicKey];
        completion(encryptedData);
    }];
}

-(void)decryptData:(NSData*)encryptedData fromRecipientKey:(UInt384)recipientPublicKey withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(NSData* decryptedData))completion {
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"" forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData* _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
        DSBLSKey * privateKey = (DSBLSKey *)[derivationPath privateKeyAtIndex:self.index fromSeed:seed];
        DSBLSKey * publicRecipientKey = [DSBLSKey blsKeyWithPublicKey:recipientPublicKey onChain:self.chain];
        NSData * data = [encryptedData decryptWithSecretKey:privateKey fromPeerWithPublicKey:publicRecipientKey];
        completion(data);
    }];
}

// MARK: - Contracts

-(void)fetchAndUpdateContract:(DPContract*)contract {
    __weak typeof(contract) weakContract = contract;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        
        if (!uint256_is_zero(self.chain.dpnsContractID) && contract.contractState == DPContractState_Unknown) {
            [self.DAPINetworkService getIdentityByName:@"dashpay" inDomain:@"" success:^(NSDictionary * _Nonnull blockchainIdentity) {
                if (!blockchainIdentity) {
                    __strong typeof(weakContract) strongContract = weakContract;
                    if (!strongContract) {
                        return;
                    }
                    strongContract.contractState = DPContractState_NotRegistered;
                }
                NSLog(@"okay");
            } failure:^(NSError * _Nonnull error) {
                __strong typeof(weakContract) strongContract = weakContract;
                if (!strongContract) {
                    return;
                }
                strongContract.contractState = DPContractState_NotRegistered;
            }];
        } else if ((uint256_is_zero(self.chain.dpnsContractID) && uint256_is_zero(contract.registeredBlockchainIdentity)) || contract.contractState == DPContractState_NotRegistered) {
            [contract registerCreator:self];
            __block DSContractTransition * transition = [contract contractRegistrationTransitionForIdentity:self];
            [self signStateTransition:transition withPrompt:@"Register Contract?" completion:^(BOOL success) {
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
                        strongContract.contractState = DPContractState_Registering;
                        [strongSelf monitorForContract:strongContract withRetryCount:2 completion:^(BOOL success, NSError * error) {
                            
                        }];
                    } failure:^(NSError * _Nonnull error) {
                        //maybe it was already registered
                        __strong typeof(weakContract) strongContract = weakContract;
                        if (!strongContract) {
                            return;
                        }
                        strongContract.contractState = DPContractState_Unknown;
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                            return;
                        }
                        [strongSelf monitorForContract:strongContract withRetryCount:2 completion:^(BOOL success, NSError * error) {
                            
                        }];
                    }];
                }
            }];
            
        } else if (contract.contractState == DPContractState_Registered || contract.contractState == DPContractState_Registering) {
            DSDLog(@"Fetching contract for verification %@",contract.base58ContractID);
            [self.DAPINetworkService fetchContractForId:contract.base58ContractID success:^(NSDictionary * _Nonnull contractDictionary) {
                __strong typeof(weakContract) strongContract = weakContract;
                if (!weakContract) {
                    return;
                }
                if (strongContract.contractState == DPContractState_Registered) {
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
                    strongContract.contractState = DPContractState_NotRegistered;
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

-(void)addUsername:(NSString*)username save:(BOOL)save {
    [self addUsername:username status:DSBlockchainIdentityUsernameStatus_Initial save:save];
}

-(void)addUsername:(NSString*)username status:(DSBlockchainIdentityUsernameStatus)status save:(BOOL)save {
    [self.usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(DSBlockchainIdentityUsernameStatus_Initial)} forKey:username];
    if (save) {
        [self saveNewUsername:username status:DSBlockchainIdentityUsernameStatus_Initial];
    }
    if (self.registered && status != DSBlockchainIdentityUsernameStatus_Confirmed) {
        [self registerUsernamesWithCompletion:^(BOOL success, NSError * _Nonnull error) {
            
        }];
    }
}

-(DSBlockchainIdentityUsernameStatus)statusOfUsername:(NSString*)username {
    return [[[self.usernameStatuses objectForKey:username] objectForKey:BLOCKCHAIN_USERNAME_STATUS] unsignedIntegerValue];
}

-(NSArray<NSString*>*)usernames {
    return [self.usernameStatuses allKeys];
}

-(NSArray<NSString*>*)unregisteredUsernames {
    return [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_Initial];
}

-(NSArray<NSString*>*)usernamesWithStatus:(DSBlockchainIdentityUsernameStatus)usernameStatus {
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

-(NSArray<NSString*>*)preorderedUsernames {
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

-(NSData*)saltForUsername:(NSString*)username saveSalt:(BOOL)saveSalt {
    NSData * salt;
    if ([self statusOfUsername:username] == DSBlockchainIdentityUsernameStatus_Initial || !(salt = [self.usernameSalts objectForKey:username])) {
        UInt160 random160 = uint160_RANDOM;
        salt = uint160_data(random160);
        [self.usernameSalts setObject:salt forKey:username];
        if (saveSalt) {
            [self saveUsername:username status:[self statusOfUsername:username] salt:salt commitSave:YES];
        }
    } else {
        salt = [self.usernameSalts objectForKey:username];
    }
    return salt;
}

-(NSMutableDictionary<NSString*,NSData*>*)saltedDomainHashesForUsernames:(NSArray*)usernames {
    NSMutableDictionary * mSaltedDomainHashes = [NSMutableDictionary dictionary];
    for (NSString * unregisteredUsername in usernames) {
        NSMutableData * saltedDomain = [NSMutableData data];
        NSData * salt = [self saltForUsername:unregisteredUsername saveSalt:YES];
        NSString * usernameDomain = [[self topDomainName] isEqualToString:@""]?[unregisteredUsername lowercaseString]:[NSString stringWithFormat:@"%@.%@",[unregisteredUsername lowercaseString],[self topDomainName]];
        NSData * usernameDomainData = [usernameDomain dataUsingEncoding:NSUTF8StringEncoding];
        [saltedDomain appendData:salt];
        [saltedDomain appendData:@"5620".hexToData]; //56 because SHA256_2 and 20 because 32 bytes
        [saltedDomain appendUInt256:[usernameDomainData SHA256_2]];
        NSData * saltedDomainHashData = uint256_data([saltedDomain SHA256_2]);
        [mSaltedDomainHashes setObject:saltedDomainHashData forKey:unregisteredUsername];
        [self.usernameSalts setObject:salt forKey:unregisteredUsername];
    }
    return [mSaltedDomainHashes copy];
}

-(NSString*)topDomainName {
    return @"";
}

// MARK: Documents

-(NSArray<DPDocument*>*)preorderDocumentsForUnregisteredUsernames:(NSArray*)unregisteredUsernames {
    NSMutableArray * usernamePreorderDocuments = [NSMutableArray array];
    for (NSData * saltedDomainHashData in [[self saltedDomainHashesForUsernames:unregisteredUsernames] allValues]) {
        NSError * error = nil;
        NSString * saltedDomainHashString = [saltedDomainHashData hexString];
        DSStringValueDictionary * dataDictionary = @{
            @"saltedDomainHash": saltedDomainHashString
        };
        DPDocument * document = [self.dpnsDocumentFactory documentOnTable:@"preorder" withDataDictionary:dataDictionary error:&error];
        [usernamePreorderDocuments addObject:document];
    }
    return usernamePreorderDocuments;
}

-(NSArray<DPDocument*>*)domainDocumentsForUnregisteredUsernames:(NSArray*)unregisteredUsernames {
    NSMutableArray * usernameDomainDocuments = [NSMutableArray array];
    for (NSString * username in [self saltedDomainHashesForUsernames:unregisteredUsernames]) {
        NSError * error = nil;
        NSMutableData * nameHashData = [NSMutableData data];
        [nameHashData appendData:@"5620".hexToData]; //56 because SHA256_2 and 20 because 32 bytes
        NSData * usernameData = [[username lowercaseString] dataUsingEncoding:NSUTF8StringEncoding];
        [nameHashData appendUInt256:[usernameData SHA256_2]];
        DSStringValueDictionary * dataDictionary = @{
            @"nameHash":nameHashData.hexString,
            @"label":username,
            @"normalizedLabel": [username lowercaseString],
            @"normalizedParentDomainName":[self topDomainName],
            @"preorderSalt": [self.usernameSalts objectForKey:username].base58String,
            @"records" : @{@"dashIdentity":uint256_base58(self.uniqueID)}
        };
        DPDocument * document = [self.dpnsDocumentFactory documentOnTable:@"domain" withDataDictionary:dataDictionary error:&error];
        [usernameDomainDocuments addObject:document];
    }
    return usernameDomainDocuments;
}

// MARK: Transitions

-(DSDocumentTransition*)preorderTransitionForUnregisteredUsernames:(NSArray*)unregisteredUsernames {
    NSArray * usernamePreorderDocuments = [self preorderDocumentsForUnregisteredUsernames:unregisteredUsernames];
    if (![usernamePreorderDocuments count]) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:usernamePreorderDocuments withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID onChain:self.chain];
    return transition;
}

-(DSDocumentTransition*)domainTransitionForUnregisteredUsernames:(NSArray*)unregisteredUsernames {
    NSArray * usernamePreorderDocuments = [self domainDocumentsForUnregisteredUsernames:unregisteredUsernames];
    if (![usernamePreorderDocuments count]) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:usernamePreorderDocuments withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID onChain:self.chain];
    return transition;
}

// MARK: Registering

-(void)registerUsernamesWithCompletion:(void (^ _Nullable)(BOOL success, NSError * error))completion {
    [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Initial completion:completion];
}

-(void)registerUsernamesAtStage:(DSBlockchainIdentityUsernameStatus)blockchainIdentityUsernameStatus completion:(void (^ _Nullable)(BOOL success, NSError * error))completion {
    DSDLog(@"registerUsernamesAtStage %lu",(unsigned long)blockchainIdentityUsernameStatus);
    switch (blockchainIdentityUsernameStatus) {
        case DSBlockchainIdentityUsernameStatus_Initial:
        {
            NSArray * usernames = [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_Initial];
            if (usernames.count) {
                [self registerPreorderedSaltedDomainHashesForUsernames:usernames completion:^(BOOL success, NSError * error) {
                    if (success) {
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending completion:completion];
                    } else {
                        if (completion) {
                            completion(NO,error);
                        }
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending completion:completion];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending:
        {
            NSArray * usernames = [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending];
            NSDictionary<NSString*,NSData *>* saltedDomainHashes = [self saltedDomainHashesForUsernames:usernames];
            if (saltedDomainHashes.count) {
                [self monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:2 completion:^(BOOL allFound, NSError * error) {
                    if (allFound) {
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Preordered completion:completion];
                    } else {
                        if (completion) {
                            completion(NO,error);
                        }
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Preordered completion:completion];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_Preordered:
        {
            NSArray * usernames = [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_Preordered];
            if (usernames.count) {
                [self registerUsernameDomainsForUsernames:usernames completion:^(BOOL success, NSError * error) {
                    if (success) {
                        [self saveUsernames:usernames toStatus:DSBlockchainIdentityUsernameStatus_RegistrationPending];
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_RegistrationPending completion:completion];
                    } else {
                        if (completion) {
                            completion(NO,error);
                        }
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_RegistrationPending completion:completion];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_RegistrationPending:
        {
            NSArray * usernames = [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_RegistrationPending];
            if (usernames.count) {
                [self monitorForDPNSUsernames:usernames withRetryCount:2 completion:completion];
            }
            break;
        }
        default:
            break;
    }
}

//Preorder stage
-(void)registerPreorderedSaltedDomainHashesForUsernames:(NSArray*)usernames completion:(void (^ _Nullable)(BOOL success, NSError * error))completion {
    DSDocumentTransition * transition = [self preorderTransitionForUnregisteredUsernames:usernames];
    [self signStateTransition:transition withPrompt:@"Register Usernames?" completion:^(BOOL success) {
        if (success) {
            [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (NSString * string in usernames) {
                        NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:string] mutableCopy];
                        if (!usernameStatusDictionary) {
                            usernameStatusDictionary = [NSMutableDictionary dictionary];
                        }
                        [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending) forKey:BLOCKCHAIN_USERNAME_STATUS];
                        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:string];
                    }
                    [self saveUsernames:usernames toStatus:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending];
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

-(void)registerUsernameDomainsForUsernames:(NSArray*)usernames completion:(void (^ _Nullable)(BOOL success, NSError * error))completion {
    DSDocumentTransition * transition = [self domainTransitionForUnregisteredUsernames:usernames];
    [self signStateTransition:transition withPrompt:@"Register Usernames?" completion:^(BOOL success) {
        if (success) {
            [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (NSString * string in usernames) {
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

- (void)fetchUsernamesWithCompletion:(void (^)(BOOL success, NSError * error))completion {
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
            if (username) {
                NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:username] mutableCopy];
                if (!usernameStatusDictionary) {
                    usernameStatusDictionary = [NSMutableDictionary dictionary];
                }
                [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_Confirmed) forKey:BLOCKCHAIN_USERNAME_STATUS];
                [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:username];
                [self saveNewUsername:username status:DSBlockchainIdentityUsernameStatus_Confirmed];
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

-(void)monitorForBlockchainIdentityWithRetryCount:(uint32_t)retryCount completion:(void (^)(BOOL success, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getIdentityById:self.uniqueIdString success:^(NSDictionary * _Nonnull identityDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (identityDictionary.count) {
            [strongSelf applyIdentityDictionary:identityDictionary];
            strongSelf.registrationStatus = DSBlockchainIdentityRegistrationStatus_Registered;
            [self save];
        }
        
        if (completion) {
            completion(YES,nil);
        }
    } failure:^(NSError * _Nonnull error) {
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self monitorForBlockchainIdentityWithRetryCount:retryCount - 1 completion:completion];
            });
        } else {
            completion(FALSE,error);
        }
    }];
}

-(void)monitorForDPNSUsernames:(NSArray*)usernames withRetryCount:(uint32_t)retryCount completion:(void (^)(BOOL allFound, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDPNSDocumentsForUsernames:usernames inDomain:[self topDomainName] success:^(id _Nonnull domainDocumentArray) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if ([domainDocumentArray isKindOfClass:[NSArray class]]) {
            NSMutableArray * usernamesLeft = [usernames mutableCopy];
            for (NSString * username in usernames) {
                for (NSDictionary * domainDocument in domainDocumentArray) {
                    if ([[domainDocument objectForKey:@"normalizedLabel"] isEqualToString:[username lowercaseString]]) {
                        NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:username] mutableCopy];
                        if (!usernameStatusDictionary) {
                            usernameStatusDictionary = [NSMutableDictionary dictionary];
                        }
                        [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_Confirmed) forKey:BLOCKCHAIN_USERNAME_STATUS];
                        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:username];
                        [strongSelf saveUsername:username status:DSBlockchainIdentityUsernameStatus_Confirmed salt:nil commitSave:YES];
                        [usernamesLeft removeObject:username];
                    }
                }
            }
            if ([usernamesLeft count] && retryCount > 0) {
                [strongSelf monitorForDPNSUsernames:usernamesLeft withRetryCount:retryCount - 1 completion:completion];
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
            [strongSelf monitorForDPNSUsernames:usernames withRetryCount:retryCount - 1 completion:completion];
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
                [strongSelf monitorForDPNSUsernames:usernames withRetryCount:retryCount - 1 completion:completion];
            });
        } else {
            completion(FALSE, error);
        }
    }];
}

-(void)monitorForDPNSPreorderSaltedDomainHashes:(NSDictionary*)saltedDomainHashes withRetryCount:(uint32_t)retryCount completion:(void (^)(BOOL allFound, NSError * error))completion {
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
            for (NSString * username in saltedDomainHashes) {
                NSData * saltedDomainHashData = saltedDomainHashes[username];
                NSString * saltedDomainHashString = [saltedDomainHashData hexString];
                for (NSDictionary * preorderDocument in preorderDocumentArray) {
                    if ([[preorderDocument objectForKey:@"saltedDomainHash"] isEqualToString:saltedDomainHashString]) {
                        NSMutableDictionary * usernameStatusDictionary = [[self.usernameStatuses objectForKey:username] mutableCopy];
                        if (!usernameStatusDictionary) {
                            usernameStatusDictionary = [NSMutableDictionary dictionary];
                        }
                        [usernameStatusDictionary setObject:@(DSBlockchainIdentityUsernameStatus_Preordered) forKey:BLOCKCHAIN_USERNAME_STATUS];
                        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:username];
                        [strongSelf saveUsername:username status:DSBlockchainIdentityUsernameStatus_Preordered salt:nil commitSave:YES];
                        [usernamesLeft removeObject:username];
                    }
                }
            }
            if ([usernamesLeft count] && retryCount > 0) {
                NSDictionary * saltedDomainHashesLeft = [saltedDomainHashes dictionaryWithValuesForKeys:usernamesLeft];
                [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashesLeft withRetryCount:retryCount - 1 completion:completion];
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
            [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:retryCount - 1 completion:completion];
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
                [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:retryCount - 1 completion:completion];
            });
        } else {
            if (completion) {
                completion(FALSE,error);
            }
        }
    }];
}

-(void)monitorForContract:(DPContract*)contract withRetryCount:(uint32_t)retryCount completion:(void (^)(BOOL success, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    NSParameterAssert(contract);
    if (!contract) return;
    [self.DAPINetworkService fetchContractForId:contract.base58ContractID success:^(id _Nonnull contractDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                DSLocalizedString(@"Internal memory allocation error", nil)}]);
            }
            return;
        }
        DSDLog(@"Contract dictionary is %@",contractDictionary);
        if ([contractDictionary isKindOfClass:[NSDictionary class]] && [contractDictionary[@"contractId"] isEqualToString:contract.base58ContractID]) {
            contract.contractState = DPContractState_Registered;
            if (completion) {
                completion(TRUE,nil);
            }
        } else if (retryCount > 0) {
            [strongSelf monitorForContract:contract withRetryCount:retryCount - 1 completion:completion];
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
                [strongSelf monitorForContract:contract withRetryCount:retryCount - 1 completion:completion];
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
    if (self.type == DSBlockchainIdentityType_Unknown) {
        return NO;
    }
    return YES;
}

-(DPDocument*)matchingDashpayUserProfileDocument {
    if (self.matchingDashpayUser) {
        DSStringValueDictionary * dataDictionary = @{
            @"publicMessage": self.matchingDashpayUser.publicMessage?self.matchingDashpayUser.publicMessage:@"",
            @"avatarUrl": self.matchingDashpayUser.avatarPath?self.matchingDashpayUser.avatarPath:@"https://api.adorable.io/avatars/120/example",
            @"displayName": self.matchingDashpayUser.displayName?self.matchingDashpayUser.displayName:(self.currentUsername?self.currentUsername:@""),
            @"$rev": @(self.matchingDashpayUser.profileDocumentRevision + 1)
        };
        NSError * error = nil;
        DPDocument * document = [self.dashpayDocumentFactory documentOnTable:@"profile" withDataDictionary:dataDictionary error:&error];
        return document;
    } else {
        return nil;
    }
}

-(DSDocumentTransition*)profileDocumentTransition {
    DPDocument * profileDocument = [self matchingDashpayUserProfileDocument];
    if (!profileDocument) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:@[profileDocument] withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID onChain:self.chain];
    return transition;
}


// MARK: Sending a Friend Request

- (void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL success, NSError * error))completion {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getIdentityByName:potentialContact.username inDomain:[self topDomainName] success:^(NSDictionary *_Nonnull blockchainIdentityDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                DSLocalizedString(@"Internal memory allocation error", nil)}]);
            }
            return;
        }
        NSString * base58String = nil;
        if (!blockchainIdentityDictionary || !(base58String = blockchainIdentityDictionary[@"id"])) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                    DSLocalizedString(@"Malformed platform response", nil)}]);
                });
            }
            return;
        }
        
        UInt256 blockchainIdentityContactUniqueId = base58String.base58ToData.UInt256;
        
        NSAssert(!uint256_is_zero(blockchainIdentityContactUniqueId), @"blockchainIdentityContactUniqueId should not be null");
        
        DSBlockchainIdentityEntity * potentialContactBlockchainIdentityEntity = [DSBlockchainIdentityEntity anyObjectMatchingInContext:self.managedObjectContext withPredicate:@"uniqueID == %@",uint256_data(blockchainIdentityContactUniqueId)];
        
        DSBlockchainIdentity * potentialContactBlockchainIdentity = nil;
        
        if (potentialContactBlockchainIdentityEntity) {
            potentialContactBlockchainIdentity = [self.chain blockchainIdentityForUniqueId:blockchainIdentityContactUniqueId];
            if (!potentialContactBlockchainIdentity) {
                potentialContactBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:potentialContactBlockchainIdentityEntity inContext:self.managedObjectContext];
            }
        } else {
            potentialContactBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithUniqueId:blockchainIdentityContactUniqueId onChain:self.chain inContext:self.managedObjectContext];

            [potentialContactBlockchainIdentity saveInitial];
        }
        [potentialContactBlockchainIdentity applyIdentityDictionary:blockchainIdentityDictionary];
        [potentialContactBlockchainIdentity save];
        
        if (![potentialContactBlockchainIdentity isDashpayReady]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                DSLocalizedString(@"User has actions to complete before being able to use Dashpay", nil)}]);
            });

            return;
        }
        uint32_t destinationKeyIndex = [potentialContactBlockchainIdentity firstIndexOfKeyOfType:self.currentMainKeyType createIfNotPresent:NO];
        uint32_t sourceKeyIndex = [self firstIndexOfKeyOfType:self.currentMainKeyType createIfNotPresent:NO];
        
        
        DSAccount * account = [self.wallet accountWithNumber:0];
        if (sourceKeyIndex == UINT32_MAX) { //not found
            //to do register a new key
            NSAssert(FALSE, @"we shouldn't be getting here");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO,[NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                    DSLocalizedString(@"Internal key handling error", nil)}]);
                });
            }
            return;
        }
        DSPotentialOneWayFriendship * potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationBlockchainIdentity:potentialContactBlockchainIdentity destinationKeyIndex:destinationKeyIndex sourceBlockchainIdentity:self sourceKeyIndex:sourceKeyIndex account:account];
        
        [potentialFriendship createDerivationPath];
        
        [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship completion:completion];
    } failure:^(NSError *_Nonnull error) {
        DSDLog(@"%@", error);
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO,error);
            });
        }
    }];
}

- (void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialOneWayFriendship*)potentialFriendship completion:(void (^)(BOOL success, NSError * error))completion {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    if (!potentialFriendship.destinationBlockchainIdentity) {
        NSAssert(potentialFriendship.destinationBlockchainIdentity, @"There must be a destination contact if the destination blockchain identity is not known");
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    
    [self.DAPIClient sendDocument:potentialFriendship.contactRequestDocument forIdentity:self contract:contract completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                    DSLocalizedString(@"Internal memory allocation error", nil)}]);
                });
            }
            return;
        }
        
        BOOL success = error == nil;
        
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
            return;
        }
        
        DSFriendRequestEntity * friendRequest = [potentialFriendship outgoingFriendRequestForDashpayUserEntity:potentialFriendship.destinationBlockchainIdentity.matchingDashpayUser];
        [strongSelf.matchingDashpayUser addOutgoingRequestsObject:friendRequest];
        [potentialFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequest];
        [DSFriendRequestEntity saveContext];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success,error);
            });
        }
        
    }];
}

-(void)acceptFriendRequest:(DSFriendRequestEntity*)friendRequest completion:(void (^)(BOOL success, NSError * error))completion {
    NSAssert(_isLocal, @"This should not be performed on a non local blockchain identity");
    if (!_isLocal) return;
    DSAccount * account = [self.wallet accountWithNumber:0];
    DSDashpayUserEntity * otherDashpayUser = friendRequest.sourceContact;
    DSBlockchainIdentity * otherBlockchainIdentity = [self.chain blockchainIdentityForUniqueId:otherDashpayUser.associatedBlockchainIdentity.uniqueID.UInt256];
    
    if (!otherBlockchainIdentity) {
        otherBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:otherDashpayUser.associatedBlockchainIdentity inContext:self.managedObjectContext];
    }
    //    DSPotentialContact *contact = [[DSPotentialContact alloc] initWithUsername:friendRequest.sourceContact.username avatarPath:friendRequest.sourceContact.avatarPath
    //                                                                 publicMessage:friendRequest.sourceContact.publicMessage];
    //    [contact setAssociatedBlockchainIdentityUniqueId:friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID.UInt256];
    //    DSKey * friendsEncyptionKey = [otherBlockchainIdentity keyOfType:friendRequest.sourceEncryptionPublicKeyIndex atIndex:friendRequest.sourceEncryptionPublicKeyIndex];
    //[DSKey keyForPublicKeyData:friendRequest.sourceContact.encryptionPublicKey forKeyType:friendRequest.sourceContact.encryptionPublicKeyType onChain:self.chain];
    //    [contact addPublicKey:friendsEncyptionKey atIndex:friendRequest.sourceContact.encryptionPublicKeyIndex];
    //    uint32_t sourceKeyIndex = [self firstIndexOfKeyOfType:friendRequest.sourceContact.encryptionPublicKeyType createIfNotPresent:NO];
    //    if (sourceKeyIndex == UINT32_MAX) { //not found
    //        //to do register a new key
    //        NSAssert(FALSE, @"we shouldn't be getting here");
    //        return;
    //    }
    DSPotentialOneWayFriendship *potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationBlockchainIdentity:otherBlockchainIdentity destinationKeyIndex:friendRequest.sourceKeyIndex sourceBlockchainIdentity:self sourceKeyIndex:friendRequest.destinationKeyIndex account:account];
    [potentialFriendship createDerivationPath];
    
    [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship completion:completion];
    
}

// MARK: Register Profile

- (void)createOrUpdateProfileWithDisplayName:(NSString*)displayName publicMessage:(NSString*)publicMessage avatarURLString:(NSString *)avatarURLString completion:(void (^)(BOOL success, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    DSDocumentTransition * transition = [self profileDocumentTransition];
    if (!transition) return;
    [self signStateTransition:transition withPrompt:@"Update profile?" completion:^(BOOL success) {
        if (success) {
            [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    if (completion) {
                        completion(NO, [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey:
                        DSLocalizedString(@"Internal memory allocation error", nil)}]);
                    }
                    return;
                }
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(YES,nil);
                    });
                }
                
                //                [self.DAPINetworkService getIdentityById:uint256_reverse_base58(self.registrationTransitionHash) success:^(NSDictionary *_Nonnull blockchainIdentity) {
                //                            __strong typeof(weakSelf) strongSelf = weakSelf;
                //                            if (!strongSelf) {
                //                                return;
                //                            }
                //
                //                            if (completion) {
                //                                completion(!!blockchainIdentity);
                //                            }
                //                        } failure:^(NSError * _Nonnull error) {
                //                            DSDLog(@"%@",error);
                //                            if (completion) {
                //                                completion(NO);
                //                            }
                //                        }];
            } failure:^(NSError * _Nonnull error) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(NO,error);
                    });
                }
            }];
            
        }
    }];
}

//

// MARK: Fetching

- (void)fetchProfileWithCompletion:(void (^)(BOOL success, NSError * error))completion {
    
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
    
    [self fetchProfileForBlockchainIdentityUniqueId:self.uniqueID saveReturnedProfile:TRUE context:self.managedObjectContext completion:^(BOOL success, NSError * error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
            });
        }
    }];
}

- (void)fetchProfileForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId saveReturnedProfile:(BOOL)saveReturnedProfile context:(NSManagedObjectContext*)context completion:(void (^)(BOOL success, NSError * error))completion {
    __weak typeof(self) weakSelf = self;
    
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
    
    [self.DAPINetworkService getDashpayProfileForUserId:uint256_base58(blockchainIdentityUniqueId) success:^(NSArray<NSDictionary *> * _Nonnull documents) {
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES,nil);
                });
            }
            return;
        }
        
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
            [DSDashpayUserEntity setContext:context];
            [DSChainEntity setContext:context];
            DSDashpayUserEntity * contact = [DSDashpayUserEntity anyObjectMatchingInContext:context withPredicate:@"associatedBlockchainIdentity.uniqueID == %@", uint256_data(blockchainIdentityUniqueId)];
            if (!contact || [[contactDictionary objectForKey:@"$rev"] intValue] != contact.profileDocumentRevision) {
                
                if (!contact) {
                    contact = [DSDashpayUserEntity managedObjectInContext:context];
                    contact.chain = strongSelf.wallet.chain.chainEntity;
                    DSBlockchainIdentity * blockchainIdentity;
                    if (uint256_eq(blockchainIdentityUniqueId, strongSelf.uniqueID) && !strongSelf.matchingDashpayUser) {
                        NSAssert(strongSelf.blockchainIdentityEntity, @"blockchainIdentityEntity must exist");
                        contact.associatedBlockchainIdentity = strongSelf.blockchainIdentityEntity;
                        self.matchingDashpayUser = contact;
                        if (saveReturnedProfile) {
                            [DSDashpayUserEntity saveContext];
                        }
                    } else if ((blockchainIdentity = [strongSelf.wallet blockchainIdentityForUniqueId:blockchainIdentityUniqueId]) && !blockchainIdentity.matchingDashpayUser) {
                        //this means we are fetching a contact for another blockchain user on the device
                        DSBlockchainIdentity * blockchainIdentity = [strongSelf.wallet blockchainIdentityForUniqueId:blockchainIdentityUniqueId];
                        NSAssert(blockchainIdentity.blockchainIdentityEntity, @"blockchainIdentityEntity must exist");
                        contact.associatedBlockchainIdentity = blockchainIdentity.blockchainIdentityEntity;
                        blockchainIdentity.matchingDashpayUser = contact;
                    }
                }
                contact.profileDocumentRevision = [[contactDictionary objectForKey:@"$rev"] intValue];
                contact.avatarPath = [contactDictionary objectForKey:@"avatarUrl"];
                contact.publicMessage = [contactDictionary objectForKey:@"about"];
                contact.displayName = [contactDictionary objectForKey:@"displayName"];
                contact.isRegistered = TRUE;
                
                if (saveReturnedProfile) {
                    [DSDashpayUserEntity saveContext];
                }
            }
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES,nil);
                });
            }
        }];
        
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO,error);
            });
        }
    }];
}

- (void)fetchIncomingContactRequests:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDashpayIncomingContactRequestsForUserId:self.uniqueIdString since:0 success:^(NSArray<NSDictionary *> * _Nonnull documents) {
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
        
        [strongSelf handleContactRequestObjects:documents context:strongSelf.managedObjectContext completion:^(BOOL success, NSArray<NSError *> *errors) {
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
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDashpayOutgoingContactRequestsForUserId:self.uniqueIdString since:0 success:^(NSArray<NSDictionary *> * _Nonnull documents) {
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
        
        [strongSelf handleContactRequestObjects:documents context:strongSelf.managedObjectContext completion:^(BOOL success, NSArray<NSError *> *errors) {
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
            DSFriendRequestEntity * friendRequest = [DSFriendRequestEntity anyObjectMatchingInContext:context withPredicate:@"destinationContact == %@ && sourceContact.associatedBlockchainIdentity.uniqueID == %@",self.matchingDashpayUser,uint256_data(contactRequest.senderBlockchainIdentityUniqueId)];
            if (!friendRequest) {
                [incomingNewRequests addObject:contactRequest];
            } else if (friendRequest.sourceContact == nil) {
                
            }
        } else if (uint256_eq(contactRequest.senderBlockchainIdentityUniqueId, self.uniqueID)) {
            //we are the sender, this is an outgoing request
            BOOL isNew = ![DSFriendRequestEntity countObjectsMatchingInContext:context withPredicate:@"sourceContact == %@ && destinationContact.associatedBlockchainIdentity.uniqueID == %@",self.matchingDashpayUser,[NSData dataWithUInt256:contactRequest.recipientBlockchainIdentityUniqueId]];
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
    [self.managedObjectContext performBlockAndWait:^{
        [DSDashpayUserEntity setContext:context];
        [DSFriendRequestEntity setContext:context];
        
        __block BOOL succeeded = YES;
        __block NSMutableArray * errors = [NSMutableArray array];
        dispatch_group_t dispatchGroup = dispatch_group_create();
        
        for (DSContactRequest * contactRequest in incomingRequests) {
            DSBlockchainIdentityEntity * externalBlockchainIdentity = [DSBlockchainIdentityEntity anyObjectMatchingInContext:context withPredicate:@"uniqueID == %@",uint256_data(contactRequest.senderBlockchainIdentityUniqueId)];
            if (!externalBlockchainIdentity) {
                //no externalBlockchainIdentity exists yet, which means no dashpay user
                dispatch_group_enter(dispatchGroup);
                DSBlockchainIdentity * senderBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithUniqueId:contactRequest.senderBlockchainIdentityUniqueId onChain:self.chain inContext:self.managedObjectContext];
                [senderBlockchainIdentity saveInitial];
                [senderBlockchainIdentity fetchAllNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
                    if (success) {
                        DSKey * senderPublicKey = [senderBlockchainIdentity keyAtIndex:contactRequest.senderKeyIndex];
                        NSData * extendedPublicKeyData = [contactRequest decryptedPublicKeyDataWithKey:senderPublicKey];
                        DSDashpayUserEntity * senderDashpayUserEntity = senderBlockchainIdentity.blockchainIdentityEntity.matchingDashpayUser;
                        NSAssert(senderDashpayUserEntity, @"The sender should exist");
                        [self addIncomingRequestFromContact:senderDashpayUserEntity
                                       forExtendedPublicKey:extendedPublicKeyData
                                                    context:context];
                    }
                    dispatch_group_leave(dispatchGroup);
                }];
                
            } else {
                if ([self.chain blockchainIdentityForUniqueId:externalBlockchainIdentity.uniqueID.UInt256]) {
                    //it's also local (aka both contacts are local to this device), we should store the extended public key for the destination
                    DSBlockchainIdentity * sourceBlockchainIdentity = [self.chain blockchainIdentityForUniqueId:externalBlockchainIdentity.uniqueID.UInt256];
                    
                    DSAccount * account = [sourceBlockchainIdentity.wallet accountWithNumber:0];
                    
                    DSPotentialOneWayFriendship * potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationBlockchainIdentity:self destinationKeyIndex:contactRequest.recipientKeyIndex sourceBlockchainIdentity:sourceBlockchainIdentity sourceKeyIndex:contactRequest.senderKeyIndex account:account];
                    
                    DSIncomingFundsDerivationPath * derivationPath = [potentialFriendship createDerivationPath];
                    
                    DSFriendRequestEntity * friendRequest = [potentialFriendship outgoingFriendRequestForDashpayUserEntity:self.matchingDashpayUser];
                    [potentialFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequest];
                    [self.matchingDashpayUser addIncomingRequestsObject:friendRequest];
                    
                    if ([[friendRequest.sourceContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",self.matchingDashpayUser]] count]) {
                        [self.matchingDashpayUser addFriendsObject:friendRequest.sourceContact];
                    }
                    
                    [account addIncomingDerivationPath:derivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier];
                    [DSFriendRequestEntity saveContext];
                    
                } else {
                    DSBlockchainIdentity * sourceBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:externalBlockchainIdentity inContext:self.managedObjectContext];
                    NSAssert(sourceBlockchainIdentity, @"This should not be null");
                    if ([sourceBlockchainIdentity activeKeyCount] > 0 && [sourceBlockchainIdentity keyAtIndex:contactRequest.senderKeyIndex]) {
                        //the contact already existed, and has an encryption public key set, create the incoming friend request, add a friendship if an outgoing friend request also exists
                        DSKey * key = [sourceBlockchainIdentity keyAtIndex:contactRequest.senderKeyIndex];
                        NSData * decrypted = [contactRequest decryptedPublicKeyDataWithKey:key];
                        NSAssert(decrypted, @"Data should be decrypted");
                        [self addIncomingRequestFromContact:externalBlockchainIdentity.matchingDashpayUser
                                       forExtendedPublicKey:decrypted
                                                    context:context];
                        
                        if ([[externalBlockchainIdentity.matchingDashpayUser.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",self.matchingDashpayUser]] count]) {
                            [self.matchingDashpayUser addFriendsObject:externalBlockchainIdentity.matchingDashpayUser];
                            [DSFriendRequestEntity saveContext];
                        }
                        
                    } else {
                        //the blockchain identity is already known, but needs to updated to get the right key, create the incoming friend request, add a friendship if an outgoing friend request also exists
                        dispatch_group_enter(dispatchGroup);
                        [sourceBlockchainIdentity fetchNeededNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
                            if (success) {
                                DSKey * key = [sourceBlockchainIdentity keyAtIndex:contactRequest.senderKeyIndex];
                                NSData * decrypted = [contactRequest decryptedPublicKeyDataWithKey:key];
                                NSAssert(decrypted, @"Data should be decrypted");
                                [self addIncomingRequestFromContact:externalBlockchainIdentity.matchingDashpayUser
                                               forExtendedPublicKey:decrypted
                                                            context:context];
                                
                                if ([[externalBlockchainIdentity.matchingDashpayUser.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",self.matchingDashpayUser]] count]) {
                                    [self.matchingDashpayUser addFriendsObject:externalBlockchainIdentity.matchingDashpayUser];
                                    [DSFriendRequestEntity saveContext];
                                }
                            } else {
                                succeeded = FALSE;
                                [errors addObject:error];
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

-(void)addFriendshipFromSourceBlockchainIdentity:(DSBlockchainIdentity*)sourceBlockchainIdentity sourceKeyIndex:(uint32_t)sourceKeyIndex toRecipientBlockchainIdentity:(DSBlockchainIdentity*)recipientBlockchainIdentity recipientKeyIndex:(uint32_t)recipientKeyIndex inContext:(NSManagedObjectContext*)context {
    DSAccount * account = [self.wallet accountWithNumber:0];
    
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObjectInContext:context];
    friendRequestEntity.sourceContact = sourceBlockchainIdentity.matchingDashpayUser;
    friendRequestEntity.destinationContact = recipientBlockchainIdentity.matchingDashpayUser;
    NSAssert(friendRequestEntity.sourceContact != friendRequestEntity.destinationContact, @"This must be different contacts");
    
    DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:0 onChain:self.chain];
    
    friendRequestEntity.account = accountEntity;
    
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    
    [self.matchingDashpayUser addOutgoingRequestsObject:friendRequestEntity];
    
    DSPotentialOneWayFriendship * realFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationBlockchainIdentity:recipientBlockchainIdentity destinationKeyIndex:recipientKeyIndex sourceBlockchainIdentity:self sourceKeyIndex:sourceKeyIndex account:account];
    
    DSIncomingFundsDerivationPath * derivationPath = [realFriendship createDerivationPath];
    
    if (recipientBlockchainIdentity.isLocal) { //the destination is also local
        NSAssert(recipientBlockchainIdentity.wallet, @"Wallet should be known");
        DSAccount * recipientAccount = [recipientBlockchainIdentity.wallet accountWithNumber:0];
        NSAssert(recipientAccount, @"Recipient Wallet should exist");
        [recipientAccount addIncomingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
        if (recipientAccount != account) {
            [account addOutgoingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
        }
    } else {
        //todo update outgoing derivation paths to incoming derivation paths as blockchain users come in
        [account addOutgoingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
    }
    
    //[account addIncomingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
    
    friendRequestEntity.derivationPath = [realFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequestEntity];
    
    NSAssert(friendRequestEntity.derivationPath, @"derivation path must be present");
    
    [self.matchingDashpayUser addOutgoingRequestsObject:friendRequestEntity];
    if ([[recipientBlockchainIdentity.matchingDashpayUser.outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact == %@",self.matchingDashpayUser]] count]) {
        [self.matchingDashpayUser addFriendsObject:recipientBlockchainIdentity.matchingDashpayUser];
    }
    
    [DSDashpayUserEntity saveContext];
}

- (void)handleOutgoingRequests:(NSArray <DSContactRequest *>  *)outgoingRequests
                       context:(NSManagedObjectContext *)context
                    completion:(void (^)(BOOL success, NSArray<NSError *> * errors))completion {
    [context performBlockAndWait:^{
        [DSDashpayUserEntity setContext:context];
        [DSFriendRequestEntity setContext:context];
        __block NSMutableArray * errors = [NSMutableArray array];
        
        __block BOOL succeeded = YES;
        dispatch_group_t dispatchGroup = dispatch_group_create();
        
        for (DSContactRequest * contactRequest in outgoingRequests) {
            DSBlockchainIdentityEntity * recipientBlockchainIdentityEntity = [DSBlockchainIdentityEntity anyObjectMatchingInContext:context withPredicate:@"uniqueID == %@",uint256_data(contactRequest.recipientBlockchainIdentityUniqueId)];
            if (!recipientBlockchainIdentityEntity) {
                //no contact exists yet
                dispatch_group_enter(dispatchGroup);
                DSBlockchainIdentity * recipientBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithUniqueId:contactRequest.recipientBlockchainIdentityUniqueId onChain:self.chain inContext:self.managedObjectContext];
                [recipientBlockchainIdentity saveInitial];
                [recipientBlockchainIdentity fetchAllNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
                    if (success) {
                        [self addFriendshipFromSourceBlockchainIdentity:self sourceKeyIndex:contactRequest.senderKeyIndex toRecipientBlockchainIdentity:recipientBlockchainIdentity recipientKeyIndex:contactRequest.recipientKeyIndex inContext:self.managedObjectContext];
                    } else {
                        succeeded = FALSE;
                        [errors addObject:error];
                    }
                    dispatch_group_leave(dispatchGroup);
                }];
            } else {
                //the recipient blockchain identity is already known, meaning they had made a friend request to us before, and on another device we had accepted
                //or the recipient blockchain identity is also local to the device
                
                [DSDashpayUserEntity setContext:context];
                DSWallet * recipientWallet = nil;
                DSBlockchainIdentity * recipientBlockchainIdentity = [self.chain blockchainIdentityForUniqueId:recipientBlockchainIdentityEntity.uniqueID.UInt256 foundInWallet:&recipientWallet];
                BOOL isLocal = TRUE;
                if (!recipientBlockchainIdentity) {
                    //this is not local
                    recipientBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:recipientBlockchainIdentityEntity inContext:self.managedObjectContext];
                    isLocal = FALSE;
                }
                
                //check to see if the blockchain identity has keys
                
                if (!recipientBlockchainIdentity.activeKeyCount) {
                    dispatch_group_enter(dispatchGroup);
                    [recipientBlockchainIdentity fetchAllNetworkStateInformationWithCompletion:^(BOOL success, NSError * error) {
                        if (success) {
                            [self addFriendshipFromSourceBlockchainIdentity:self sourceKeyIndex:contactRequest.senderKeyIndex toRecipientBlockchainIdentity:recipientBlockchainIdentity recipientKeyIndex:contactRequest.recipientKeyIndex inContext:self.managedObjectContext];
                        } else {
                            succeeded = FALSE;
                            [errors addObject:error];
                        }
                        dispatch_group_leave(dispatchGroup);
                    }];
                    return;
                }
                
                [self addFriendshipFromSourceBlockchainIdentity:self sourceKeyIndex:contactRequest.senderKeyIndex toRecipientBlockchainIdentity:recipientBlockchainIdentity recipientKeyIndex:contactRequest.recipientKeyIndex inContext:self.managedObjectContext];

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
                forExtendedPublicKey:(NSData*)extendedPublicKey
                             context:(NSManagedObjectContext *)context {
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObjectInContext:context];
    friendRequestEntity.sourceContact = dashpayUserEntity;
    friendRequestEntity.destinationContact = self.matchingDashpayUser;
    NSAssert(friendRequestEntity.sourceContact != friendRequestEntity.destinationContact, @"This must be different contacts");
    
    DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity managedObjectInContext:context];
    derivationPathEntity.chain = self.chain.chainEntity;
    
    friendRequestEntity.derivationPath = derivationPathEntity;
    
    DSAccount * account = [self.wallet accountWithNumber:0];
    
    DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:account.accountNumber onChain:self.chain];
    
    derivationPathEntity.account = accountEntity;
    
    friendRequestEntity.account = accountEntity;
    
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    
    DSIncomingFundsDerivationPath * derivationPath = [DSIncomingFundsDerivationPath externalDerivationPathWithExtendedPublicKey:extendedPublicKey withDestinationBlockchainIdentityUniqueId:self.matchingDashpayUser.associatedBlockchainIdentity.uniqueID.UInt256 sourceBlockchainIdentityUniqueId:dashpayUserEntity.associatedBlockchainIdentity.uniqueID.UInt256 onChain:self.chain];
    
    derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
    
    [derivationPath storeExternalDerivationPathExtendedPublicKeyToKeyChain];
    
    //incoming request uses an outgoing derivation path
    [account addOutgoingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
    
    [self.matchingDashpayUser addIncomingRequestsObject:friendRequestEntity];
    
    [DSDashpayUserEntity saveContext];
}

// MARK: - Persistence

// MARK: Saving

-(void)saveInitial {
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityUsernameEntity setContext:self.managedObjectContext];
        [DSCreditFundingTransactionEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * entity = [DSBlockchainIdentityEntity managedObject];
        entity.uniqueID = uint256_data(self.uniqueID);
        entity.isLocal = self.isLocal;
        if (self.isLocal) {
            [DSCreditFundingTransactionEntity setContext:self.managedObjectContext];
            NSData * transactionHash = uint256_data(self.registrationCreditFundingTransaction.txHash);
            DSCreditFundingTransactionEntity * transactionEntity = (DSCreditFundingTransactionEntity*)[DSTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", transactionHash];
            entity.registrationFundingTransaction = transactionEntity;
        }
        entity.chain = self.chain.chainEntity;
        for (NSString * username in self.usernameStatuses) {
            DSBlockchainIdentityUsernameEntity * usernameEntity = [DSBlockchainIdentityUsernameEntity managedObject];
            usernameEntity.status = [self statusOfUsername:username];
            usernameEntity.stringValue = username;
            usernameEntity.blockchainIdentity = entity;
            [entity addUsernamesObject:usernameEntity];
            [entity setDashpayUsername:usernameEntity];
        }
        [DSDashpayUserEntity setContext:self.managedObjectContext];
        [DSChainEntity setContext:self.managedObjectContext];
        DSDashpayUserEntity * dashpayUserEntity = [DSDashpayUserEntity managedObjectInContext:self.managedObjectContext];
        dashpayUserEntity.chain = self.chain.chainEntity;
        entity.matchingDashpayUser = dashpayUserEntity;
        
        self.matchingDashpayUser = dashpayUserEntity;
        [DSBlockchainIdentityEntity saveContext];
        if ([self isLocal]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self}];
            });
        }
    }];
}


-(void)save {
    [self.managedObjectContext performBlockAndWait:^{
        BOOL changeOccured = NO;
        NSMutableArray * updateEvents = [NSMutableArray array];
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityUsernameEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
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
        if (entity.type != self.type) {
            entity.type = self.type;
            changeOccured = YES;
            [updateEvents addObject:DSBlockchainIdentityUpdateEventType];
        }
        if (changeOccured) {
            [DSBlockchainIdentityEntity saveContext];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:updateEvents}];
            });
        }
    }];
}

-(NSString*)identifierForKeyAtPath:(NSIndexPath*)path fromDerivationPath:(DSDerivationPath*)derivationPath {
    return [NSString stringWithFormat:@"%@-%@-%@",self.uniqueIdString,derivationPath.standaloneExtendedPublicKeyUniqueID,[path indexPathString]];
}

-(void)saveNewKey:(DSKey*)key atPath:(NSIndexPath*)path withStatus:(DSBlockchainIdentityKeyStatus)status fromDerivationPath:(DSDerivationPath*)derivationPath {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal) return;
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityKeyPathEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * blockchainIdentityEntity = self.blockchainIdentityEntity;
        DSDerivationPathEntity * derivationPathEntity = derivationPath.derivationPathEntity;
        NSData *keyPathData = [NSKeyedArchiver archivedDataWithRootObject:path];
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsMatching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@",blockchainIdentityEntity,derivationPathEntity,keyPathData];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObject];
            blockchainIdentityKeyPathEntity.derivationPath = derivationPath.derivationPathEntity;
            blockchainIdentityKeyPathEntity.keyType = key.keyType;
            blockchainIdentityKeyPathEntity.keyStatus = status;
            setKeychainData(key.secretKeyData, [self identifierForKeyAtPath:path fromDerivationPath:derivationPath], YES);
            blockchainIdentityKeyPathEntity.path = keyPathData;
            blockchainIdentityKeyPathEntity.publicKeyData = key.publicKeyData;
            blockchainIdentityKeyPathEntity.keyID = (uint32_t)[path indexAtPosition:path.length - 1];
            [blockchainIdentityEntity addKeyPathsObject:blockchainIdentityKeyPathEntity];
            [DSBlockchainIdentityEntity saveContext];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:@[DSBlockchainIdentityUpdateEventKeyUpdate]}];
        });
    }];
}

-(void)saveNewKey:(DSKey*)key forKeyWithIndexID:(uint32_t)keyID withStatus:(DSBlockchainIdentityKeyStatus)status {
    NSAssert(!self.isLocal, @"This should only be called on non local blockchain identities");
    if (self.isLocal) return;
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityKeyPathEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * blockchainIdentityEntity = self.blockchainIdentityEntity;
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsMatching:@"blockchainIdentity == %@ && keyID == %@",blockchainIdentityEntity,@(keyID)];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObject];
            blockchainIdentityKeyPathEntity.keyType = key.keyType;
            blockchainIdentityKeyPathEntity.keyStatus = status;
            blockchainIdentityKeyPathEntity.keyID = keyID;
            blockchainIdentityKeyPathEntity.publicKeyData = key.publicKeyData;
            [blockchainIdentityEntity addKeyPathsObject:blockchainIdentityKeyPathEntity];
            [DSBlockchainIdentityEntity saveContext];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:@[DSBlockchainIdentityUpdateEventKeyUpdate]}];
        });
    }];
}


-(void)updateStatus:(DSBlockchainIdentityKeyStatus)status forKeyAtPath:(NSIndexPath*)path fromDerivationPath:(DSDerivationPath*)derivationPath {
    NSAssert(self.isLocal, @"This should only be called on local blockchain identities");
    if (!self.isLocal) return;
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityKeyPathEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
        DSDerivationPathEntity * derivationPathEntity = derivationPath.derivationPathEntity;
        NSData *keyPathData = [NSKeyedArchiver archivedDataWithRootObject:path];
        DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsMatching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@",entity, derivationPathEntity,keyPathData] firstObject];
        if (blockchainIdentityKeyPathEntity && (blockchainIdentityKeyPathEntity.keyStatus != status)) {
            blockchainIdentityKeyPathEntity.keyStatus = status;
            [DSBlockchainIdentityEntity saveContext];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:@[DSBlockchainIdentityUpdateEventKeyUpdate]}];
        });
    }];
}

-(void)updateStatus:(DSBlockchainIdentityKeyStatus)status forKeyWithIndexID:(uint32_t)keyID {
    NSAssert(!self.isLocal, @"This should only be called on non local blockchain identities");
    if (self.isLocal) return;
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityKeyPathEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
        DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsMatching:@"blockchainIdentity == %@ && derivationPath == NULL && keyID == %@",entity,@(keyID)] firstObject];
        if (blockchainIdentityKeyPathEntity) {
            DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObject];
            blockchainIdentityKeyPathEntity.keyStatus = status;
            [DSBlockchainIdentityEntity saveContext];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self,DSBlockchainIdentityUpdateEvents:@[DSBlockchainIdentityUpdateEventKeyUpdate]}];
        });
    }];
}

-(void)saveNewUsername:(NSString*)username status:(DSBlockchainIdentityUsernameStatus)status {
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityUsernameEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
        DSBlockchainIdentityUsernameEntity * usernameEntity = [DSBlockchainIdentityUsernameEntity managedObject];
        usernameEntity.status = status;
        usernameEntity.stringValue = username;
        usernameEntity.salt = [self saltForUsername:username saveSalt:NO];
        [entity addUsernamesObject:usernameEntity];
        [entity setDashpayUsername:usernameEntity];
        [DSBlockchainIdentityEntity saveContext];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateUsernameStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain, DSBlockchainIdentityKey:self}];
        });
    }];
    
}

-(void)saveUsernames:(NSArray*)usernames toStatus:(DSBlockchainIdentityUsernameStatus)status {
    [self.managedObjectContext performBlockAndWait:^{
        for (NSString * username in usernames) {
            [self saveUsername:username status:status salt:nil commitSave:NO];
        }
        [DSBlockchainIdentityEntity saveContext];
    }];
}

-(void)saveUsernamesToStatuses:(NSDictionary<NSString*,NSNumber*>*)dictionary {
    [self.managedObjectContext performBlockAndWait:^{
        for (NSString * username in dictionary) {
            DSBlockchainIdentityUsernameStatus status = [dictionary[username] intValue];
            [self saveUsername:username status:status salt:nil commitSave:NO];
        }
        [DSBlockchainIdentityEntity saveContext];
    }];
}

-(void)saveUsername:(NSString*)username status:(DSBlockchainIdentityUsernameStatus)status salt:(NSData*)salt commitSave:(BOOL)commitSave {
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityUsernameEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
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
                [DSBlockchainIdentityEntity saveContext];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateUsernameStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain, DSBlockchainIdentityKey:self, DSBlockchainIdentityUsernameKey:username}];
            });
        }
    }];
}

// MARK: Deletion

-(void)deletePersistentObjectAndSave:(BOOL)save {
    [self.managedObjectContext performBlockAndWait:^{
        DSBlockchainIdentityEntity * blockchainIdentityEntity = self.blockchainIdentityEntity;
        if (blockchainIdentityEntity) {
            NSSet <DSFriendRequestEntity *>* friendRequests = [blockchainIdentityEntity.matchingDashpayUser outgoingRequests];
            for (DSFriendRequestEntity * friendRequest in friendRequests) {
                uint32_t accountNumber = friendRequest.account.index;
                DSAccount * account = [self.wallet accountWithNumber:accountNumber];
                [account removeIncomingDerivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
            }
            [blockchainIdentityEntity deleteObject];
            if (save) {
                [DSBlockchainIdentityEntity saveContext];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainIdentityDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain,DSBlockchainIdentityKey:self}];
        });
    }];
}

// MARK: Entity

-(DSBlockchainIdentityEntity*)blockchainIdentityEntity {
    __block DSBlockchainIdentityEntity* entity = nil;
    [[DSBlockchainIdentityEntity context] performBlockAndWait:^{
        entity = [DSBlockchainIdentityEntity anyObjectMatching:@"uniqueID == %@",self.uniqueIDData];
    }];
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
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@-%@}",self.currentUsername,self.uniqueIdString]];
}

@end
