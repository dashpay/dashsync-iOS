//
//  DSBlockchainUser.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "DSBlockchainUser.h"
#import "DSChain.h"
#import "DSECDSAKey.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSCoder+Dash.h"
#import "NSMutableData+Dash.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"
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
#import "DashPlatformProtocol+DashSync.h"
#import "DSPotentialFriendship.h"
#import "NSData+Bitcoin.h"
#import "DSDAPIClient+RegisterDashPayContract.h"
#import "NSManagedObject+Sugar.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSBlockchainUserRegistrationTransactionEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSPotentialContact.h"

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"

@interface DSBlockchainUser()

@property (nonatomic,weak) DSWallet * wallet;
@property (nonatomic,strong) NSString * username;
@property (nonatomic,strong) NSString * uniqueIdentifier;
@property (nonatomic,assign) uint32_t index;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 lastTransitionHash;
@property (nonatomic,assign) uint64_t creditBalance;

@property(nonatomic,strong) DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction;
@property(nonatomic,strong) NSMutableArray <DSBlockchainUserTopupTransaction*>* blockchainUserTopupTransactions;
@property(nonatomic,strong) NSMutableArray <DSBlockchainUserCloseTransaction*>* blockchainUserCloseTransactions; //this is also a transition
@property(nonatomic,strong) NSMutableArray <DSBlockchainUserResetTransaction*>* blockchainUserResetTransactions; //this is also a transition
@property(nonatomic,strong) NSMutableArray <DSTransition*>* baseTransitions;
@property(nonatomic,strong) NSMutableArray <DSTransaction*>* allTransitions;

@property(nonatomic,strong) DSContactEntity * ownContact;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSBlockchainUser

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    NSParameterAssert(username);
    NSParameterAssert(wallet);
    
    if (!(self = [super init])) return nil;
    self.username = username;
    self.uniqueIdentifier = [NSString stringWithFormat:@"%@_%@_%@",BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY,wallet.chain.uniqueID,username];
    self.wallet = wallet;
    self.registrationTransactionHash = UINT256_ZERO;
    self.index = index;
    self.blockchainUserTopupTransactions = [NSMutableArray array];
    self.blockchainUserCloseTransactions = [NSMutableArray array];
    self.blockchainUserResetTransactions = [NSMutableArray array];
    self.baseTransitions = [NSMutableArray array];
    self.allTransitions = [NSMutableArray array];
    if (managedObjectContext) {
        self.managedObjectContext = managedObjectContext;
    } else {
        self.managedObjectContext = [NSManagedObject context];
    }
    
    [self updateCreditBalance];
    
    
    return self;
}

-(NSData*)registrationTransactionHashData {
    return uint256_data(self.registrationTransactionHash);
}

-(NSString*)registrationTransactionHashIdentifier {
    NSAssert(!uint256_is_zero(self.registrationTransactionHash), @"Registration transaction hash is null");
    return uint256_hex(self.registrationTransactionHash);
}

