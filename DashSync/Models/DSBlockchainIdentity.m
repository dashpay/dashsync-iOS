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
#import "DSTransition.h"
#import <TinyCborObjc/NSObject+DSCborEncoding.h>
#import "DSChainManager.h"
#import "DSDAPINetworkService.h"
#import "DSContactEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSDashPlatform.h"
#import "DSPotentialFriendship.h"
#import "NSData+Bitcoin.h"
#import "DSDAPIClient+RegisterDashPayContract.h"
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
#import "DPContract.h"

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"
#define DEFAULT_SIGNING_ALGORITH DSDerivationPathSigningAlgorith_ECDSA

@interface DSBlockchainIdentity()

@property (nonatomic,weak) DSWallet * wallet;
@property (nonatomic,strong) NSMutableDictionary <NSString *,NSNumber *> * usernameStatuses;
@property (nonatomic,assign) UInt256 uniqueId;
@property (nonatomic,assign) DSUTXO lockedOutpoint;
@property (nonatomic,assign) uint32_t index;
@property (nonatomic,assign,getter=isRegistered) BOOL registered;
@property (nonatomic,assign) UInt256 registrationTransitionHash;
@property (nonatomic,assign) UInt256 lastTransitionHash;
@property (nonatomic,assign) uint64_t creditBalance;

@property (nonatomic,assign) uint32_t keysCreated;
@property (nonatomic,assign) uint32_t currentMainKeyIndex;
@property (nonatomic,assign) DSDerivationPathSigningAlgorith currentMainKeyType;

@property(nonatomic,strong) DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition;
@property(nonatomic,strong) NSMutableArray <DSBlockchainIdentityTopupTransition*>* blockchainIdentityTopupTransitions;
@property(nonatomic,strong) NSMutableArray <DSBlockchainIdentityCloseTransition*>* blockchainIdentityCloseTransitions;
@property(nonatomic,strong) NSMutableArray <DSBlockchainIdentityUpdateTransition*>* blockchainIdentityUpdateTransitions;
@property(nonatomic,strong) NSMutableArray <DSDocumentTransition*>* documentTransitions;
@property(nonatomic,strong) NSMutableArray <DSTransition*>* allTransitions;

@property(nonatomic,readonly) DSDAPIClient* DAPIClient;
@property(nonatomic,readonly) DSDAPINetworkService* DAPINetworkService;

@property(nonatomic,strong) DPDocumentFactory* dashpayDocumentFactory;
@property(nonatomic,strong) DPDocumentFactory* dpnsDocumentFactory;

@property(nonatomic,strong) DSContactEntity * ownContact;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSBlockchainIdentity

-(instancetype)initAtIndex:(uint32_t)index inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);
    
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.keysCreated = 0;
    self.registrationTransitionHash = UINT256_ZERO;
    self.index = index;
    self.blockchainIdentityTopupTransitions = [NSMutableArray array];
    self.blockchainIdentityCloseTransitions = [NSMutableArray array];
    self.blockchainIdentityUpdateTransitions = [NSMutableArray array];
    self.documentTransitions = [NSMutableArray array];
    self.allTransitions = [NSMutableArray array];
    self.usernameStatuses = [NSMutableDictionary dictionary];
    self.registered = FALSE;
    if (managedObjectContext) {
        self.managedObjectContext = managedObjectContext;
    } else {
        self.managedObjectContext = [NSManagedObject context];
    }
    
    
    return self;
}

-(instancetype)initAtIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext {
    if (!(self = [self initAtIndex:index inWallet:wallet inContext:managedObjectContext])) return nil;
    NSAssert(!dsutxo_is_zero(lockedOutpoint), @"utxo must not be nil");
    self.lockedOutpoint = lockedOutpoint;
    self.uniqueId = [dsutxo_data(lockedOutpoint) SHA256_2];
    return self;
}

-(instancetype)initWithFundingTransaction:(DSCreditFundingTransaction*)transaction inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    NSParameterAssert(wallet);
    if (![transaction isCreditFundingTransaction]) return nil;
    if (!(self = [self initAtIndex:[transaction usedDerivationPathIndex] withLockedOutpoint:transaction.lockedOutpoint inWallet:wallet inContext:managedObjectContext])) return nil;
    
    [self loadTransitions];
    
    [self.managedObjectContext performBlockAndWait:^{
        self.ownContact = [DSContactEntity anyObjectMatching:@"associatedBlockchainIdentityUniqueId == %@",uint256_data(self.registrationTransitionHash)];
    }];
    
