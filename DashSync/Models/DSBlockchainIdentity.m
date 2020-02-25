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
#import "DSContactEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSDashPlatform.h"
#import "DSPotentialFriendship.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSTransitionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.h"
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

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"
#define DEFAULT_SIGNING_ALGORITH DSDerivationPathSigningAlgorith_ECDSA

@interface DSBlockchainIdentity()

@property (nonatomic,weak) DSWallet * wallet;
@property (nonatomic,strong) NSMutableDictionary <NSString *,NSNumber *> * usernameStatuses;
@property (nonatomic,assign) UInt256 uniqueID;
@property (nonatomic,assign) DSUTXO lockedOutpoint;
@property (nonatomic,assign) uint32_t index;
@property (nonatomic,assign) DSBlockchainIdentityRegistrationStatus registrationStatus;
@property (nonatomic,assign) UInt256 registrationTransitionHash;
@property (nonatomic,assign) UInt256 lastTransitionHash;
@property (nonatomic,assign) uint64_t creditBalance;

@property (nonatomic,assign) uint32_t keysCreated;
@property (nonatomic,assign) uint32_t currentMainKeyIndex;
@property (nonatomic,assign) DSDerivationPathSigningAlgorith currentMainKeyType;

@property (nonatomic,strong) DSCreditFundingTransaction * registrationCreditFundingTransaction;

//@property(nonatomic,strong) DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition;
//@property(nonatomic,strong) NSMutableArray <DSBlockchainIdentityTopupTransition*>* blockchainIdentityTopupTransitions;
//@property(nonatomic,strong) NSMutableArray <DSBlockchainIdentityCloseTransition*>* blockchainIdentityCloseTransitions;
//@property(nonatomic,strong) NSMutableArray <DSBlockchainIdentityUpdateTransition*>* blockchainIdentityUpdateTransitions;
//@property(nonatomic,strong) NSMutableArray <DSDocumentTransition*>* documentTransitions;
//@property(nonatomic,strong) NSMutableArray <DSTransition*>* allTransitions;

@property(nonatomic,strong) NSMutableDictionary <NSString*,NSData*>* usernameSalts;

@property(nonatomic,readonly) DSDAPIClient* DAPIClient;
@property(nonatomic,readonly) DSDAPINetworkService* DAPINetworkService;

@property(nonatomic,strong) DPDocumentFactory* dashpayDocumentFactory;
@property(nonatomic,strong) DPDocumentFactory* dpnsDocumentFactory;

@property(nonatomic,strong) DSContactEntity * ownContact;

@property(nonatomic,strong) NSMutableDictionary * usedKeys;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSBlockchainIdentity

// MARK: - Initialization

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);
    
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.keysCreated = 0;
    self.registrationTransitionHash = UINT256_ZERO;
    self.currentMainKeyIndex = 0;
    self.currentMainKeyType = DSDerivationPathSigningAlgorith_ECDSA;
    self.index = index;
//    self.blockchainIdentityTopupTransitions = [NSMutableArray array];
//    self.blockchainIdentityCloseTransitions = [NSMutableArray array];
//    self.blockchainIdentityUpdateTransitions = [NSMutableArray array];
//    self.documentTransitions = [NSMutableArray array];
//    self.allTransitions = [NSMutableArray array];
    self.usernameStatuses = [NSMutableDictionary dictionary];
    self.usedKeys = [NSMutableDictionary dictionary];
    self.registrationStatus = DSBlockchainIdentityRegistrationStatus_Unknown;
    self.usernameSalts = [NSMutableDictionary dictionary];
    self.type = type;
    if (managedObjectContext) {
        self.managedObjectContext = managedObjectContext;
    } else {
        self.managedObjectContext = [NSManagedObject context];
    }
    
    
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
        self.ownContact = [DSContactEntity anyObjectMatching:@"associatedBlockchainIdentityUniqueId == %@",uint256_data(self.registrationTransitionHash)];
    }];
    
    //    [self updateCreditBalance];
    
    
    return self;
}

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index  withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> *)usernameDictionary inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [self initWithType:type atIndex:index withFundingTransaction:transaction inWallet:wallet inContext:managedObjectContext])) return nil;
    
    if (usernameDictionary) {
        NSMutableDictionary * usernameStatuses = [NSMutableDictionary dictionary];
        NSMutableDictionary * usernameSalts = [NSMutableDictionary dictionary];
        for (NSString * username in usernameDictionary) {
            NSDictionary * subDictionary = usernameDictionary[username];
            NSNumber * status = [subDictionary objectForKey:BLOCKCHAIN_USERNAME_STATUS];
            [usernameStatuses setObject:status forKey:username];
            NSData * salt = [subDictionary objectForKey:BLOCKCHAIN_USERNAME_SALT];
            if (salt) {
                [usernameSalts setObject:salt forKey:username];
            }
        }
        self.usernameStatuses = usernameStatuses;
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

// MARK: - Local Registration and Generation

-(void)generateBlockchainIdentityExtendedPublicKeys:(void (^ _Nullable)(BOOL registered))completion {
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
    self.registrationCreditFundingTransaction = fundingTransaction;
    self.lockedOutpoint = fundingTransaction.lockedOutpoint;
    [self registerInWalletForBlockchainIdentityUniqueId:fundingTransaction.creditBurnIdentityIdentifier];
}

-(void)registerInWalletForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId {
    self.uniqueID = blockchainIdentityUniqueId;
    [self registerInWallet];
}

-(void)registerInWallet {
    [self.wallet registerBlockchainIdentity:self];
    [self saveInitial];
}

// MARK: - Setters

-(void)setType:(DSBlockchainIdentityType)type {
    if (self.type == DSBlockchainIdentityType_Unknown || !self.registered) {
        _type = type;
    } else {
        DSDLog(@"Unable to switch types once set");
    }
}

// MARK: - Read Only Property Helpers

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
////            DSTransition *transition = [e transitionForChain:self.wallet.chain];
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
//    //        DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction = [[DSBlockchainIdentityTopupTransition alloc] initWithBlockchainIdentityTopupTransactionVersion:1 registrationTransactionHash:self.registrationTransitionHash onChain:self.wallet.chain];
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
//        DSBlockchainIdentityUpdateTransition * blockchainIdentityResetTransaction = [[DSBlockchainIdentityUpdateTransition alloc] initWithBlockchainIdentityResetTransactionVersion:1 registrationTransactionHash:self.registrationTransitionHash previousBlockchainIdentityTransactionHash:self.lastTransitionHash replacementPublicKeyHash:[privateKey.publicKeyData hash160] creditFee:1000 onChain:self.wallet.chain];
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

-(uint32_t)activeKeys {
    //todo
    return self.keysCreated;
}

-(uint32_t)indexOfKey:(DSKey*)key {
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:DSDerivationPathSigningAlgorith_ECDSA];
    NSUInteger index = [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:key.hash160] addressFromHash160DataForChain:self.wallet.chain]];
    if (index == NSNotFound) {
        derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
        index = [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:key.hash160] addressFromHash160DataForChain:self.wallet.chain]];
    }
    return (uint32_t)index;
}