-(void)updateCreditBalance {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        
        [self.DAPINetworkService getUserByName:self.username success:^(NSDictionary * _Nullable profileDictionary) {
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

-(void)loadTransitions {
    self.allTransitions = [[self.wallet.specialTransactionsHolder subscriptionTransactionsForRegistrationTransactionHash:self.registrationTransactionHash] mutableCopy];
    for (DSTransaction * transaction in self.allTransitions) {
        if ([transaction isKindOfClass:[DSTransition class]]) {
            [self.baseTransitions addObject:(DSTransition*)transaction];
        } else if ([transaction isKindOfClass:[DSBlockchainUserCloseTransaction class]]) {
            [self.blockchainUserCloseTransactions addObject:(DSBlockchainUserCloseTransaction*)transaction];
        } else if ([transaction isKindOfClass:[DSBlockchainUserResetTransaction class]]) {
            [self.blockchainUserResetTransactions addObject:(DSBlockchainUserResetTransaction*)transaction];
        }
    }
}

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet createdWithTransactionHash:(UInt256)registrationTransactionHash lastTransitionHash:(UInt256)lastTransitionHash inContext:(NSManagedObjectContext*)managedObjectContext {
    if (!(self = [self initWithUsername:username atIndex:index inWallet:wallet inContext:managedObjectContext])) return nil;
    NSAssert(!uint256_is_zero(registrationTransactionHash), @"Registration hash must not be nil");
    self.registrationTransactionHash = registrationTransactionHash;
    self.lastTransitionHash = lastTransitionHash; //except topup and close, including state transitions
    
    [self loadTransitions];
    
    [self.managedObjectContext performBlockAndWait:^{
        self.ownContact = [DSContactEntity anyObjectMatching:@"associatedBlockchainUserRegistrationTransaction.transactionHash.txHash == %@",uint256_data(self.registrationTransactionHash)];
    }];
    
    return self;
}

-(instancetype)initWithBlockchainUserRegistrationTransaction:(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction inContext:(NSManagedObjectContext*)managedObjectContext {
    uint32_t index = 0;
    DSWallet * wallet = [blockchainUserRegistrationTransaction.chain walletHavingBlockchainUserAuthenticationHash:blockchainUserRegistrationTransaction.pubkeyHash foundAtIndex:&index];
    if (!(self = [self initWithUsername:blockchainUserRegistrationTransaction.username atIndex:index inWallet:wallet inContext:(NSManagedObjectContext*)managedObjectContext])) return nil;
    self.registrationTransactionHash = blockchainUserRegistrationTransaction.txHash;
    self.blockchainUserRegistrationTransaction = blockchainUserRegistrationTransaction;
    
    [self loadTransitions];
    
    return self;
}

-(void)generateBlockchainUserExtendedPublicKey:(void (^ _Nullable)(BOOL registered))completion {
    __block DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
    if ([derivationPath hasExtendedPublicKey]) {
        completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"Generate Blockchain User" forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        [derivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
        completion(YES);
    }];
}

-(void)registerInWalletForBlockchainUserRegistrationTransaction:(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction {
    self.blockchainUserRegistrationTransaction = blockchainUserRegistrationTransaction;
    self.registrationTransactionHash = blockchainUserRegistrationTransaction.txHash;
    [self registerInWallet];
}

-(void)registerInWallet {
    [self.wallet registerBlockchainUser:self];
}

-(void)registrationTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction))completion {
    NSParameterAssert(fundingAccount);
    
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to register the username %@ and spend %@ on credits?", nil),self.username,[[DSPriceManager sharedInstance] stringForDashAmount:topupAmount]];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:topupAmount forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];
        
        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = [[DSBlockchainUserRegistrationTransaction alloc] initWithBlockchainUserRegistrationTransactionVersion:1 username:self.username pubkeyHash:[privateKey.publicKeyData hash160] onChain:self.wallet.chain];
        [blockchainUserRegistrationTransaction signPayloadWithKey:privateKey];
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:blockchainUserRegistrationTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO];
        
        completion(blockchainUserRegistrationTransaction);
    }];
}

-(void)topupTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction))completion {
    NSParameterAssert(fundingAccount);
    
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to topup %@ and spend %@ on credits?", nil),self.username,[[DSPriceManager sharedInstance] stringForDashAmount:topupAmount]];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:topupAmount forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = [[DSBlockchainUserTopupTransaction alloc] initWithBlockchainUserTopupTransactionVersion:1 registrationTransactionHash:self.registrationTransactionHash onChain:self.wallet.chain];
        
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:blockchainUserTopupTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO];
        
        completion(blockchainUserTopupTransaction);
    }];
    
}

-(void)resetTransactionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainUserResetTransaction * blockchainUserResetTransaction))completion {
    NSString * question = DSLocalizedString(@"Are you sure you would like to reset this user?", nil);
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:0 forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
        DSECDSAKey * oldPrivateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:self.index fromSeed:seed];
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:index fromSeed:seed];
        
        DSBlockchainUserResetTransaction * blockchainUserResetTransaction = [[DSBlockchainUserResetTransaction alloc] initWithBlockchainUserResetTransactionVersion:1 registrationTransactionHash:self.registrationTransactionHash previousBlockchainUserTransactionHash:self.lastTransitionHash replacementPublicKeyHash:[privateKey.publicKeyData hash160] creditFee:1000 onChain:self.wallet.chain];
        [blockchainUserResetTransaction signPayloadWithKey:oldPrivateKey];
        DSDLog(@"%@",blockchainUserResetTransaction.toData);
        completion(blockchainUserResetTransaction);
    }];
}