//    [self updateCreditBalance];
    
    
    return self;
}

-(NSData*)uniqueIdData {
    return uint256_data(self.uniqueId);
}

-(NSData*)lockedOutpointData {
    return dsutxo_data(self.lockedOutpoint);
}

-(NSString*)currentUsername {
    return [self.usernames firstObject];
}

-(NSString*)registrationTransitionHashIdentifier {
    NSAssert(!uint256_is_zero(self.registrationTransitionHash), @"Registration transaction hash is null");
    return uint256_hex(self.registrationTransitionHash);
}

-(void)updateCreditBalance {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        
        [self.DAPINetworkService getUserById:self.uniqueIdString success:^(NSDictionary * _Nullable profileDictionary) {
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

-(NSArray<DSDerivationPath*>*)derivationPaths {
    return [[DSDerivationPathFactory sharedInstance] unloadedSpecializedDerivationPathsForWallet:self.wallet];
}

-(void)loadTransitions {
    if (_wallet.isTransient) return;
    [self.managedObjectContext performBlockAndWait:^{
        [DSTransitionEntity setContext:self.managedObjectContext];
        [DSBlockchainIdentityRegistrationTransitionEntity setContext:self.managedObjectContext];
        [DSDerivationPathEntity setContext:self.managedObjectContext];
        NSArray<DSTransitionEntity *>* specialTransactionEntities = [DSTransitionEntity objectsMatching:@"(blockchainIdentity.uniqueId == %@)",self.uniqueIdData];
        for (DSTransitionEntity *e in specialTransactionEntities) {
                DSTransition *transition = [e transitionForChain:self.wallet.chain];
                
                if (! transition) continue;
                if ([transition isMemberOfClass:[DSBlockchainIdentityRegistrationTransition class]]) {
                    self.blockchainIdentityRegistrationTransition = (DSBlockchainIdentityRegistrationTransition*)transition;
                } else if ([transition isMemberOfClass:[DSBlockchainIdentityTopupTransition class]]) {
                    [self.blockchainIdentityTopupTransitions addObject:(DSBlockchainIdentityTopupTransition*)transition];
                } else if ([transition isMemberOfClass:[DSBlockchainIdentityUpdateTransition class]]) {
                    [self.blockchainIdentityUpdateTransitions addObject:(DSBlockchainIdentityUpdateTransition*)transition];
                } else if ([transition isMemberOfClass:[DSBlockchainIdentityCloseTransition class]]) {
                    [self.blockchainIdentityCloseTransitions addObject:(DSBlockchainIdentityCloseTransition*)transition];
                } else if ([transition isMemberOfClass:[DSDocumentTransition class]]) {
                    [self.documentTransitions addObject:(DSDocumentTransition*)transition];
                } else { //the other ones don't have addresses in payload
                    NSAssert(FALSE, @"Unknown special transaction type");
                }
        }
    }];
}

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

-(void)registerInWalletForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId {
    self.uniqueId = blockchainIdentityUniqueId;
    //self.blockchainIdentityRegistrationTransition = blockchainIdentityRegistrationTransition;
    //self.registrationTransitionHash = blockchainIdentityRegistrationTransition.transitionHash;
    [self registerInWallet];
}

-(void)registerInWallet {
    [self.wallet registerBlockchainIdentity:self];
}

-(void)registrationTransitionSignedByPrivateKey:(DSKey*)privateKey registeringPublicKeys:(NSDictionary <NSNumber*,DSKey*>*)publicKeys completion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction))completion {
        
    DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition = [[DSBlockchainIdentityRegistrationTransition alloc] initWithVersion:1 forIdentityType:DSBlockchainIdentityType_User registeringPublicKeys:publicKeys usingLockedOutpoint:self.lockedOutpoint onChain:self.wallet.chain];
    [blockchainIdentityRegistrationTransition signWithKey:privateKey fromIdentity:self];
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
        
        [self registrationTransitionSignedByPrivateKey:privateKey registeringPublicKeys:@{@(index):publicKey} completion:completion];
    }];
}