-(DSAuthenticationKeysDerivationPath*)derivationPathForType:(DSDerivationPathSigningAlgorith)type {
    if (type == DSDerivationPathSigningAlgorith_ECDSA) {
        return [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:self.wallet];
    } else if (type == DSDerivationPathSigningAlgorith_BLS) {
        return [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
    }
    return nil;
}

-(DSKey*)privateKeyAtIndex:(uint32_t)index ofType:(DSDerivationPathSigningAlgorith)type forSeed:(NSData*)seed {
    
    const NSUInteger indexes[] = {_index,index};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    return [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
}

-(DSKey*)publicKeyAtIndex:(uint32_t)index ofType:(DSDerivationPathSigningAlgorith)type {
    
    const NSUInteger indexes[] = {_index,index};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    return [derivationPath publicKeyAtIndexPath:indexPath onChain:self.wallet.chain];
}

-(DSKey*)createNewKeyOfType:(DSDerivationPathSigningAlgorith)type returnIndex:(uint32_t *)rIndex {
    const NSUInteger indexes[] = {_index,self.keysCreated};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    DSKey * key = [derivationPath publicKeyAtIndexPath:indexPath onChain:self.wallet.chain];
    self.keysCreated++;
    [self saveNewKey:key atPath:indexPath fromDerivationPath:derivationPath];
    return key;
}

-(void)addKey:(DSKey*)key atIndex:(uint32_t)index ofType:(DSDerivationPathSigningAlgorith)type save:(BOOL)save {
    const NSUInteger indexes[] = {_index,index};
    NSIndexPath * indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    [self addKey:key atIndexPath:indexPath ofType:type save:save];
}

-(void)addKey:(DSKey*)key atIndexPath:(NSIndexPath*)indexPath ofType:(DSDerivationPathSigningAlgorith)type save:(BOOL)save {
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    DSKey * keyToCheck = [derivationPath publicKeyAtIndexPath:indexPath onChain:self.wallet.chain];
    if ([keyToCheck.publicKeyData isEqualToData:key.publicKeyData]) {
        uint32_t index = (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1];
        self.keysCreated = MAX(self.keysCreated,index + 1);
        if (save) {
            [self saveNewKey:key atPath:indexPath fromDerivationPath:derivationPath];
        }
    }
}

-(void)registerKeyIsActive:(BOOL)active atIndexPath:(NSIndexPath*)indexPath ofType:(DSDerivationPathSigningAlgorith)type {
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathForType:type];
    
    DSKey * key = [derivationPath publicKeyAtIndexPath:indexPath onChain:self.wallet.chain];
    uint32_t index = (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1];
    self.keysCreated = MAX(self.keysCreated,index + 1);
    [self.usedKeys setObject:key forKey:@(index)];
}

// MARK: From Remote/Network

-(void)addKeyFromKeyDictionary:(NSDictionary*)dictionary {
    NSString * dataString = dictionary[@"data"];
    NSNumber * keyId = dictionary[@"id"];
    NSNumber * isEnabled = dictionary[@"isEnabled"];
    NSNumber * type = dictionary[@"type"];
    if (dataString && keyId && isEnabled && type) {
        DSKey * rKey = nil;
        NSData * data = [dataString base64ToData];
        if ([type intValue] == DSKeyType_BLS) {
            rKey = [DSBLSKey blsKeyWithPublicKey:data.UInt384 onChain:self.wallet.chain];
        } else if ([type intValue] == DSKeyType_ECDSA) {
            rKey = [DSECDSAKey keyWithPublicKey:data];
        }
        [self addKey:rKey atIndex:[keyId intValue] - 1 ofType:[type intValue] save:TRUE];
    }
}

// MARK: - Funding

-(NSString*)registrationFundingAddress {
    if (self.registrationCreditFundingTransaction) {
        return [uint160_data(self.registrationCreditFundingTransaction.creditBurnPublicKeyHash) addressFromHash160DataForChain:self.wallet.chain];
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

-(NSString*)registrationStatusString {
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

// MARK: Transition

-(void)registrationTransitionSignedByPrivateKey:(DSKey*)privateKey atIndex:(uint32_t)index registeringPublicKeys:(NSDictionary <NSNumber*,DSKey*>*)publicKeys completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction))completion {
    NSAssert(self.type != 0, @"Identity type should be defined");
    DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition = [[DSBlockchainIdentityRegistrationTransition alloc] initWithVersion:1 forIdentityType:self.type registeringPublicKeys:publicKeys usingLockedOutpoint:self.lockedOutpoint onChain:self.wallet.chain];
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
        
        DSKey * publicKey = [self createNewKeyOfType:DSDerivationPathSigningAlgorith_ECDSA returnIndex:&index];
        
        [self registrationTransitionSignedByPrivateKey:privateKey atIndex:index registeringPublicKeys:@{@(index):publicKey} completion:completion];
    }];
}

// MARK: Registering

-(void)createAndPublishRegistrationTransitionWithCompletion:(void (^)(NSDictionary *, NSError *))completion {
    [self registrationTransitionWithCompletion:^(DSBlockchainIdentityRegistrationTransition * _Nonnull blockchainIdentityRegistrationTransition) {
        if (blockchainIdentityRegistrationTransition) {
            [self.DAPIClient publishTransition:blockchainIdentityRegistrationTransition success:^(NSDictionary * _Nonnull successDictionary) {
                [self monitorForBlockchainIdentityWithRetryCount:5 completion:^(BOOL success) {
                    
                }];
                completion(successDictionary,nil);
            } failure:^(NSError * _Nonnull error) {
                if (error) {
                    [self monitorForBlockchainIdentityWithRetryCount:1 completion:^(BOOL success) {
                        
                    }];
                }
                completion(nil,error);
            }];
        } else {
            NSError * error = [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                                                                           DSLocalizedString(@"Unable to create registration transition", nil)}];
            completion(nil,error);
        }
    }];
    
}

// MARK: Retrieval

-(void)retrieveIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success))completion {
    [self monitorForBlockchainIdentityWithRetryCount:1 completion:completion];
}

// MARK: - Platform Helpers

-(DPDocumentFactory*)dashpayDocumentFactory {
    if (!_dashpayDocumentFactory) {
        DPContract * contract = [DSDashPlatform sharedInstanceForChain:self.wallet.chain].dashPayContract;
        NSAssert(contract,@"Contract must be defined");
        self.dashpayDocumentFactory = [[DPDocumentFactory alloc] initWithBlockchainIdentity:self contract:contract onChain:self.wallet.chain];
    }
    return _dashpayDocumentFactory;
}

-(DPDocumentFactory*)dpnsDocumentFactory {
    if (!_dpnsDocumentFactory) {
        DPContract * contract = [DSDashPlatform sharedInstanceForChain:self.wallet.chain].dpnsContract;
        NSAssert(contract,@"Contract must be defined");
        self.dpnsDocumentFactory = [[DPDocumentFactory alloc] initWithBlockchainIdentity:self contract:contract onChain:self.wallet.chain];
    }
    return _dpnsDocumentFactory;
}

-(DSDAPIClient*)DAPIClient {
    return self.wallet.chain.chainManager.DAPIClient;
}

-(DSDAPINetworkService*)DAPINetworkService {
    return self.DAPIClient.DAPINetworkService;
}