-(void)updateWithTopupTransaction:(DSBlockchainUserTopupTransaction*)blockchainUserTopupTransaction save:(BOOL)save {
    NSParameterAssert(blockchainUserTopupTransaction);
    
    if (![_blockchainUserTopupTransactions containsObject:blockchainUserTopupTransaction]) {
        [_blockchainUserTopupTransactions addObject:blockchainUserTopupTransaction];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithResetTransaction:(DSBlockchainUserResetTransaction*)blockchainUserResetTransaction save:(BOOL)save {
    NSParameterAssert(blockchainUserResetTransaction);
    
    if (![_blockchainUserResetTransactions containsObject:blockchainUserResetTransaction]) {
        [_blockchainUserResetTransactions addObject:blockchainUserResetTransaction];
        [_allTransitions addObject:blockchainUserResetTransaction];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithCloseTransaction:(DSBlockchainUserCloseTransaction*)blockchainUserCloseTransaction save:(BOOL)save {
    NSParameterAssert(blockchainUserCloseTransaction);
    
    if (![_blockchainUserCloseTransactions containsObject:blockchainUserCloseTransaction]) {
        [_blockchainUserCloseTransactions addObject:blockchainUserCloseTransaction];
        [_allTransitions addObject:blockchainUserCloseTransaction];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithTransition:(DSTransition*)transition save:(BOOL)save {
    NSParameterAssert(transition);
    
    if (![_baseTransitions containsObject:transition]) {
        [_baseTransitions addObject:transition];
        [_allTransitions addObject:transition];
        if (save) {
            [self save];
        }
    }
}

// MARK: - Persistence

-(void)save {
    
}


-(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction {
    if (!_blockchainUserRegistrationTransaction) {
        _blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction*)[self.wallet.specialTransactionsHolder transactionForHash:self.registrationTransactionHash];
    }
    return _blockchainUserRegistrationTransaction;
}

-(UInt256)lastTransitionHash {
    //this is not effective, do this locally in the future
    return [self.wallet.specialTransactionsHolder lastSubscriptionTransactionHashForRegistrationTransactionHash:self.registrationTransactionHash];
}

-(DSTransition*)transitionForStateTransitionPacketHash:(UInt256)stateTransitionHash {
    DSTransition * transition = [[DSTransition alloc] initWithTransitionVersion:1 registrationTransactionHash:self.registrationTransactionHash previousTransitionHash:self.lastTransitionHash creditFee:1000 packetHash:stateTransitionHash onChain:self.wallet.chain];
    return transition;
}

-(void)signStateTransition:(DSTransition*)transition withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion {
    NSParameterAssert(transition);
    
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt forWallet:self.wallet forAmount:0 forceAuthentication:YES completion:^(NSData* _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:self.index fromSeed:seed];
        NSLog(@"%@",uint160_hex(privateKey.publicKeyData.hash160));
        
        NSLog(@"%@",uint160_hex(self.blockchainUserRegistrationTransaction.pubkeyHash));
        NSAssert(uint160_eq(privateKey.publicKeyData.hash160,self.blockchainUserRegistrationTransaction.pubkeyHash),@"Keys aren't ok");
        [transition signPayloadWithKey:privateKey];
        completion(YES);
    }];
}

-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@-%@}",self.username,self.registrationTransactionHashIdentifier]];
}

// MARK: - Layer 2

- (void)sendNewFriendRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    [self.DAPINetworkService getUserByName:potentialContact.username success:^(NSDictionary *_Nonnull blockchainUser) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (!blockchainUser) {
            if (completion) {
                completion(NO);
            }
            return;
        }
        
        UInt256 blockchainUserContactRegistrationHash = ((NSString*)blockchainUser[@"regtxid"]).hexToData.reverse.UInt256;
        UInt384 blockchainUserContactEncryptionPublicKey = ((NSString*)blockchainUser[@"publicKey"]).hexToData.reverse.UInt384;
        NSAssert(!uint256_is_zero(blockchainUserContactRegistrationHash), @"blockchainUserContactRegistrationHash should not be null");
        //NSAssert(!uint384_is_zero(blockchainUserContactEncryptionPublicKey), @"blockchainUserContactEncryptionPublicKey should not be null");
        [potentialContact setAssociatedBlockchainUserRegistrationTransactionHash:blockchainUserContactRegistrationHash];
        //[potentialContact setContactEncryptionPublicKey:blockchainUserContactEncryptionPublicKey];
        DSAccount * account = [self.wallet accountWithNumber:0];
        DSPotentialFriendship * potentialFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:potentialContact sourceBlockchainUser:self account:account];
        
        [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship completion:completion];
    } failure:^(NSError *_Nonnull error) {
        DSDLog(@"%@", error);
        
        if (completion) {
            completion(NO);
        }
    }];
}

