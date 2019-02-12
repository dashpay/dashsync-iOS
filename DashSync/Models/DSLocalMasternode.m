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
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#include <arpa/inet.h>

@interface DSLocalMasternode()

@property(nonatomic,assign) UInt128 ipAddress;
@property(nonatomic,assign) uint32_t port;
@property(nonatomic,strong) DSWallet * operatorKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * fundsWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * ownerKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * votingKeysWallet; //only if this is contained in the wallet.

@end

@implementation DSLocalMasternode

-(instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet*)wallet {
    if (!(self = [super init])) return nil;
    self.operatorKeysWallet = wallet;
    self.fundsWallet = wallet;
    self.ownerKeysWallet = wallet;
    self.votingKeysWallet = wallet;
    self.ipAddress = ipAddress;
    self.port = port;
    return self;
}

-(void)registerInAssociatedWallets {
    [self.operatorKeysWallet registerMasternodeOperator:self];
    [self.ownerKeysWallet registerMasternodeOwner:self];
    [self.votingKeysWallet registerMasternodeVoter:self];
}

-(void)registrationTransactionFundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSProviderRegistrationTransaction * providerRegistrationTransaction))completion {
    char s[INET6_ADDRSTRLEN];
    NSString * ipAddressString = @(inet_ntop(AF_INET, &self.ipAddress.u32[3], s, sizeof(s)));
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to register a masternode at %@:%d?", nil),ipAddressString,self.port];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.fundsWallet forAmount:MASTERNODE_COST forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self.fundsWallet];
        if (!providerFundsDerivationPath.hasExtendedPublicKey) {
            [providerFundsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.fundsWallet.uniqueID];
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
        [scriptPayout appendScriptPubKeyForAddress:holdingAddress forChain:self.fundsWallet.chain];
        
        DSKey * ownerKey = [providerOwnerKeysDerivationPath firstUnusedPrivateKeyFromSeed:seed];
        UInt160 votingKeyHash = providerVotingKeysDerivationPath.firstUnusedPublicKey.hash160;
        UInt384 operatorKey = providerOperatorKeysDerivationPath.firstUnusedPublicKey.UInt384;
        DSProviderRegistrationTransaction * providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithProviderRegistrationTransactionVersion:1 type:0 mode:0 collateralOutpoint:DSUTXO_ZERO ipAddress:self.ipAddress port:self.port ownerKeyHash:ownerKey.publicKey.hash160 operatorKey:operatorKey votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:scriptPayout onChain:fundingAccount.wallet.chain];
        
        NSMutableData *script = [NSMutableData data];
        
        [script appendScriptPubKeyForAddress:holdingAddress forChain:fundingAccount.wallet.chain];
        [fundingAccount updateTransaction:providerRegistrationTransaction forAmounts:@[@(MASTERNODE_COST)] toOutputScripts:@[script] withFee:YES isInstant:NO toShapeshiftAddress:nil shuffleOutputOrder:NO];
        
        
        [providerRegistrationTransaction updateInputsHash];
        
        [providerRegistrationTransaction signPayloadWithKey:ownerKey];
        
        completion(providerRegistrationTransaction);
    }];
}

@end