// MARK: - Signing and Encryption

-(void)signStateTransition:(DSTransition*)transition forKeyIndex:(uint32_t)keyIndex ofType:(DSDerivationPathSigningAlgorith)signingAlgorithm withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion {
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

-(BOOL)verifySignature:(NSData*)signature forKeyIndex:(uint32_t)keyIndex ofType:(DSDerivationPathSigningAlgorith)signingAlgorithm forMessageDigest:(UInt256)messageDigest {
    DSKey * publicKey = [self publicKeyAtIndex:keyIndex ofType:signingAlgorithm];
    return [publicKey verify:messageDigest signatureData:signature];
}

-(void)encryptData:(NSData*)data forRecipientKey:(UInt384)recipientPublicKey withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(NSData* encryptedData))completion {
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"" forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData* _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self.wallet];
        DSBLSKey * privateKey = (DSBLSKey *)[derivationPath privateKeyAtIndex:self.index fromSeed:seed];
        DSBLSKey * publicRecipientKey = [DSBLSKey blsKeyWithPublicKey:recipientPublicKey onChain:self.wallet.chain];
        NSData * encryptedData = [data encryptWithSecretKey:privateKey forPeerWithPublicKey:publicRecipientKey];
        completion(encryptedData);
    }];
}

// MARK: - Contracts

-(void)fetchAndUpdateContract:(DPContract*)contract {
    __weak typeof(contract) weakContract = contract;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        
        if (contract.contractState == DPContractState_Unknown) {
            [self.DAPINetworkService getIdentityByName:@"dashpay" inDomain:@"" success:^(NSDictionary * _Nonnull blockchainIdentity) {
                NSLog(@"okay");
            } failure:^(NSError * _Nonnull error) {
                __strong typeof(weakContract) strongContract = weakContract;
                if (!strongContract) {
                    return;
                }
                strongContract.contractState = DPContractState_NotRegistered;
            }];
        } else if (contract.contractState == DPContractState_NotRegistered) {
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
                        [strongSelf monitorForContract:strongContract withRetryCount:2 completion:^(BOOL success) {
                            
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
                        [strongSelf monitorForContract:strongContract withRetryCount:2 completion:^(BOOL success) {
                            
                        }];
                    }];
                }
            }];
            
        } else if (contract.contractState == DPContractState_Registered || contract.contractState == DPContractState_Registering) {
            [self.DAPINetworkService fetchContractForId:contract.base58ContractID success:^(NSDictionary * _Nonnull contract) {
                __strong typeof(weakContract) strongContract = weakContract;
                if (!weakContract) {
                    return;
                }
                if (strongContract.contractState == DPContractState_Registered) {
                    
                }
            } failure:^(NSError * _Nonnull error) {
                NSString * debugDescription1 = [error.userInfo objectForKey:@"NSDebugDescription"];
                NSError *jsonError;
                NSData *objectData = [debugDescription1 dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary * debugDescription = [NSJSONSerialization JSONObjectWithData:objectData options:0 error:&jsonError];
                //NSDictionary * debugDescription =
                NSString * errorMessage = [debugDescription objectForKey:@"grpc_message"];
                if ([errorMessage isEqualToString:@"Invalid argument: Contract not found"]) {
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
    [self.usernameStatuses setObject:@(DSBlockchainIdentityUsernameStatus_Initial) forKey:username];
    if (save) {
        [self saveNewUsername:username status:DSBlockchainIdentityUsernameStatus_Initial];
    }
    if (self.registered) {
        [self registerUsernames];
    }
}

-(DSBlockchainIdentityUsernameStatus)statusOfUsername:(NSString*)username {
    return [[self.usernameStatuses objectForKey:username] unsignedIntegerValue];
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
        DSBlockchainIdentityUsernameStatus status = [self.usernameStatuses[username] unsignedIntegerValue];
        if (status == usernameStatus) {
            [unregisteredUsernames addObject:username];
        }
    }
    return [unregisteredUsernames copy];
}

-(NSArray<NSString*>*)preorderedUsernames {
    NSMutableArray * unregisteredUsernames = [NSMutableArray array];
    for (NSString * username in self.usernameStatuses) {
        DSBlockchainIdentityUsernameStatus status = [self.usernameStatuses[username] unsignedIntegerValue];
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
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:usernamePreorderDocuments withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID onChain:self.wallet.chain];
    return transition;
}

-(DSDocumentTransition*)domainTransitionForUnregisteredUsernames:(NSArray*)unregisteredUsernames {
    NSArray * usernamePreorderDocuments = [self domainDocumentsForUnregisteredUsernames:unregisteredUsernames];
    if (![usernamePreorderDocuments count]) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:usernamePreorderDocuments withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID onChain:self.wallet.chain];
    return transition;
}

// MARK: Registering

-(void)registerUsernames {
    [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Initial];
}

-(void)registerUsernamesAtStage:(DSBlockchainIdentityUsernameStatus)blockchainIdentityUsernameStatus {
    DSDLog(@"registerUsernamesAtStage %lu",(unsigned long)blockchainIdentityUsernameStatus);
    switch (blockchainIdentityUsernameStatus) {
        case DSBlockchainIdentityUsernameStatus_Initial:
        {
            NSArray * usernames = [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_Initial];
            if (usernames.count) {
                [self registerPreorderedSaltedDomainHashesForUsernames:usernames completion:^(BOOL success) {
                    if (success) {
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending];
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending:
        {
            NSArray * usernames = [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending];
            NSDictionary<NSString*,NSData *>* saltedDomainHashes = [self saltedDomainHashesForUsernames:usernames];
            if (saltedDomainHashes.count) {
                [self monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:2 completion:^(BOOL success) {
                    if (success) {
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Preordered];
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_Preordered];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_Preordered:
        {
            NSArray * usernames = [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_Preordered];
            if (usernames.count) {
                [self registerUsernameDomainsForUsernames:usernames completion:^(BOOL success) {
                    if (success) {
                        [self saveUsernames:usernames toStatus:DSBlockchainIdentityUsernameStatus_RegistrationPending];
                        [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_RegistrationPending];
                    }
                }];
            } else {
                [self registerUsernamesAtStage:DSBlockchainIdentityUsernameStatus_RegistrationPending];
            }
            break;
        }
        case DSBlockchainIdentityUsernameStatus_RegistrationPending:
        {
            NSArray * usernames = [self usernamesWithStatus:DSBlockchainIdentityUsernameStatus_RegistrationPending];
            if (usernames.count) {
                [self monitorForDPNSUsernames:usernames withRetryCount:2 completion:^(BOOL success) {
                    if (success) {
                        //Done;
                    }
                }];
            }
            break;
        }
        default:
            break;
    }
}

//Preorder stage
-(void)registerPreorderedSaltedDomainHashesForUsernames:(NSArray*)usernames completion:(void (^ _Nullable)(BOOL success))completion {
    DSDocumentTransition * transition = [self preorderTransitionForUnregisteredUsernames:usernames];
    [self signStateTransition:transition withPrompt:@"Register Usernames?" completion:^(BOOL success) {
        if (success) {
            [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (NSString * string in usernames) {
                        [self.usernameStatuses setObject:@(DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending) forKey:string];
                    }
                    [self saveUsernames:usernames toStatus:DSBlockchainIdentityUsernameStatus_PreorderRegistrationPending];
                    if (completion) {
                        completion(YES);
                    }
                });
                
            } failure:^(NSError * _Nonnull error) {
                DSDLog(@"%@", error);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(NO);
                    }
                });
            }];
        }
    }];
}

-(void)registerUsernameDomainsForUsernames:(NSArray*)usernames completion:(void (^ _Nullable)(BOOL success))completion {
    DSDocumentTransition * transition = [self domainTransitionForUnregisteredUsernames:usernames];
    [self signStateTransition:transition withPrompt:@"Register Usernames?" completion:^(BOOL success) {
        if (success) {
            [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (NSString * string in usernames) {
                        [self.usernameStatuses setObject:@(DSBlockchainIdentityUsernameStatus_RegistrationPending) forKey:string];
                    }
                    if (completion) {
                        completion(YES);
                    }
                });
                
            } failure:^(NSError * _Nonnull error) {
                DSDLog(@"%@", error);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(NO);
                    }
                });
            }];
        }
    }];
}