- (void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialFriendship*)potentialFriendship completion:(void (^)(BOOL))completion {
    if (uint256_is_zero(potentialFriendship.destinationContact.associatedBlockchainUserRegistrationTransactionHash)) {
        [self sendNewFriendRequestToPotentialContact:potentialFriendship.destinationContact completion:completion];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDAPIClient ds_currentDashPayContract];
    
    [self.wallet.chain.chainManager.DAPIClient sendDocument:potentialFriendship.contactRequestDocument forUser:self contract:contract completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        BOOL success = error == nil;
        
        if (success) {
            [self fetchProfileForRegistrationTransactionHash:potentialFriendship.destinationContact.associatedBlockchainUserRegistrationTransactionHash saveReturnedProfile:NO completion:^(DSContactEntity *contactEntity) {
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
    [contact setAssociatedBlockchainUserRegistrationTransactionHash:friendRequest.sourceContact.associatedBlockchainUserRegistrationHash.UInt256];
    DSPotentialFriendship *potentialFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:contact
                                                                          sourceBlockchainUser:self
                                                                                      account:account];
    [potentialFriendship createDerivationPath];
    
    [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship completion:completion];
    
}

- (void)createProfileWithAboutMeString:(NSString*)aboutme completion:(void (^)(BOOL success))completion {
    DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
    dpp.userId = uint256_reverse_hex(self.registrationTransactionHash);
    DPContract *contract = [DSDAPIClient ds_currentDashPayContract];
    dpp.contract = contract;
    NSError *error = nil;
    DPJSONObject *data = @{
                           @"about" :aboutme,
                           @"avatarUrl" : [NSString stringWithFormat:@"https://api.adorable.io/avatars/120/%@.png", self.username],
                           };
    DPDocument *user = [dpp.documentFactory documentWithType:@"profile" data:data error:&error];
    NSAssert(error == nil, @"Failed to build a user");
    
    __weak typeof(self) weakSelf = self;
    
    [self.wallet.chain.chainManager.DAPIClient sendDocument:user forUser:self contract:contract completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        BOOL success = error == nil;
        
        if (success) {
            [self.DAPINetworkService getUserById:uint256_hex(uint256_reverse(self.registrationTransactionHash)) success:^(NSDictionary *_Nonnull blockchainUser) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                
                if (completion) {
                    completion(!!blockchainUser);
                }
            } failure:^(NSError * _Nonnull error) {
                DSDLog(@"%@",error);
                if (completion) {
                    completion(NO);
                }
            }];
        }
        else {
            if (completion) {
                completion(NO);
            }
        }
    }];
}

-(DSDAPINetworkService*)DAPINetworkService {
    return self.wallet.chain.chainManager.DAPIClient.DAPINetworkService;
}

- (void)fetchProfile:(void (^)(BOOL))completion {
    [self fetchProfileForRegistrationTransactionHash:self.registrationTransactionHash saveReturnedProfile:TRUE completion:^(DSContactEntity *contactEntity) {
        if (completion) {
            if (contactEntity) {
                completion(YES);
            } else {
                completion(NO);
            }
        }
    }];
}

- (void)fetchProfileForRegistrationTransactionHash:(UInt256)registrationTransactionHash saveReturnedProfile:(BOOL)saveReturnedProfile completion:(void (^)(DSContactEntity* contactEntity))completion {
    NSDictionary *query = @{ @"userId" : uint256_reverse_hex(self.registrationTransactionHash) };
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDAPIClient ds_currentDashPayContract];
    // TODO: this method should have high-level wrapper in the category DSDAPIClient+DashPayDocuments
    
    DSDLog(@"contract ID %@",[contract identifier]);
    [self.DAPINetworkService fetchDocumentsForContractId:[contract identifier] objectsType:@"profile" options:options success:^(NSArray<NSDictionary *> *_Nonnull documents) {
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
        [self.managedObjectContext performBlockAndWait:^{
            [DSContactEntity setContext:self.managedObjectContext];
            [DSChainEntity setContext:self.managedObjectContext];
            DSContactEntity * contact = [DSContactEntity managedObject];
            contact.avatarPath = [contactDictionary objectForKey:@"avatarUrl"];
            contact.publicMessage = [contactDictionary objectForKey:@"about"];
            contact.chain = self.wallet.chain.chainEntity;
            if (uint256_eq(registrationTransactionHash, self.registrationTransactionHash) && !self.ownContact) {
                DSBlockchainUserRegistrationTransactionEntity * blockchainUserRegistrationTransactionEntity = [DSBlockchainUserRegistrationTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@",uint256_data(self.registrationTransactionHash)];
                NSAssert(blockchainUserRegistrationTransactionEntity, @"blockchainUserRegistrationTransactionEntity must exist");
                contact.associatedBlockchainUserRegistrationHash = uint256_data(self.registrationTransactionHash);
                contact.associatedBlockchainUserRegistrationTransaction = blockchainUserRegistrationTransactionEntity;
                contact.username = self.username;
                self.ownContact = contact;
                if (saveReturnedProfile) {
                    [DSContactEntity saveContext];
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
    NSDictionary *query = @{ @"document.toUserId" : self.ownContact.associatedBlockchainUserRegistrationHash.reverse.hexString};
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDAPIClient ds_currentDashPayContract];
    // TODO: this method should have high-level wrapper in the category DSDAPIClient+DashPayDocuments
    
    [self.DAPINetworkService fetchDocumentsForContractId:[contract identifier] objectsType:@"contact" options:options success:^(NSArray<NSDictionary *> *_Nonnull documents) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf handleContactRequestObjects:documents];
        
        if (completion) {
            completion(YES);
        }
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            completion(NO);
        }
    }];
}

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success))completion {
    NSDictionary *query = @{ @"userId" : uint256_reverse_hex(self.registrationTransactionHash)};
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
    
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDAPIClient ds_currentDashPayContract];
    // TODO: this method should have high-level wrapper in the category DSDAPIClient+DashPayDocuments
    NSLog(@"%@",[contract identifier]);
    [self.DAPINetworkService fetchDocumentsForContractId:[contract identifier] objectsType:@"contact" options:options success:^(NSArray<NSDictionary *> *_Nonnull documents) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf handleContactRequestObjects:documents];
        
        if (completion) {
            completion(YES);
        }
    } failure:^(NSError *_Nonnull error) {
        if (completion) {
            completion(NO);
        }
    }];
}


