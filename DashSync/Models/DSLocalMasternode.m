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
    [self.ownerKeysWallet registerMasternodeOperator:self];
    [self.votingKeysWallet registerMasternodeOperator:self];
}

-(void)registrationTransactionFundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSProviderRegistrationTransaction * providerRegistrationTransaction))completion {
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to register a masternode at %@:%d?", nil),self.ipAddress,self.port];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.fundsWallet forAmount:MASTERNODE_COST forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self.fundsWallet];
        DSDerivationPath * providerOwnerKeysDerivationPath = [DSDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];
        DSDerivationPath * providerOperatorKeysDerivationPath = [DSDerivationPath providerOwnerKeysDerivationPathForWallet:self.operatorKeysWallet];
        DSDerivationPath * providerVotingKeysDerivationPath = [DSDerivationPath providerVotingKeysDerivationPathForWallet:self.votingKeysWallet];
        
        NSString * receiveAddress = [providerFundsDerivationPath receiveAddress];
        
        DSProviderRegistrationTransaction * providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] init];
        [blockchainUserRegistrationTransaction signPayloadWithKey:privateKey];
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:providerRegistrationTransaction forAmounts:@[@(MASTERNODE_COST)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO toShapeshiftAddress:nil];
        
        completion(providerRegistrationTransaction);
    }];
}

@end