// MARK: Retrieval

- (void)fetchUsernamesWithCompletion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDPNSDocumentsForIdentityWithUserId:self.uniqueIdString success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (![documents count]) {
            if (completion) {
                completion(YES);
            }
            return;
        }
        //todo verify return is true
        for (NSDictionary * nameDictionary in documents) {
            NSString * username = nameDictionary[@"label"];
            if (username) {
                [self.usernameStatuses setObject:@(DSBlockchainIdentityUsernameStatus_Confirmed) forKey:username];
                [self saveNewUsername:username status:DSBlockchainIdentityUsernameStatus_Confirmed];
            }
        }
//        [context performBlockAndWait:^{
//            __strong typeof(weakSelf) strongSelf = weakSelf;
//            if (!strongSelf) {
//                return;
//            }
//            [DSContactEntity setContext:context];
//            [DSChainEntity setContext:context];
//            DSContactEntity * contact = [DSContactEntity anyObjectMatchingInContext:context withPredicate:@"associatedBlockchainIdentityUniqueId == %@", uint256_data(blockchainIdentityUniqueId)];
//            if (!contact || [[contactDictionary objectForKey:@"$rev"] intValue] != contact.documentRevision) {
//
//                if (!contact) {
//                    contact = [DSContactEntity managedObjectInContext:context];
//                }
//
//                contact.documentRevision = [[contactDictionary objectForKey:@"$rev"] intValue];
//                contact.avatarPath = [contactDictionary objectForKey:@"avatarUrl"];
//                contact.publicMessage = [contactDictionary objectForKey:@"about"];
//                contact.associatedBlockchainIdentityUniqueId = uint256_data(blockchainIdentityUniqueId);
//                contact.chain = strongSelf.wallet.chain.chainEntity;
//                if (uint256_eq(blockchainIdentityUniqueId, strongSelf.uniqueID) && !strongSelf.ownContact) {
//                    NSAssert(strongSelf.blockchainIdentityEntity, @"blockchainIdentityEntity must exist");
//                    contact.associatedBlockchainIdentity = strongSelf.blockchainIdentityEntity;
//                    contact.associatedBlockchainIdentityUniqueId = uint256_data(strongSelf.uniqueID);
//                    contact.username = strongSelf.currentUsername;
//                    self.ownContact = contact;
//                    if (saveReturnedProfile) {
//                        [DSContactEntity saveContext];
//                    }
//                } else if ([strongSelf.wallet blockchainIdentityForUniqueId:blockchainIdentityUniqueId]) {
//                    //this means we are fetching a contact for another blockchain user on the device
//                    DSBlockchainIdentity * blockchainIdentity = [strongSelf.wallet blockchainIdentityForUniqueId:blockchainIdentityUniqueId];
//                    NSAssert(blockchainIdentity.blockchainIdentityEntity, @"blockchainIdentityEntity must exist");
//                    contact.associatedBlockchainIdentity = blockchainIdentity.blockchainIdentityEntity;
//                    contact.associatedBlockchainIdentityUniqueId = uint256_data(blockchainIdentity.uniqueID);
//                    contact.username = blockchainIdentity.currentUsername;
//                    blockchainIdentity.ownContact = contact;
//                    if (saveReturnedProfile) {
//                        [DSContactEntity saveContext];
//                    }
//                }
//            }
//
//            if (completion) {
//                completion(contact);
//            }
//        }];
        
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            completion(nil);
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

-(void)monitorForBlockchainIdentityWithRetryCount:(uint32_t)retryCount completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getIdentityById:self.uniqueIdString success:^(NSDictionary * _Nonnull profileDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (profileDictionary[@"credits"]) {
            uint64_t creditBalance = (uint64_t)[profileDictionary[@"credits"] longLongValue];
            strongSelf.creditBalance = creditBalance;
        }
        if (!strongSelf.type) {
            strongSelf.type = profileDictionary[@"type"]?[((NSNumber*)profileDictionary[@"type"]) intValue]:DSBlockchainIdentityType_Unknown;
        }
        if (profileDictionary[@"publicKeys"]) {
            for (NSDictionary * dictionary in profileDictionary[@"publicKeys"]) {
                [self addKeyFromKeyDictionary:dictionary];
            }
        }
        strongSelf.registrationStatus = DSBlockchainIdentityRegistrationStatus_Registered;
        [self save];
        
        if (completion) {
            completion(TRUE);
        }
    } failure:^(NSError * _Nonnull error) {
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self monitorForBlockchainIdentityWithRetryCount:retryCount - 1 completion:completion];
            });
        } else {
            completion(FALSE);
        }
    }];
}

-(void)monitorForDPNSUsernames:(NSArray*)usernames withRetryCount:(uint32_t)retryCount completion:(void (^)(BOOL))completion {
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
                        [strongSelf.usernameStatuses setObject:@(DSBlockchainIdentityUsernameStatus_Confirmed) forKey:username];
                        [strongSelf saveUsername:username status:DSBlockchainIdentityUsernameStatus_Confirmed salt:nil commitSave:YES];
                        [usernamesLeft removeObject:username];
                    }
                }
            }
            if ([usernamesLeft count] && retryCount > 0) {
                [strongSelf monitorForDPNSUsernames:usernamesLeft withRetryCount:retryCount - 1 completion:completion];
            } else if ([usernamesLeft count]) {
                completion(FALSE);
            } else {
                completion(TRUE);
            }
        } else if (retryCount > 0) {
            [strongSelf monitorForDPNSUsernames:usernames withRetryCount:retryCount - 1 completion:completion];
        } else {
            completion(FALSE);
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
            completion(FALSE);
        }
    }];
}