- (void)handleContactRequestObjects:(NSArray<NSDictionary *> *)rawContactRequests {
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
        if (uint256_eq(recipientRegistrationHash, self.ownContact.associatedBlockchainUserRegistrationHash.UInt256)) {
            //we are the recipient, this is an incoming request
            DSFriendRequestEntity * friendRequest = [DSFriendRequestEntity anyObjectMatching:@"destinationContact == %@ && sourceContact.associatedBlockchainUserRegistrationHash == %@",self.ownContact,[NSData dataWithUInt256:senderRegistrationHash]];
            if (!friendRequest) {
                [incomingNewRequests setObject:extendedPublicKey forKey:[NSData dataWithUInt256:senderRegistrationHash]];
            } else if (friendRequest.sourceContact == nil) {
                
            }
        } else if (uint256_eq(senderRegistrationHash, self.ownContact.associatedBlockchainUserRegistrationHash.UInt256)) {
            BOOL isNew = ![DSFriendRequestEntity countObjectsMatching:@"sourceContact == %@ && destinationContact.associatedBlockchainUserRegistrationHash == %@",self.ownContact,[NSData dataWithUInt256:senderRegistrationHash]];
            if (isNew) {
                [outgoingNewRequests setObject:extendedPublicKey forKey:[NSData dataWithUInt256:recipientRegistrationHash]];
            }
        } else {
            NSAssert(FALSE, @"the contact request needs to be either outgoing or incoming");
        }
    }
    if ([incomingNewRequests count]) {
        [self handleIncomingRequests:incomingNewRequests];
    }
    if ([outgoingNewRequests count]) {
        [self handleOutgoingRequests:outgoingNewRequests];
    }
}