-(void)topupTransitionForFundingTransaction:(DSTransaction*)fundingTransaction completion:(void (^ _Nullable)(DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction))completion {
    NSParameterAssert(fundingTransaction);
    
//    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to topup %@ and spend %@ on credits?", nil),self.username,[[DSPriceManager sharedInstance] stringForDashAmount:topupAmount]];
//    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:topupAmount forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
//        if (!seed) {
//            completion(nil);
//            return;
//        }
//        DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction = [[DSBlockchainIdentityTopupTransition alloc] initWithBlockchainIdentityTopupTransactionVersion:1 registrationTransactionHash:self.registrationTransitionHash onChain:self.wallet.chain];
//
//        NSMutableData * opReturnScript = [NSMutableData data];
//        [opReturnScript appendUInt8:OP_RETURN];
//        [fundingAccount updateTransaction:blockchainIdentityTopupTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO];
//
//        completion(blockchainIdentityTopupTransaction);
//    }];
//
}

-(void)updateTransitionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainIdentityUpdateTransition * blockchainIdentityUpdateTransition))completion {
    
}

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

-(void)updateWithTopupTransition:(DSBlockchainIdentityTopupTransition*)blockchainIdentityTopupTransition save:(BOOL)save {
    NSParameterAssert(blockchainIdentityTopupTransition);
    
    if (![_blockchainIdentityTopupTransitions containsObject:blockchainIdentityTopupTransition]) {
        [_blockchainIdentityTopupTransitions addObject:blockchainIdentityTopupTransition];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithUpdateTransition:(DSBlockchainIdentityUpdateTransition*)blockchainIdentityUpdateTransition save:(BOOL)save {
    NSParameterAssert(blockchainIdentityUpdateTransition);
    
    if (![_blockchainIdentityUpdateTransitions containsObject:blockchainIdentityUpdateTransition]) {
        [_blockchainIdentityUpdateTransitions addObject:blockchainIdentityUpdateTransition];
        [_allTransitions addObject:blockchainIdentityUpdateTransition];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithCloseTransition:(DSBlockchainIdentityCloseTransition*)blockchainIdentityCloseTransition save:(BOOL)save {
    NSParameterAssert(blockchainIdentityCloseTransition);
    
    if (![_blockchainIdentityCloseTransitions containsObject:blockchainIdentityCloseTransition]) {
        [_blockchainIdentityCloseTransitions addObject:blockchainIdentityCloseTransition];
        [_allTransitions addObject:blockchainIdentityCloseTransition];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithTransition:(DSDocumentTransition*)transition save:(BOOL)save {
    NSParameterAssert(transition);
    
    if (![_documentTransitions containsObject:transition]) {
        [_documentTransitions addObject:transition];
        [_allTransitions addObject:transition];
        if (save) {
            [self save];
        }
    }
}

-(NSString*)uniqueIdString {
    return [uint256_data(self.uniqueId) base58String];
}

// MARK: - Keys

-(uint32_t)indexOfKey:(DSKey*)key {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:self.wallet];
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
    } else if (type == DSDerivationPathSigningAlgorith_ECDSA) {
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
    DSKey * key = [self publicKeyAtIndex:self.keysCreated ofType:type];
    self.keysCreated++;
    [self save];
    return key;
}

// MARK: - Funding

-(NSString*)registrationFundingAddress {
    if (self.creditFundingTransaction) {
        return [uint160_data(self.creditFundingTransaction.creditBurnPublicKeyHash) addressFromHash160DataForChain:self.wallet.chain];
    } else {
        DSCreditFundingDerivationPath * derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:self.wallet];
        return [derivationPathRegistrationFunding addressAtIndex:self.index];
    }
}

-(void)fundingTransactionForTopupAmount:(uint64_t)topupAmount toAddress:(NSString*)address fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSCreditFundingTransaction * fundingTransaction))completion {
    DSCreditFundingTransaction * fundingTransaction = [fundingAccount creditFundingTransactionFor:topupAmount to:address withFee:YES];
    completion(fundingTransaction);
}

// MARK: - DPNS

-(void)addUsername:(NSString*)username {
    [self.usernameStatuses setObject:@(DSBlockchainIdentityUsernameStatus_Initial) forKey:username];
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
    NSMutableArray * unregisteredUsernames = [NSMutableArray array];
    for (NSString * username in self.usernameStatuses) {
        DSBlockchainIdentityUsernameStatus status = [self.usernameStatuses[username] unsignedIntegerValue];
        if (status == DSBlockchainIdentityUsernameStatus_Initial) {
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

-(NSArray<DPDocument*>*)unregisteredUsernamesPreorderDocuments {
    NSMutableArray * usernamePreorderDocuments = [NSMutableArray array];
    for (NSString * unregisteredUsername in [self unregisteredUsernames]) {
        NSError * error = nil;
        NSMutableData * saltedDomain = [NSMutableData data];
        NSData * usernameData = [unregisteredUsername dataUsingEncoding:NSUTF8StringEncoding];
        [saltedDomain appendData:usernameData];
        NSString * saltedDomainHashString = uint256_hex([saltedDomain SHA256_2]);
        DSStringValueDictionary * dataDictionary = @{
            @"saltedDomainHash": saltedDomainHashString
        };
        DPDocument * document = [self.dpnsDocumentFactory documentOnTable:@"preorder" withDataDictionary:dataDictionary error:&error];
        [usernamePreorderDocuments addObject:document];
    }
    return usernamePreorderDocuments;
}

-(DSDocumentTransition*)unregisteredUsernamesPreorderTransition {
    NSArray * usernamePreorderDocuments = [self unregisteredUsernamesPreorderDocuments];
    if (![usernamePreorderDocuments count]) return nil;
    DSDocumentTransition * transition = [[DSDocumentTransition alloc] initForDocuments:usernamePreorderDocuments withTransitionVersion:1 blockchainIdentityUniqueId:self.uniqueId onChain:self.wallet.chain];
    return transition;
}

-(void)registerUsernames {
    DSDocumentTransition * transition = [self unregisteredUsernamesPreorderTransition];
    //__weak typeof(self) weakSelf = self;
    [self.DAPINetworkService publishTransition:transition success:^(NSDictionary * _Nonnull successDictionary) {
        
    } failure:^(NSError * _Nonnull error) {
        DSDLog(@"%@", error);
        
//        if (completion) {
//            completion(NO);
//        }
    }];
    
}

// MARK: - Persistence

-(void)save {
    
}


-(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransition {
    if (!_blockchainIdentityRegistrationTransition) {
        _blockchainIdentityRegistrationTransition = (DSBlockchainIdentityRegistrationTransition*)[self.wallet.specialTransactionsHolder transactionForHash:self.registrationTransitionHash];
    }
    return _blockchainIdentityRegistrationTransition;
}

-(UInt256)lastTransitionHash {
    //this is not effective, do this locally in the future
    return [[self allTransitions] lastObject].transitionHash;
}

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
        [transition signWithKey:privateKey fromIdentity:self];
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

-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@-%@}",self.currentUsername,self.uniqueIdString]];
}

// MARK: - Identity

-(void)createAndPublishRegistrationTransitionWithCompletion:(void (^)(NSDictionary *, NSError *))completion {
    [self registrationTransitionWithCompletion:^(DSBlockchainIdentityRegistrationTransition * _Nonnull blockchainIdentityRegistrationTransition) {
                                        if (blockchainIdentityRegistrationTransition) {
                                            [self.DAPIClient publishTransition:blockchainIdentityRegistrationTransition success:^(NSDictionary * _Nonnull successDictionary) {
                                                [self monitorForBlockchainIdentityWithRetryCount:5];
                                                completion(successDictionary,nil);
                                            } failure:^(NSError * _Nonnull error) {
                                                completion(nil,error);
                                            }];
                                        } else {
                                            NSError * error = [NSError errorWithDomain:@"DashSync" code:501 userInfo:@{NSLocalizedDescriptionKey:
                                            DSLocalizedString(@"Unable to create registration transition", nil)}];
                                            completion(nil,error);
                                        }
                                    }];

}
        
-(void)monitorForBlockchainIdentityWithRetryCount:(uint32_t)retryCount {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getUserById:self.uniqueIdString success:^(NSDictionary * _Nonnull profileDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        uint64_t creditBalance = (uint64_t)[profileDictionary[@"credits"] longLongValue];
        strongSelf.creditBalance = creditBalance;
        strongSelf.registered = TRUE;
    } failure:^(NSError * _Nonnull error) {
        if (retryCount > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self monitorForBlockchainIdentityWithRetryCount:retryCount - 1];
            });
        }
    }];
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

// MARK: - Layer 2

- (void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getUserByName:potentialContact.username success:^(NSDictionary *_Nonnull blockchainIdentity) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (!blockchainIdentity) {
            if (completion) {
                completion(NO);
            }
            return;
        }
        //TODO: switch this from regtxid
        UInt256 blockchainIdentityContactUniqueId = ((NSString*)blockchainIdentity[@"regtxid"]).hexToData.reverse.UInt256;
        __unused UInt384 blockchainIdentityContactEncryptionPublicKey = ((NSString*)blockchainIdentity[@"publicKey"]).hexToData.reverse.UInt384;
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

- (void)createOrUpdateProfileWithAboutMeString:(NSString*)aboutme avatarURLString:(NSString *)avatarURLString completion:(void (^)(BOOL success))completion {
//    DSDashPlatform *dpp = [DSDashPlatform sharedInstanceForChain:self.wallet.chain];
//    dpp.userId = uint256_reverse_hex(self.registrationTransitionHash);
//    DPContract *contract = [DSDAPIClient ds_currentDashPayContractForChain:self.wallet.chain];
//    dpp.contract = contract;
//    NSError *error = nil;
//    DSStringValueDictionary *data = @{
//                           @"about" :aboutme,
//                           @"avatarUrl" : avatarURLString,
//                           };
//    DPDocument *user = [dpp.documentFactory documentWithType:@"profile" data:data error:&error];
//    if (self.ownContact) {
//        NSError *error = nil;
//        [user setAction:DPDocumentAction_Update error:&error];
//        NSAssert(!error, @"Invalid action");
//        
//        // TODO: refactor DPDocument update/delete API
//        DPMutableJSONObject *mutableData = [data mutableCopy];
//        mutableData[@"$scopeId"] = self.ownContact.documentScopeID;
//        mutableData[@"$rev"] = @(self.ownContact.documentRevision + 1);
//        [user setData:mutableData error:&error];
//        NSAssert(!error, @"Invalid data");
//    }
//    NSAssert(error == nil, @"Failed to build a user");
//    
//    __weak typeof(self) weakSelf = self;
//    
//    [self.wallet.chain.chainManager.DAPIClient sendDocument:user forUser:self contract:contract completion:^(NSError * _Nullable error) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) {
//            return;
//        }
//        
//        BOOL success = error == nil;
//        
//        if (success) {
//            [self.DAPINetworkService getUserById:uint256_hex(uint256_reverse(self.registrationTransitionHash)) success:^(NSDictionary *_Nonnull blockchainIdentity) {
//                __strong typeof(weakSelf) strongSelf = weakSelf;
//                if (!strongSelf) {
//                    return;
//                }
//                
//                if (completion) {
//                    completion(!!blockchainIdentity);
//                }
//            } failure:^(NSError * _Nonnull error) {
//                DSDLog(@"%@",error);
//                if (completion) {
//                    completion(NO);
//                }
//            }];
//        }
//        else {
//            if (completion) {
//                completion(NO);
//            }
//        }
//    }];
}

-(DSDAPIClient*)DAPIClient {
    return self.wallet.chain.chainManager.DAPIClient;
}

-(DSDAPINetworkService*)DAPINetworkService {
    return self.DAPIClient.DAPINetworkService;
}

- (void)fetchProfile:(void (^)(BOOL))completion {
    [self fetchProfileForBlockchainIdentityUniqueId:self.uniqueId saveReturnedProfile:TRUE context:self.managedObjectContext completion:^(DSContactEntity *contactEntity) {
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
    
//    NSDictionary *query = @{ @"userId" : uint256_reverse_hex(blockchainIdentityUniqueId) };
//    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
//
//    __weak typeof(self) weakSelf = self;
//    DPContract *contract = [DSDAPIClient ds_currentDashPayContract];
//    // TODO: this method should have high-level wrapper in the category DSDAPIClient+DashPayDocuments
//
//    DSDLog(@"contract ID %@",[contract identifier]);
//    [self.DAPINetworkService fetchDocumentsForContractId:[contract identifier] objectsType:@"profile" options:options success:^(NSArray<NSDictionary *> *_Nonnull documents) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) {
//            return;
//        }
//        if (![documents count]) {
//            if (completion) {
//                completion(nil);
//            }
//            return;
//        }
//        //todo
//
//        NSDictionary * contactDictionary = [documents firstObject];
//        [context performBlockAndWait:^{
//            [DSContactEntity setContext:context];
//            [DSChainEntity setContext:context];
//            NSString *scopeID = [contactDictionary objectForKey:@"$scopeId"];
//            DSContactEntity * contact = [DSContactEntity anyObjectMatchingInContext:context withPredicate:@"documentScopeID == %@", scopeID];
//            if (!contact || [[contactDictionary objectForKey:@"$rev"] intValue] != contact.documentRevision) {
//
//                if (!contact) {
//                    contact = [DSContactEntity managedObjectInContext:context];
//                }
//
//                contact.documentScopeID = scopeID;
//                contact.documentRevision = [[contactDictionary objectForKey:@"$rev"] intValue];
//                contact.avatarPath = [contactDictionary objectForKey:@"avatarUrl"];
//                contact.publicMessage = [contactDictionary objectForKey:@"about"];
//                contact.associatedBlockchainIdentityUniqueId = uint256_data(registrationTransactionHash);
//                contact.chain = self.wallet.chain.chainEntity;
//                if (uint256_eq(registrationTransactionHash, self.registrationTransitionHash) && !self.ownContact) {
//                    DSBlockchainIdentityRegistrationTransitionEntity * blockchainIdentityRegistrationTransactionEntity = [DSBlockchainIdentityRegistrationTransitionEntity anyObjectMatchingInContext:context withPredicate:@"transactionHash.txHash == %@",uint256_data(registrationTransactionHash)];
//                    NSAssert(blockchainIdentityRegistrationTransactionEntity, @"blockchainIdentityRegistrationTransactionEntity must exist");
//                    contact.associatedBlockchainIdentityRegistrationTransaction = blockchainIdentityRegistrationTransactionEntity;
//                    contact.username = self.username;
//                    self.ownContact = contact;
//                    if (saveReturnedProfile) {
//                        [DSContactEntity saveContext];
//                    }
//                } else if ([self.wallet blockchainIdentityForRegistrationHash:registrationTransactionHash]) {
//                    //this means we are fetching a contact for another blockchain user on the device
//                    DSBlockchainIdentity * blockchainIdentity = [self.wallet blockchainIdentityForRegistrationHash:registrationTransactionHash];
//                    DSBlockchainIdentityRegistrationTransitionEntity * blockchainIdentityRegistrationTransactionEntity = [DSBlockchainIdentityRegistrationTransitionEntity anyObjectMatchingInContext:context withPredicate:@"transactionHash.txHash == %@",uint256_data(registrationTransactionHash)];
//                    NSAssert(blockchainIdentityRegistrationTransactionEntity, @"blockchainIdentityRegistrationTransactionEntity must exist");
//                    contact.associatedBlockchainIdentityRegistrationTransaction = blockchainIdentityRegistrationTransactionEntity;
//                    contact.username = blockchainIdentity.username;
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
//
//    } failure:^(NSError *_Nonnull error) {
//        if (completion) {
//            completion(nil);
//        }
//    }];
}

- (void)fetchIncomingContactRequests:(void (^)(BOOL success))completion {
    NSDictionary *query = @{ @"document.toUserId" : self.ownContact.associatedBlockchainIdentityUniqueId.reverse.hexString};
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.wallet.chain].dashPayContract;
    // TODO: this method should have high-level wrapper in the category DSDAPIClient+DashPayDocuments
    
    [self.DAPINetworkService fetchDocumentsForContractId:[contract identifier] objectsType:@"contact" options:options success:^(NSArray<NSDictionary *> *_Nonnull documents) {
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

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success))completion {
    NSDictionary *query = @{ @"userId" : uint256_reverse_hex(self.registrationTransitionHash)};
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.wallet.chain].dashPayContract;
    // TODO: this method should have high-level wrapper in the category DSDAPIClient+DashPayDocuments
    NSLog(@"%@",[contract identifier]);
    [self.DAPINetworkService fetchDocumentsForContractId:[contract identifier] objectsType:@"contact" options:options success:^(NSArray<NSDictionary *> *_Nonnull documents) {
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


- (void)handleContactRequestObjects:(NSArray<NSDictionary *> *)rawContactRequests context:(NSManagedObjectContext *)context completion:(void (^)(BOOL success))completion {
    NSMutableDictionary <NSData *,NSData *> *incomingNewRequests = [NSMutableDictionary dictionary];
    NSMutableDictionary <NSData *,NSData *> *outgoingNewRequests = [NSMutableDictionary dictionary];
    for (NSDictionary *rawContact in rawContactRequests) {
        NSDictionary * metaData = [rawContact objectForKey:@"$meta"];
        NSString *recipientString = rawContact[@"toUserId"];
        UInt256 recipientRegistrationHash = [recipientString hexToData].reverse.UInt256;
        NSString *senderString = metaData?metaData[@"userId"]:nil;
        UInt256 senderRegistrationHash = [senderString hexToData].reverse.UInt256;
        NSString *extendedPublicKeyString = rawContact[@"publicKey"];
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
                [self.DAPINetworkService getUserById:blockchainIdentityRegistrationHash.reverse.hexString success:^(NSDictionary *_Nonnull blockchainIdentityDictionary) {
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
                [self.DAPINetworkService getUserById:blockchainIdentityRegistrationHash.reverse.hexString success:^(NSDictionary *_Nonnull blockchainIdentityDictionary) {
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

@end