-(void)monitorForDPNSPreorderSaltedDomainHashes:(NSDictionary*)saltedDomainHashes withRetryCount:(uint32_t)retryCount completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDPNSDocumentsForPreorderSaltedDomainHashes:[saltedDomainHashes allValues] success:^(id _Nonnull preorderDocumentArray) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if ([preorderDocumentArray isKindOfClass:[NSArray class]]) {
            NSMutableArray * usernamesLeft = [[saltedDomainHashes allKeys] mutableCopy];
            for (NSString * username in saltedDomainHashes) {
                NSData * saltedDomainHashData = saltedDomainHashes[username];
                NSString * saltedDomainHashString = [saltedDomainHashData hexString];
                for (NSDictionary * preorderDocument in preorderDocumentArray) {
                    if ([[preorderDocument objectForKey:@"saltedDomainHash"] isEqualToString:saltedDomainHashString]) {
                        [strongSelf.usernameStatuses setObject:@(DSBlockchainIdentityUsernameStatus_Preordered) forKey:username];
                        [strongSelf saveUsername:username status:DSBlockchainIdentityUsernameStatus_Preordered salt:nil commitSave:YES];
                        [usernamesLeft removeObject:username];
                    }
                }
            }
            if ([usernamesLeft count] && retryCount > 0) {
                NSDictionary * saltedDomainHashesLeft = [saltedDomainHashes dictionaryWithValuesForKeys:usernamesLeft];
                [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashesLeft withRetryCount:retryCount - 1 completion:completion];
            } else if ([usernamesLeft count]) {
                completion(FALSE);
            } else {
                completion(TRUE);
            }
        } else if (retryCount > 0) {
            [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:retryCount - 1 completion:completion];
        } else {
            completion(FALSE);
        }
    } failure:^(NSError * _Nonnull error) {
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes withRetryCount:retryCount - 1 completion:completion];
            });
        } else {
            completion(FALSE);
        }
    }];
}

-(void)monitorForContract:(DPContract*)contract withRetryCount:(uint32_t)retryCount completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    NSParameterAssert(contract);
    if (!contract) return;
    [self.DAPINetworkService fetchContractForId:contract.base58ContractID success:^(id _Nonnull contractDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if ([contractDictionary isKindOfClass:[NSDictionary class]] && [contractDictionary[@"contractId"] isEqualToString:contract.base58ContractID]) {
            contract.contractState = DPContractState_Registered;
            completion(TRUE);
        } else if (retryCount > 0) {
            [strongSelf monitorForContract:contract withRetryCount:retryCount - 1 completion:completion];
        } else {
            completion(FALSE);
        }
    } failure:^(NSError * _Nonnull error) {
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                [strongSelf monitorForContract:contract withRetryCount:retryCount - 1 completion:completion];
            });
        } else {
            completion(FALSE);
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

- (void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getIdentityByName:potentialContact.username inDomain:[self topDomainName] success:^(NSDictionary *_Nonnull blockchainIdentityDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSString * base58String = nil;
        if (!blockchainIdentityDictionary || !(base58String = blockchainIdentityDictionary[@"id"])) {
            if (completion) {
                completion(NO);
            }
            return;
        }
        
        UInt256 blockchainIdentityContactUniqueId = base58String.base58ToData.reverse.UInt256;
        NSArray * publicKeys = blockchainIdentityDictionary[@"publicKeys"];
        __unused UInt384 blockchainIdentityContactEncryptionPublicKey = ((NSString*)blockchainIdentityDictionary[@"publicKey"]).hexToData.reverse.UInt384;
        NSAssert(!uint256_is_zero(blockchainIdentityContactUniqueId), @"blockchainIdentityContactUniqueId should not be null");
        //NSAssert(!uint384_is_zero(blockchainIdentityContactEncryptionPublicKey), @"blockchainIdentityContactEncryptionPublicKey should not be null");
        [potentialContact setAssociatedBlockchainIdentityUniqueId:blockchainIdentityContactUniqueId];
        //[potentialContact setContactEncryptionPublicKey:blockchainIdentityContactEncryptionPublicKey];
        DSAccount * account = [self.wallet accountWithNumber:0];
        DSPotentialFriendship * potentialFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:potentialContact sourceBlockchainIdentity:self account:account];
        
        [potentialFriendship createDerivationPath];
        
        [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship completion:completion];
    } failure:^(NSError *_Nonnull error) {
        DSDLog(@"%@", error);
        
        if (completion) {
            completion(NO);
        }
    }];
}

- (void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialFriendship*)potentialFriendship completion:(void (^)(BOOL))completion {
    if (uint256_is_zero(potentialFriendship.destinationContact.associatedBlockchainIdentityUniqueId)) {
        [self sendNewFriendRequestToPotentialContact:potentialFriendship.destinationContact completion:completion];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.wallet.chain].dashPayContract;
    
    [self.DAPIClient sendDocument:potentialFriendship.contactRequestDocument forIdentity:self contract:contract completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        BOOL success = error == nil;
        
        if (success) {
            
            [self fetchProfileForBlockchainIdentityUniqueId:potentialFriendship.destinationContact.associatedBlockchainIdentityUniqueId saveReturnedProfile:NO context:self.managedObjectContext completion:^(DSContactEntity *contactEntity) {
                if (!contactEntity) {
                    if (completion) {
                        completion(NO);
                    }
                    return;
                }
                DSFriendRequestEntity * friendRequest = [potentialFriendship outgoingFriendRequestForContactEntity:contactEntity];
                [strongSelf.ownContact addOutgoingRequestsObject:friendRequest];
                [potentialFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequest];
                if (completion) {
                    completion(success);
                }
            }];
            
        }
        
        
    }];
}

-(void)acceptFriendRequest:(DSFriendRequestEntity*)friendRequest completion:(void (^)(BOOL))completion {
    DSAccount * account = [self.wallet accountWithNumber:0];
    DSPotentialContact *contact = [[DSPotentialContact alloc] initWithUsername:friendRequest.sourceContact.username avatarPath:friendRequest.sourceContact.avatarPath
                                                                 publicMessage:friendRequest.sourceContact.publicMessage];
    [contact setAssociatedBlockchainIdentityUniqueId:friendRequest.sourceContact.associatedBlockchainIdentityUniqueId.UInt256];
    DSPotentialFriendship *potentialFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:contact
                                                                                  sourceBlockchainIdentity:self
                                                                                                   account:account];
    [potentialFriendship createDerivationPath];
    
    [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship completion:completion];
    
}

-(DPDocument*)ownContactProfileDocument {
    if (self.ownContact) {
        DSStringValueDictionary * dataDictionary = @{
            @"publicMessage": self.ownContact.publicMessage,
            @"avatarUrl": self.ownContact.avatarPath,
            @"displayName": self.ownContact.displayName,
            @"$rev": @(self.ownContact.documentRevision + 1)
        };
        NSError * error = nil;
        DPDocument * document = [self.dashpayDocumentFactory documentOnTable:@"profile" withDataDictionary:dataDictionary error:&error];
        return document;
    } else {
        return nil;
    }
}

-(DSDocumentTransition*)profileDocumentTransition {
    DPDocument * profileDocument = [self ownContactProfileDocument];
    if (!profileDocument) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:@[profileDocument] withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueID onChain:self.wallet.chain];
    return transition;
}