- (void)handleIncomingRequests:(NSDictionary <NSData *,NSData *>  *)incomingRequests {
    [self.managedObjectContext performBlockAndWait:^{
        [DSContactEntity setContext:self.managedObjectContext];
        [DSFriendRequestEntity setContext:self.managedObjectContext];
        for (NSData * blockchainUserRegistrationHash in incomingRequests) {
            DSContactEntity * externalContact = [DSContactEntity anyObjectMatching:@"associatedBlockchainUserRegistrationHash == %@",blockchainUserRegistrationHash];
            if (!externalContact) {
                //no contact exists yet
                [self.DAPINetworkService getUserById:blockchainUserRegistrationHash.hexString success:^(NSDictionary *_Nonnull blockchainUserDictionary) {
                    if (blockchainUserDictionary) {
                        UInt256 contactBlockchainUserTransactionRegistrationHash = ((NSString*)blockchainUserDictionary[@"hash"]).hexToData.reverse.UInt256;
                        [self fetchProfileForRegistrationTransactionHash:contactBlockchainUserTransactionRegistrationHash saveReturnedProfile:NO completion:^(DSContactEntity *contactEntity) {
                            if (contactEntity) {
                                NSString * username = blockchainUserDictionary[@"uname"];
                                contactEntity.username = username;
                                contactEntity.associatedBlockchainUserRegistrationHash = uint256_data(contactBlockchainUserTransactionRegistrationHash);
                                
                                DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
                                friendRequestEntity.sourceContact = contactEntity;
                                friendRequestEntity.destinationContact = self.ownContact;
                                
                                DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity managedObject];
                                derivationPathEntity.chain = self.wallet.chain.chainEntity;
                                
                                friendRequestEntity.derivationPath = derivationPathEntity;
                                
                                DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:0 onChain:self.wallet.chain];
                                
                                derivationPathEntity.account = accountEntity;
                                
                                friendRequestEntity.account = accountEntity;
                                
                                [friendRequestEntity finalizeWithFriendshipIdentifier];
                                
                                DSIncomingFundsDerivationPath * derivationPath = [DSIncomingFundsDerivationPath externalDerivationPathWithExtendedPublicKey:incomingRequests[blockchainUserRegistrationHash] withDestinationBlockchainUserRegistrationTransactionHash:self.ownContact.associatedBlockchainUserRegistrationHash.UInt256 sourceBlockchainUserRegistrationTransactionHash:contactEntity.associatedBlockchainUserRegistrationHash.UInt256 onChain:self.wallet.chain];
                                
                                derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
                                
                                [derivationPath storeExternalDerivationPathExtendedPublicKeyToKeyChain];
                                
                                [self.ownContact addIncomingRequestsObject:friendRequestEntity];
                                
                                [DSContactEntity saveContext];
                            }
                        }];
                    }
                } failure:^(NSError * _Nonnull error) {
                    
                }];
            } else {
                if (externalContact.associatedBlockchainUserRegistrationHash && [self.wallet blockchainUserForRegistrationHash:externalContact.associatedBlockchainUserRegistrationHash.UInt256]) {
                    //it's also local (aka both contacts are on this device), we should store the extended public key for the destination
                    DSBlockchainUser * sourceBlockchainUser = [self.wallet blockchainUserForRegistrationHash:externalContact.associatedBlockchainUserRegistrationHash.UInt256];
                    DSAccount * account = [sourceBlockchainUser.wallet accountWithNumber:0];
                    
                    DSPotentialContact* contact = [[DSPotentialContact alloc] initWithContactEntity:self.ownContact];
                    
                    DSPotentialFriendship * potentialFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:contact sourceBlockchainUser:sourceBlockchainUser account:account];
                    
                    [potentialFriendship createDerivationPath];
                    
                    DSFriendRequestEntity * friendRequest = [potentialFriendship outgoingFriendRequestForContactEntity:self.ownContact];
                    [potentialFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequest];
                    [self.ownContact addIncomingRequestsObject:friendRequest];
                } else {
                    //the contact already existed, create the incoming friend request, add a friendship if an outgoing friend request also exists
                    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
                    friendRequestEntity.sourceContact = externalContact;
                    friendRequestEntity.destinationContact = self.ownContact;
                    
                    DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:0 onChain:self.wallet.chain];
                    
                    friendRequestEntity.account = accountEntity;
                    
                    [friendRequestEntity finalizeWithFriendshipIdentifier];
                    
                    [self.ownContact addIncomingRequestsObject:friendRequestEntity];
                    if ([[externalContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",self.ownContact]] count]) {
                        [self.ownContact addFriendsObject:externalContact];
                    }
                }
                
                [DSContactEntity saveContext];
            }
        }
    }];
}

