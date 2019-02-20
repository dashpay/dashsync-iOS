//
//  DSLocalMasternode.m
//  DashSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import "DSLocalMasternode.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSAuthenticationManager.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "DSMasternodeManager.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataProperties.h"
#include <arpa/inet.h>

@interface DSLocalMasternode()

@property(nonatomic,assign) UInt128 ipAddress;
@property(nonatomic,assign) uint32_t port;
@property(nonatomic,strong) DSWallet * operatorKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * holdingKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * ownerKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * votingKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,assign) uint32_t operatorWalletIndex; //the derivation path index of keys
@property(nonatomic,assign) uint32_t ownerWalletIndex;
@property(nonatomic,assign) uint32_t votingWalletIndex;
@property(nonatomic,assign) uint32_t holdingWalletIndex;
@property(nonatomic,assign) DSLocalMasternodeStatus status;

@end

@implementation DSLocalMasternode

-(instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet*)wallet {
    if (!(self = [super init])) return nil;
    
    return [self initWithIPAddress:ipAddress onPort:port inFundsWallet:wallet inOperatorWallet:wallet inOwnerWallet:wallet
                    inVotingWallet:wallet];
}
-(instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet*)fundsWallet inOperatorWallet:(DSWallet*)operatorWallet inOwnerWallet:(DSWallet*)ownerWallet inVotingWallet:(DSWallet*)votingWallet {
    if (!(self = [super init])) return nil;
    self.operatorKeysWallet = operatorWallet;
    self.holdingKeysWallet = fundsWallet;
    self.ownerKeysWallet = ownerWallet;
    self.votingKeysWallet = votingWallet;
    self.ipAddress = ipAddress;
    self.port = port;
    return self;
}

-(instancetype)initWithProviderTransactionRegistration:(DSProviderRegistrationTransaction*)providerRegistrationTransaction {
    if (!(self = [super init])) return nil;
    uint32_t ownerAddressIndex;
    uint32_t votingAddressIndex;
    uint32_t operatorAddressIndex;
    uint32_t holdingAddressIndex;
    DSWallet * ownerWallet = [providerRegistrationTransaction.chain walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:&ownerAddressIndex];
    DSWallet * votingWallet = [providerRegistrationTransaction.chain walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:&votingAddressIndex];
    DSWallet * operatorWallet = [providerRegistrationTransaction.chain walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:&operatorAddressIndex];
    DSWallet * holdingWallet = [providerRegistrationTransaction.chain walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:&holdingAddressIndex];
    self.operatorKeysWallet = operatorWallet;
    self.holdingKeysWallet = holdingWallet;
    self.ownerKeysWallet = ownerWallet;
    self.votingKeysWallet = votingWallet;
    self.ownerWalletIndex = ownerAddressIndex;
    self.operatorWalletIndex = operatorAddressIndex;
    self.votingWalletIndex = votingAddressIndex;
    self.holdingWalletIndex = holdingAddressIndex;
    self.ipAddress = providerRegistrationTransaction.ipAddress;
    self.port = providerRegistrationTransaction.port;
    self.status = DSLocalMasternodeStatus_Registered; //because it comes from a transaction already
    return self;
}

-(void)registerInAssociatedWallets {
    [self.operatorKeysWallet registerMasternodeOperator:self];
    [self.ownerKeysWallet registerMasternodeOwner:self];
    [self.votingKeysWallet registerMasternodeVoter:self];
}

-(void)registrationTransactionFundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSProviderRegistrationTransaction * providerRegistrationTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_New) return;
    char s[INET6_ADDRSTRLEN];
    NSString * ipAddressString = @(inet_ntop(AF_INET, &self.ipAddress.u32[3], s, sizeof(s)));
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to register a masternode at %@:%d?", nil),ipAddressString,self.port];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:fundingAccount.wallet forAmount:MASTERNODE_COST forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self.holdingKeysWallet];
        if (!providerFundsDerivationPath.hasExtendedPublicKey) {
            [providerFundsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.holdingKeysWallet.uniqueID];
        }
        DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];
        if (!providerOwnerKeysDerivationPath.hasExtendedPublicKey) {
            [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.ownerKeysWallet.uniqueID];
        }
        DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];
        if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
            [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.operatorKeysWallet.uniqueID];
        }
        DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self.votingKeysWallet];
        if (!providerVotingKeysDerivationPath.hasExtendedPublicKey) {
            [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.votingKeysWallet.uniqueID];
        }
        
        NSString * holdingAddress = [providerFundsDerivationPath receiveAddress];
        NSMutableData * scriptPayout = [NSMutableData data];
        [scriptPayout appendScriptPubKeyForAddress:holdingAddress forChain:self.holdingKeysWallet.chain];
        
        DSECDSAKey * ownerKey = [providerOwnerKeysDerivationPath firstUnusedPrivateKeyFromSeed:seed];
        UInt160 votingKeyHash = providerVotingKeysDerivationPath.firstUnusedPublicKey.hash160;
        UInt384 operatorKey = providerOperatorKeysDerivationPath.firstUnusedPublicKey.UInt384;
        DSProviderRegistrationTransaction * providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithProviderRegistrationTransactionVersion:1 type:0 mode:0 ipAddress:self.ipAddress port:self.port ownerKeyHash:ownerKey.publicKeyData.hash160 operatorKey:operatorKey votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:scriptPayout onChain:fundingAccount.wallet.chain];
        
        NSMutableData *script = [NSMutableData data];
        
        [script appendScriptPubKeyForAddress:holdingAddress forChain:fundingAccount.wallet.chain];
        [fundingAccount updateTransaction:providerRegistrationTransaction forAmounts:@[@(MASTERNODE_COST)] toOutputScripts:@[script] withFee:YES isInstant:NO];
        
        [providerRegistrationTransaction updateInputsHash];
        
        //there is no need to sign the payload here.
        
        self.status = DSLocalMasternodeStatus_Created;
        
        completion(providerRegistrationTransaction);
    }];
}

// MARK: - Persistence

-(void)save {
    NSManagedObjectContext * context = [DSTransactionEntity context];
    [context performBlockAndWait:^{ // add the transaction to core data
        [DSChainEntity setContext:context];
        [DSLocalMasternodeEntity setContext:context];
        [DSProviderRegistrationTransactionEntity setContext:context];
        if ([DSLocalMasternodeEntity
             countObjectsMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)] == 0) {
            
            DSLocalMasternodeEntity * localMasternode = [DSLocalMasternodeEntity managedObject];
            [localMasternode setAttributesFromLocalMasternode:self];
            [DSLocalMasternodeEntity saveContext];
        } else {
            DSLocalMasternodeEntity * localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)];
            [localMasternode setAttributesFromLocalMasternode:self];
            [DSLocalMasternodeEntity saveContext];
        }
    }];
}

@end