- (void)createOrUpdateProfileWithAboutMeString:(NSString*)aboutme avatarURLString:(NSString *)avatarURLString completion:(void (^)(BOOL success))completion {
    __weak typeof(self) weakSelf = self;
    DSDocumentTransition * transition = [self profileDocumentTransition];
    if (!transition) return;
    [self signStateTransition:transition withPrompt:@"Update profile?" completion:^(BOOL success) {
        if (success) {
            [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                            return;
                        }
                
                [self.DAPINetworkService getIdentityById:uint256_reverse_base58(self.registrationTransitionHash) success:^(NSDictionary *_Nonnull blockchainIdentity) {
                            __strong typeof(weakSelf) strongSelf = weakSelf;
                            if (!strongSelf) {
                                return;
                            }
            
                            if (completion) {
                                completion(!!blockchainIdentity);
                            }
                        } failure:^(NSError * _Nonnull error) {
                            DSDLog(@"%@",error);
                            if (completion) {
                                completion(NO);
                            }
                        }];
            } failure:^(NSError * _Nonnull error) {
                if (completion) {
                    completion(NO);
                }
            }];

        }
    }];
}

// MARK: Fetching

- (void)fetchProfile:(void (^)(BOOL))completion {
    [self fetchProfileForBlockchainIdentityUniqueId:self.uniqueID saveReturnedProfile:TRUE context:self.managedObjectContext completion:^(DSContactEntity *contactEntity) {
        if (completion) {
            if (contactEntity) {
                completion(YES);
            } else {
                completion(NO);
            }
        }
    }];
}

- (void)fetchProfileForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId saveReturnedProfile:(BOOL)saveReturnedProfile context:(NSManagedObjectContext*)context completion:(void (^)(DSContactEntity* contactEntity))completion {
    return;
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDashpayProfileForUserId:uint256_reverse_base58(blockchainIdentityUniqueId) success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (![documents count]) {
            if (completion) {
                completion(nil);
            }
            return;
        }
        //todo
        
        NSDictionary * contactDictionary = [documents firstObject];
        [context performBlockAndWait:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [DSContactEntity setContext:context];
            [DSChainEntity setContext:context];
            DSContactEntity * contact = [DSContactEntity anyObjectMatchingInContext:context withPredicate:@"associatedBlockchainIdentityUniqueId == %@", uint256_data(blockchainIdentityUniqueId)];
            if (!contact || [[contactDictionary objectForKey:@"$rev"] intValue] != contact.documentRevision) {
                
                if (!contact) {
                    contact = [DSContactEntity managedObjectInContext:context];
                }
                
                contact.documentRevision = [[contactDictionary objectForKey:@"$rev"] intValue];
                contact.avatarPath = [contactDictionary objectForKey:@"avatarUrl"];
                contact.publicMessage = [contactDictionary objectForKey:@"about"];
                contact.associatedBlockchainIdentityUniqueId = uint256_data(blockchainIdentityUniqueId);
                contact.chain = strongSelf.wallet.chain.chainEntity;
                if (uint256_eq(blockchainIdentityUniqueId, strongSelf.uniqueID) && !strongSelf.ownContact) {
                    NSAssert(strongSelf.blockchainIdentityEntity, @"blockchainIdentityEntity must exist");
                    contact.associatedBlockchainIdentity = strongSelf.blockchainIdentityEntity;
                    contact.associatedBlockchainIdentityUniqueId = uint256_data(strongSelf.uniqueID);
                    contact.username = strongSelf.currentUsername;
                    self.ownContact = contact;
                    if (saveReturnedProfile) {
                        [DSContactEntity saveContext];
                    }
                } else if ([strongSelf.wallet blockchainIdentityForUniqueId:blockchainIdentityUniqueId]) {
                    //this means we are fetching a contact for another blockchain user on the device
                    DSBlockchainIdentity * blockchainIdentity = [strongSelf.wallet blockchainIdentityForUniqueId:blockchainIdentityUniqueId];
                    NSAssert(blockchainIdentity.blockchainIdentityEntity, @"blockchainIdentityEntity must exist");
                    contact.associatedBlockchainIdentity = blockchainIdentity.blockchainIdentityEntity;
                    contact.associatedBlockchainIdentityUniqueId = uint256_data(blockchainIdentity.uniqueID);
                    contact.username = blockchainIdentity.currentUsername;
                    blockchainIdentity.ownContact = contact;
                    if (saveReturnedProfile) {
                        [DSContactEntity saveContext];
                    }
                }
            }
            
            if (completion) {
                completion(contact);
            }
        }];
        
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            completion(nil);
        }
    }];
}

- (void)fetchIncomingContactRequests:(void (^)(BOOL success))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDashpayIncomingContactRequestsForUserId:self.ownContact.associatedBlockchainIdentityUniqueId.reverse.base58String since:0 success:^(NSArray<NSDictionary *> * _Nonnull documents) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf handleContactRequestObjects:documents context:strongSelf.managedObjectContext completion:^(BOOL success) {
            if (completion) {
                completion(YES);
            }
        }];
    } failure:^(NSError * _Nonnull error) {
                if (completion) {
            completion(NO);
        }
    }];
}

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getDashpayOutgoingContactRequestsForUserId:self.ownContact.associatedBlockchainIdentityUniqueId.reverse.base58String since:0 success:^(NSArray<NSDictionary *> * _Nonnull documents) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf handleContactRequestObjects:documents context:strongSelf.managedObjectContext completion:^(BOOL success) {
            if (completion) {
                completion(YES);
            }
        }];
        
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            completion(NO);
        }
    }];
}

// MARK: Response Processing