- (void)handleOutgoingRequests:(NSDictionary <NSData *,NSData *>  *)outgoingRequests {
    [self.managedObjectContext performBlockAndWait:^{
        [DSContactEntity setContext:self.managedObjectContext];
        [DSFriendRequestEntity setContext:self.managedObjectContext];
        for (NSData * blockchainUserRegistrationHash in outgoingRequests) {
            DSContactEntity * destinationContact = [DSContactEntity anyObjectMatching:@"associatedBlockchainUserRegistrationHash == %@",blockchainUserRegistrationHash];
            if (!destinationContact) {
                //no contact exists yet
                [self.DAPINetworkService getUserById:blockchainUserRegistrationHash.hexString success:^(NSDictionary *_Nonnull blockchainUserDictionary) {
                    if (blockchainUserDictionary) {
                        UInt256 contactBlockchainUserTransactionRegistrationHash = ((NSString*)blockchainUserDictionary[@"hash"]).hexToData.reverse.UInt256;
                        [self fetchProfileForRegistrationTransactionHash:contactBlockchainUserTransactionRegistrationHash saveReturnedProfile:NO completion:^(DSContactEntity *destinationContactEntity) {
                            NSString * username = blockchainUserDictionary[@"uname"];
                            destinationContactEntity.username = username;
                            destinationContactEntity.associatedBlockchainUserRegistrationHash = uint256_data(contactBlockchainUserTransactionRegistrationHash);
                            DSAccount * account = [self.wallet accountWithNumber:0];
                            
                            DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
                            friendRequestEntity.sourceContact = self.ownContact;
                            friendRequestEntity.destinationContact = destinationContactEntity;
                            
                            DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:0 onChain:self.wallet.chain];
                            
                            friendRequestEntity.account = accountEntity;
                            
                            [friendRequestEntity finalizeWithFriendshipIdentifier];
                            
                            [self.ownContact addOutgoingRequestsObject:friendRequestEntity];
                            
                            DSPotentialContact * contact = [[DSPotentialContact alloc] initWithContactEntity:destinationContactEntity];
                            
                            DSPotentialFriendship * realFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:contact sourceBlockchainUser:self account:account];
                            
                            [realFriendship createDerivationPath];
                            
                            [realFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequestEntity];
                            
                            [DSContactEntity saveContext];
                        }];
                    }
                } failure:^(NSError * _Nonnull error) {
                    
                }];
            } else {
                //the contact already existed, meaning they had made a friend request to us before, and on another device we had accepted
                //or the contact is locally known on the device
                DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
                friendRequestEntity.sourceContact = self.ownContact;
                friendRequestEntity.destinationContact = destinationContact;
                
                DSAccountEntity * accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueID index:0 onChain:self.wallet.chain];
                
                friendRequestEntity.account = accountEntity;
                
                [friendRequestEntity finalizeWithFriendshipIdentifier];
                
                DSAccount * account = [self.wallet accountWithNumber:0];
                
                DSPotentialContact* contact = [[DSPotentialContact alloc] initWithContactEntity:destinationContact];
                
                DSPotentialFriendship * realFriendship = [[DSPotentialFriendship alloc] initWithDestinationContact:contact sourceBlockchainUser:self account:account];
                
                [realFriendship createDerivationPath];
                
                [realFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequestEntity];
                
                [self.ownContact addOutgoingRequestsObject:friendRequestEntity];
                if ([[destinationContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",self.ownContact]] count]) {
                    [self.ownContact addFriendsObject:destinationContact];
                }
                
                [DSContactEntity saveContext];
            }
        }
        
        
    }];
}

@end