- (void)handleContactRequestObjects:(NSArray<NSDictionary *> *)rawContactRequests context:(NSManagedObjectContext *)context completion:(void (^)(BOOL success))completion {
    NSMutableDictionary <NSData *,NSData *> *incomingNewRequests = [NSMutableDictionary dictionary];
    NSMutableDictionary <NSData *,NSData *> *outgoingNewRequests = [NSMutableDictionary dictionary];
    for (NSDictionary *rawContact in rawContactRequests) {
        NSDictionary * metaData = [rawContact objectForKey:@"$meta"];
        NSString *recipientString = rawContact[@"toUserId"];
        UInt256 recipientRegistrationHash = [recipientString hexToData].reverse.UInt256;
        NSString *senderString = metaData?metaData[@"userId"]:nil;
        UInt256 senderRegistrationHash = [senderString hexToData].reverse.UInt256;
        NSString *extendedPublicKeyString = rawContact[@"encryptedPublicKey"];
        NSData *extendedPublicKey = [[NSData alloc] initWithBase64EncodedString:extendedPublicKeyString options:0];
        if (uint256_eq(recipientRegistrationHash, self.ownContact.associatedBlockchainIdentityUniqueId.UInt256)) {
            //we are the recipient, this is an incoming request
            DSFriendRequestEntity * friendRequest = [DSFriendRequestEntity anyObjectMatchingInContext:context withPredicate:@"destinationContact == %@ && sourceContact.associatedBlockchainIdentityUniqueId == %@",self.ownContact,[NSData dataWithUInt256:senderRegistrationHash]];
            if (!friendRequest) {
                [incomingNewRequests setObject:extendedPublicKey forKey:[NSData dataWithUInt256:senderRegistrationHash]];
            } else if (friendRequest.sourceContact == nil) {
                
            }
        } else if (uint256_eq(senderRegistrationHash, self.ownContact.associatedBlockchainIdentityUniqueId.UInt256)) {
            BOOL isNew = ![DSFriendRequestEntity countObjectsMatchingInContext:context withPredicate:@"sourceContact == %@ && destinationContact.associatedBlockchainIdentityUniqueId == %@",self.ownContact,[NSData dataWithUInt256:recipientRegistrationHash]];
            if (isNew) {
                [outgoingNewRequests setObject:extendedPublicKey forKey:[NSData dataWithUInt256:recipientRegistrationHash]];
            }
        } else {
            NSAssert(FALSE, @"the contact request needs to be either outgoing or incoming");
        }
    }
    
    __block BOOL succeeded = YES;
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    if ([incomingNewRequests count]) {
        dispatch_group_enter(dispatchGroup);
        [self handleIncomingRequests:incomingNewRequests context:context completion:^(BOOL success) {
            if (!success) {
                succeeded = NO;
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
    if ([outgoingNewRequests count]) {
        dispatch_group_enter(dispatchGroup);
        [self handleOutgoingRequests:outgoingNewRequests context:context completion:^(BOOL success) {
            if (!success) {
                succeeded = NO;
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        if (completion) {
            completion(succeeded);
        }
    });
}

-(void)addIncomingRequestFromContact:(DSContactEntity*)contactEntity
                forExtendedPublicKey:(NSData*)extendedPublicKey
                             context:(NSManagedObjectContext *)context {
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObjectInContext:context];
    friendRequestEntity.sourceContact = contactEntity;
    friendRequestEntity.destinationContact = self.ownContact;
    
    DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity managedObjectInContext:context];
    derivationPathEntity.chain = self.wallet.chain.chainEntity;
    
    friendRequestEntity.derivationPath = derivationPathEntity;
    
    DSAccount * account = [self.wallet accountWithNumber:0];
    
    DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:account.accountNumber onChain:self.wallet.chain];
    
    derivationPathEntity.account = accountEntity;
    
    friendRequestEntity.account = accountEntity;
    
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    
    DSIncomingFundsDerivationPath * derivationPath = [DSIncomingFundsDerivationPath externalDerivationPathWithExtendedPublicKey:extendedPublicKey withDestinationBlockchainIdentityUniqueId:self.ownContact.associatedBlockchainIdentityUniqueId.UInt256 sourceBlockchainIdentityUniqueId:contactEntity.associatedBlockchainIdentityUniqueId.UInt256 onChain:self.wallet.chain];
    
    derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
    
    [derivationPath storeExternalDerivationPathExtendedPublicKeyToKeyChain];
    
    //incoming request uses an outgoing derivation path
    [account addOutgoingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
    
    [self.ownContact addIncomingRequestsObject:friendRequestEntity];
    
    [DSContactEntity saveContext];
}

- (void)handleIncomingRequests:(NSDictionary <NSData *,NSData *>  *)incomingRequests
                       context:(NSManagedObjectContext *)context
                    completion:(void (^)(BOOL success))completion {
    [self.managedObjectContext performBlockAndWait:^{
        [DSContactEntity setContext:context];
        [DSFriendRequestEntity setContext:context];
        
        __block BOOL succeeded = YES;
        dispatch_group_t dispatchGroup = dispatch_group_create();
        
        for (NSData * blockchainIdentityRegistrationHash in incomingRequests) {
            DSContactEntity * externalContact = [DSContactEntity anyObjectMatchingInContext:context withPredicate:@"associatedBlockchainIdentityUniqueId == %@",blockchainIdentityRegistrationHash];
            if (!externalContact) {
                //no contact exists yet
                dispatch_group_enter(dispatchGroup);
                [self.DAPINetworkService getIdentityById:blockchainIdentityRegistrationHash.reverse.base58String success:^(NSDictionary *_Nonnull blockchainIdentityDictionary) {
                    NSAssert(blockchainIdentityDictionary != nil, @"Should not be nil. Otherwise dispatch_group logic will be broken");
                    if (blockchainIdentityDictionary) {
                        UInt256 contactBlockchainIdentityUniqueId = ((NSString*)blockchainIdentityDictionary[@"uniqueId"]).hexToData.reverse.UInt256;
                        [self fetchProfileForBlockchainIdentityUniqueId:contactBlockchainIdentityUniqueId saveReturnedProfile:NO context:context completion:^(DSContactEntity *contactEntity) {
                            if (contactEntity) {
                                NSString * username = blockchainIdentityDictionary[@"uname"];
                                contactEntity.username = username;
                                contactEntity.associatedBlockchainIdentityUniqueId = uint256_data(contactBlockchainIdentityUniqueId);
                                
                                [self addIncomingRequestFromContact:contactEntity
                                               forExtendedPublicKey:incomingRequests[blockchainIdentityRegistrationHash]
                                                            context:context];
                                
                            }
                            else {
                                succeeded = NO;
                            }
                            
                            dispatch_group_leave(dispatchGroup);
                        }];
                    }
                } failure:^(NSError * _Nonnull error) {
                    succeeded = NO;
                    dispatch_group_leave(dispatchGroup);
                }];
            } else {
                if (externalContact.associatedBlockchainIdentityUniqueId && [self.wallet blockchainIdentityForUniqueId:externalContact.associatedBlockchainIdentityUniqueId.UInt256]) {
                    //it's also local (aka both contacts are on this device), we should store the extended public key for the destination
                    DSBlockchainIdentity * sourceBlockchainIdentity = [self.wallet blockchainIdentityForUniqueId:externalContact.associatedBlockchainIdentityUniqueId.UInt256];
                    
                    DSAccount * account = [sourceBlockchainIdentity.wallet accountWithNumber:0];
                    
                    DSPotentialContact* contact = [[DSPotentialContact alloc] initWithContactEntity:self.ownContact];
                    
                    DSPotentialFriendship * potentialFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:contact sourceBlockchainIdentity:sourceBlockchainIdentity account:account];
                    
                    DSIncomingFundsDerivationPath * derivationPath = [potentialFriendship createDerivationPath];
                    
                    DSFriendRequestEntity * friendRequest = [potentialFriendship outgoingFriendRequestForContactEntity:self.ownContact];
                    [potentialFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequest];
                    [self.ownContact addIncomingRequestsObject:friendRequest];
                    
                    if ([[friendRequest.sourceContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",self.ownContact]] count]) {
                        [self.ownContact addFriendsObject:friendRequest.sourceContact];
                    }
                    
                    [account addIncomingDerivationPath:derivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier];
                    
                } else {
                    //the contact already existed, create the incoming friend request, add a friendship if an outgoing friend request also exists
                    [self addIncomingRequestFromContact:externalContact
                                   forExtendedPublicKey:incomingRequests[blockchainIdentityRegistrationHash]
                                                context:context];
                    
                    if ([[externalContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",self.ownContact]] count]) {
                        [self.ownContact addFriendsObject:externalContact];
                    }
                }
                
                [DSContactEntity saveContext];
            }
        }
        
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
            if (completion) {
                completion(succeeded);
            }
        });
    }];
}

- (void)handleOutgoingRequests:(NSDictionary <NSData *,NSData *>  *)outgoingRequests
                       context:(NSManagedObjectContext *)context
                    completion:(void (^)(BOOL success))completion {
    [context performBlockAndWait:^{
        [DSContactEntity setContext:context];
        [DSFriendRequestEntity setContext:context];
        
        __block BOOL succeeded = YES;
        dispatch_group_t dispatchGroup = dispatch_group_create();
        
        for (NSData * blockchainIdentityRegistrationHash in outgoingRequests) {
            DSContactEntity * destinationContact = [DSContactEntity anyObjectMatchingInContext:context withPredicate:@"associatedBlockchainIdentityUniqueId == %@",blockchainIdentityRegistrationHash];
            if (!destinationContact) {
                //no contact exists yet
                dispatch_group_enter(dispatchGroup);
                [self.DAPINetworkService getIdentityById:blockchainIdentityRegistrationHash.reverse.base58String success:^(NSDictionary *_Nonnull blockchainIdentityDictionary) {
                    NSAssert(blockchainIdentityDictionary != nil, @"Should not be nil. Otherwise dispatch_group logic will be broken");
                    if (blockchainIdentityDictionary) {
                        UInt256 contactBlockchainIdentityUniqueId = ((NSString*)blockchainIdentityDictionary[@"uniqueId"]).hexToData.reverse.UInt256;
                        [self fetchProfileForBlockchainIdentityUniqueId:contactBlockchainIdentityUniqueId saveReturnedProfile:NO context:context completion:^(DSContactEntity *destinationContactEntity) {
                            
                            if (!destinationContactEntity) {
                                succeeded = NO;
                                dispatch_group_leave(dispatchGroup);
                                return;
                            }
                            
                            NSString * username = blockchainIdentityDictionary[@"uname"];
                            
                            DSDLog(@"NEW outgoing friend request with new contact %@",username);
                            destinationContactEntity.username = username;
                            destinationContactEntity.associatedBlockchainIdentityUniqueId = uint256_data(contactBlockchainIdentityUniqueId);
                            DSAccount * account = [self.wallet accountWithNumber:0];
                            
                            DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObjectInContext:context];
                            friendRequestEntity.sourceContact = self.ownContact;
                            friendRequestEntity.destinationContact = destinationContactEntity;
                            
                            DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:0 onChain:self.wallet.chain];
                            
                            friendRequestEntity.account = accountEntity;
                            
                            [friendRequestEntity finalizeWithFriendshipIdentifier];
                            
                            [self.ownContact addOutgoingRequestsObject:friendRequestEntity];
                            
                            DSPotentialContact * contact = [[DSPotentialContact alloc] initWithContactEntity:destinationContactEntity];
                            
                            DSPotentialFriendship * realFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:contact sourceBlockchainIdentity:self account:account];
                            
                            DSIncomingFundsDerivationPath * derivationPath = [realFriendship createDerivationPath];
                            
                            [account addIncomingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
                            
                            friendRequestEntity.derivationPath = [realFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequestEntity];
                            
                            NSAssert(friendRequestEntity.derivationPath, @"derivation path must be present");
                            
                            [DSContactEntity saveContext];
                            
                            dispatch_group_leave(dispatchGroup);
                        }];
                    }
                } failure:^(NSError * _Nonnull error) {
                    succeeded = NO;
                    dispatch_group_leave(dispatchGroup);
                }];
            } else {
                //the contact already existed, meaning they had made a friend request to us before, and on another device we had accepted
                //or the contact is locally known on the device
                DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObjectInContext:context];
                DSDLog(@"NEW outgoing friend request with known contact %@",destinationContact.username);
                friendRequestEntity.sourceContact = self.ownContact;
                friendRequestEntity.destinationContact = destinationContact;
                
                DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:0 onChain:self.wallet.chain];
                
                friendRequestEntity.account = accountEntity;
                
                [friendRequestEntity finalizeWithFriendshipIdentifier];
                
                DSAccount * account = [self.wallet accountWithNumber:0];
                
                DSPotentialContact* contact = [[DSPotentialContact alloc] initWithContactEntity:destinationContact];
                
                DSPotentialFriendship * realFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:contact sourceBlockchainIdentity:self account:account];
                
                DSIncomingFundsDerivationPath * derivationPath = [realFriendship createDerivationPath];
                
                
                friendRequestEntity.derivationPath = [realFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequestEntity];
                
                NSAssert(friendRequestEntity.derivationPath, @"derivation path must be present");
                
                if (destinationContact.associatedBlockchainIdentity) { //the destination is also local
                    [account addIncomingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
                } else {
                    //todo update outgoing derivation paths to incoming derivation paths as blockchain users come in
                    [account addOutgoingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier];
                }
                
                [self.ownContact addOutgoingRequestsObject:friendRequestEntity];
                if ([[destinationContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",self.ownContact]] count]) {
                    [self.ownContact addFriendsObject:destinationContact];
                }
                
                [DSContactEntity saveContext];
            }
        }
        
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
            if (completion) {
                completion(succeeded);
            }
        });
    }];
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
        NSData * transactionHash = uint256_data(self.registrationCreditFundingTransaction.txHash);
        DSCreditFundingTransactionEntity * transactionEntity = (DSCreditFundingTransactionEntity*)[DSTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", transactionHash];
        entity.registrationFundingTransaction = transactionEntity;
        entity.chain = self.wallet.chain.chainEntity;
        for (NSString * username in self.usernameStatuses) {
            DSBlockchainIdentityUsernameEntity * usernameEntity = [DSBlockchainIdentityUsernameEntity managedObject];
            usernameEntity.status = ((NSNumber*)self.usernameStatuses[username]).intValue;
            usernameEntity.stringValue = username;
            usernameEntity.blockchainIdentity = entity;
            [entity addUsernamesObject:usernameEntity];
        }
        [DSBlockchainIdentityEntity saveContext];
    }];
}

-(void)save {
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityUsernameEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
        entity.creditBalance = self.creditBalance;
        entity.registrationStatus = self.registrationStatus;
        entity.type = self.type;
        [DSBlockchainIdentityEntity saveContext];
    }];
}


-(void)saveNewKey:(DSKey*)key atPath:(NSIndexPath*)path fromDerivationPath:(DSDerivationPath*)derivationPath {
    [self.managedObjectContext performBlockAndWait:^{
        [DSBlockchainIdentityEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityKeyPathEntity setContext:self.managedObjectContext];
        DSBlockchainIdentityEntity * entity = self.blockchainIdentityEntity;
        DSDerivationPathEntity * derivationPathEntity = derivationPath.derivationPathEntity;
        NSData *keyPathData = [NSKeyedArchiver archivedDataWithRootObject:path];
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsMatching:@"derivationPath == %@ && path == %@",derivationPathEntity,keyPathData];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity * blockchainIdentityKeyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObject];
            blockchainIdentityKeyPathEntity.derivationPath = derivationPath.derivationPathEntity;
            
            blockchainIdentityKeyPathEntity.path = keyPathData;
            [entity addKeyPathsObject:blockchainIdentityKeyPathEntity];
            [DSBlockchainIdentityEntity saveContext];
        }
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
        [DSBlockchainIdentityEntity saveContext];
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
            [entity addUsernamesObject:usernameEntity];
            if (commitSave) {
                [DSBlockchainIdentityEntity saveContext];
            }
        }
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
