//
//  DSLocalMasternode.m
//  DashSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import "DSLocalMasternode.h"
#import "BigIntTypes.h"
#import "DSAccount.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSAuthenticationManager.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "DSChainManager.h"
#import "DSECDSAKey.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSMasternodeManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSSporkManager.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTransactionOutput.h"
#import "DSWallet.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#include <arpa/inet.h>

#define MASTERNODE_NAME_KEY @"MASTERNODE_NAME_KEY"

@interface DSLocalMasternode ()

@property (nonatomic, assign) DSSocketAddress socketAddress;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) DSWallet *operatorKeysWallet; //only if this is contained in the wallet.
@property (nonatomic, strong) DSWallet *holdingKeysWallet;  //only if this is contained in the wallet.
@property (nonatomic, strong) DSWallet *ownerKeysWallet;    //only if this is contained in the wallet.
@property (nonatomic, strong) DSWallet *votingKeysWallet;   //only if this is contained in the wallet.
@property (nonatomic, assign) uint32_t operatorWalletIndex; //the derivation path index of keys
@property (nonatomic, assign) uint32_t ownerWalletIndex;
@property (nonatomic, assign) uint32_t votingWalletIndex;
@property (nonatomic, assign) uint32_t holdingWalletIndex;
@property (nonatomic, strong) NSMutableIndexSet *previousOperatorWalletIndexes;
@property (nonatomic, strong) NSMutableIndexSet *previousVotingWalletIndexes;
@property (nonatomic, assign) DSLocalMasternodeStatus status;
@property (nonatomic, strong) DSProviderRegistrationTransaction *providerRegistrationTransaction;
@property (nonatomic, strong) NSMutableArray<DSProviderUpdateRegistrarTransaction *> *providerUpdateRegistrarTransactions;
@property (nonatomic, strong) NSMutableArray<DSProviderUpdateServiceTransaction *> *providerUpdateServiceTransactions;
@property (nonatomic, strong) NSMutableArray<DSProviderUpdateRevocationTransaction *> *providerUpdateRevocationTransactions;

@property (nonatomic, readonly) DSECDSAKey *ownerPrivateKey;

@end

@implementation DSLocalMasternode

- (instancetype)initWithSocketAddress:(DSSocketAddress)socketAddress inWallet:(DSWallet *)wallet {
    if (!(self = [super init])) return nil;
    return [self initWithSocketAddress:socketAddress
                         inFundsWallet:wallet
                      inOperatorWallet:wallet
                         inOwnerWallet:wallet
                        inVotingWallet:wallet];
}
- (instancetype)initWithSocketAddress:(DSSocketAddress)socketAddress inFundsWallet:(DSWallet *)fundsWallet inOperatorWallet:(DSWallet *)operatorWallet inOwnerWallet:(DSWallet *)ownerWallet inVotingWallet:(DSWallet *)votingWallet {
    if (!(self = [super init])) return nil;
    self.operatorKeysWallet = operatorWallet;
    self.holdingKeysWallet = fundsWallet;
    self.ownerKeysWallet = ownerWallet;
    self.votingKeysWallet = votingWallet;
    self.ownerWalletIndex = UINT32_MAX;
    self.operatorWalletIndex = UINT32_MAX;
    self.votingWalletIndex = UINT32_MAX;
    self.holdingWalletIndex = UINT32_MAX;
    self.socketAddress = socketAddress;
    self.providerUpdateRegistrarTransactions = [NSMutableArray array];
    self.providerUpdateServiceTransactions = [NSMutableArray array];
    self.providerUpdateRevocationTransactions = [NSMutableArray array];
    self.previousOperatorWalletIndexes = [NSMutableIndexSet indexSet];
    self.previousVotingWalletIndexes = [NSMutableIndexSet indexSet];
    [self associateName];
    return self;
}

- (instancetype)initWithSocketAddress:(DSSocketAddress)socketAddress inFundsWallet:(DSWallet *_Nullable)fundsWallet fundsWalletIndex:(uint32_t)fundsWalletIndex inOperatorWallet:(DSWallet *_Nullable)operatorWallet operatorWalletIndex:(uint32_t)operatorWalletIndex inOwnerWallet:(DSWallet *_Nullable)ownerWallet ownerWalletIndex:(uint32_t)ownerWalletIndex inVotingWallet:(DSWallet *_Nullable)votingWallet votingWalletIndex:(uint32_t)votingWalletIndex {
    if (!(self = [super init])) return nil;
    self.operatorKeysWallet = operatorWallet;
    self.holdingKeysWallet = fundsWallet;
    self.ownerKeysWallet = ownerWallet;
    self.votingKeysWallet = votingWallet;
    self.ownerWalletIndex = ownerWalletIndex;
    self.operatorWalletIndex = operatorWalletIndex;
    self.votingWalletIndex = votingWalletIndex;
    self.holdingWalletIndex = fundsWalletIndex;
    self.socketAddress = socketAddress;
    self.providerUpdateRegistrarTransactions = [NSMutableArray array];
    self.providerUpdateServiceTransactions = [NSMutableArray array];
    self.providerUpdateRevocationTransactions = [NSMutableArray array];
    self.previousOperatorWalletIndexes = [NSMutableIndexSet indexSet];
    self.previousVotingWalletIndexes = [NSMutableIndexSet indexSet];
    [self associateName];
    return self;
}


- (instancetype)initWithProviderTransactionRegistration:(DSProviderRegistrationTransaction *)providerRegistrationTransaction {
    if (!(self = [super init])) return nil;
    uint32_t ownerAddressIndex;
    uint32_t votingAddressIndex;
    uint32_t operatorAddressIndex;
    uint32_t holdingAddressIndex;
    DSWallet *ownerWallet = [providerRegistrationTransaction.chain walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:&ownerAddressIndex];
    DSWallet *votingWallet = [providerRegistrationTransaction.chain walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:&votingAddressIndex];
    DSWallet *operatorWallet = [providerRegistrationTransaction.chain walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:&operatorAddressIndex];
    DSWallet *holdingWallet = [providerRegistrationTransaction.chain walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:&holdingAddressIndex];
    //DSLogPrivate(@"%@",[uint160_data(providerRegistrationTransaction.ownerKeyHash) addressFromHash160DataForChain:providerRegistrationTransaction.chain]);
    self.operatorKeysWallet = operatorWallet;
    self.holdingKeysWallet = holdingWallet;
    self.ownerKeysWallet = ownerWallet;
    self.votingKeysWallet = votingWallet;
    self.ownerWalletIndex = ownerAddressIndex;
    self.operatorWalletIndex = operatorAddressIndex;
    self.votingWalletIndex = votingAddressIndex;
    self.holdingWalletIndex = holdingAddressIndex;
    self.socketAddress = (DSSocketAddress){providerRegistrationTransaction.ipAddress, providerRegistrationTransaction.port};
    self.providerRegistrationTransaction = providerRegistrationTransaction;
    self.providerUpdateRegistrarTransactions = [NSMutableArray array];
    self.providerUpdateServiceTransactions = [NSMutableArray array];
    self.providerUpdateRevocationTransactions = [NSMutableArray array];
    self.previousOperatorWalletIndexes = [NSMutableIndexSet indexSet];
    self.previousVotingWalletIndexes = [NSMutableIndexSet indexSet];
    self.status = DSLocalMasternodeStatus_Registered; //because it comes from a transaction already
    [self associateName];
    return self;
}

- (void)registerInAssociatedWallets {
    [self.operatorKeysWallet registerMasternodeOperator:self];
    [self.ownerKeysWallet registerMasternodeOwner:self];
    [self.votingKeysWallet registerMasternodeVoter:self];
}

- (BOOL)forceOperatorPublicKey:(DSBLSKey *)operatorPublicKey {
    if (self.operatorWalletIndex != UINT32_MAX) return NO;
    [self.ownerKeysWallet registerMasternodeOperator:self withOperatorPublicKey:operatorPublicKey];
    return YES;
}

- (BOOL)forceOwnerPrivateKey:(DSECDSAKey *)ownerPrivateKey {
    if (self.ownerWalletIndex != UINT32_MAX) return NO;
    if (![ownerPrivateKey hasPrivateKey]) return NO;
    [self.ownerKeysWallet registerMasternodeOwner:self withOwnerPrivateKey:ownerPrivateKey];
    return YES;
}

//the voting key can either be private or public key
- (BOOL)forceVotingKey:(DSECDSAKey *)votingKey {
    if (self.votingWalletIndex != UINT32_MAX) return NO;
    [self.ownerKeysWallet registerMasternodeVoter:self withVotingKey:votingKey];
    return YES;
}

- (BOOL)noLocalWallet {
    return !(self.operatorKeysWallet || self.holdingKeysWallet || self.ownerKeysWallet || self.votingKeysWallet);
}

- (DSSocketAddress)socketAddress {
    if ([self.providerUpdateServiceTransactions count]) {
        return [self.providerUpdateServiceTransactions lastObject].masternodeSocketAddress;
    }
    if (self.providerRegistrationTransaction) {
        return (DSSocketAddress){self.providerRegistrationTransaction.ipAddress, self.providerRegistrationTransaction.port};
    }
    return _socketAddress;
}

- (DSChain *)chain {
    if (self.providerRegistrationTransaction) {
        return self.providerRegistrationTransaction.chain;
    }
    if (self.operatorKeysWallet) {
        return self.operatorKeysWallet.chain;
    }
    if (self.ownerKeysWallet) {
        return self.ownerKeysWallet.chain;
    }
    if (self.votingKeysWallet) {
        return self.votingKeysWallet.chain;
    }
    if (self.holdingKeysWallet) {
        return self.holdingKeysWallet.chain;
    }

    NSAssert(NO, @"A chain should have been found at this point");

    return nil;
}

- (NSString *)ipAddressString {
    char s[INET6_ADDRSTRLEN];
    NSString *ipAddressString = @(inet_ntop(AF_INET, &self.socketAddress.ipAddress.u32[3], s, sizeof(s)));
    return ipAddressString;
}

- (NSString *)ipAddressAndPortString {
    return [NSString stringWithFormat:@"%@:%d", self.ipAddressString, self.socketAddress.port];
}

- (NSString *)ipAddressAndIfNonstandardPortString {
    DSChain *chain = self.chain;
    if (chain.isMainnet && self.socketAddress.port == self.providerRegistrationTransaction.chain.standardPort) {
        return self.ipAddressString;
    } else {
        return self.ipAddressAndPortString;
    }
}

- (NSString *)portString {
    return [NSString stringWithFormat:@"%d", self.socketAddress.port];
}

- (NSString *)payoutAddress {
    if ([self.providerUpdateRegistrarTransactions count]) {
        return [NSString addressWithScriptPubKey:[self.providerUpdateRegistrarTransactions lastObject].scriptPayout onChain:self.providerRegistrationTransaction.chain];
    }
    if (self.providerRegistrationTransaction) {
        return [NSString addressWithScriptPubKey:self.providerRegistrationTransaction.scriptPayout onChain:self.providerRegistrationTransaction.chain];
    }
    return nil;
}

- (NSString *)operatorPayoutAddress {
    if ([self.providerUpdateServiceTransactions count]) {
        return [NSString addressWithScriptPubKey:[self.providerUpdateServiceTransactions lastObject].scriptPayout onChain:self.providerRegistrationTransaction.chain];
    }
    return nil;
}

- (DSBLSKey *)operatorKeyFromSeed:(NSData *)seed {
    DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];

    return (DSBLSKey *)[providerOperatorKeysDerivationPath privateKeyForHash160:[[NSData dataWithUInt384:self.providerRegistrationTransaction.operatorKey] hash160] fromSeed:seed];
}

- (NSString *)operatorKeyStringFromSeed:(NSData *)seed {
    DSBLSKey *blsKey = [self operatorKeyFromSeed:seed];
    return [blsKey secretKeyString];
}

- (DSECDSAKey *)ownerKeyFromSeed:(NSData *)seed {
    if (!self.ownerKeysWallet) {
        return nil;
    }
    if (!seed) {
        return nil;
    }
    DSAuthenticationKeysDerivationPath *providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];

    return (DSECDSAKey *)[providerOwnerKeysDerivationPath privateKeyForHash160:self.providerRegistrationTransaction.ownerKeyHash fromSeed:seed];
}

- (NSString *)ownerKeyStringFromSeed:(NSData *)seed {
    DSECDSAKey *ecdsaKey = [self ownerKeyFromSeed:seed];
    if (!ecdsaKey) return nil;
    return [ecdsaKey secretKeyString];
}

- (DSECDSAKey *)votingKeyFromSeed:(NSData *)seed {
    if (!self.votingKeysWallet) {
        return nil;
    }
    if (!seed) {
        return nil;
    }
    DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self.votingKeysWallet];

    return (DSECDSAKey *)[providerVotingKeysDerivationPath privateKeyForHash160:self.providerRegistrationTransaction.votingKeyHash fromSeed:seed];
}

- (NSData *)ownerPublicKeyData {
    if (self.ownerKeysWallet) {
        DSAuthenticationKeysDerivationPath *providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];
        return [providerOwnerKeysDerivationPath publicKeyDataForHash160:self.providerRegistrationTransaction.ownerKeyHash];
    } else {
        return [NSData data];
    }
}

- (NSData *)operatorPublicKeyData {
    if (self.operatorKeysWallet) {
        DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];
        return [providerOperatorKeysDerivationPath publicKeyDataForHash160:[[NSData dataWithUInt384:self.providerRegistrationTransaction.operatorKey] hash160]];
    } else {
        return [NSData data];
    }
}

- (NSData *)votingPublicKeyData {
    if (self.votingKeysWallet) {
        DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self.votingKeysWallet];
        return [providerVotingKeysDerivationPath publicKeyDataForHash160:self.providerRegistrationTransaction.votingKeyHash];
    } else {
        return [NSData data];
    }
}

- (NSString *)votingKeyStringFromSeed:(NSData *)seed {
    DSECDSAKey *ecdsaKey = [self votingKeyFromSeed:seed];
    if (!ecdsaKey) return nil;
    return [ecdsaKey secretKeyString];
}

// MARK: - Named Masternodes

- (NSString *)masternodeIdentifierForNameStorage {
    return [NSString stringWithFormat:@"%@%@", MASTERNODE_NAME_KEY, uint256_hex(_providerRegistrationTransaction.txHash)];
}

- (void)associateName {
    NSError *error = nil;
    NSString *name = getKeychainString([self masternodeIdentifierForNameStorage], &error);
    if (!error) {
        self.name = name;
    }
}

- (void)registerName:(NSString *)name {
    if (![_name isEqualToString:name]) {
        setKeychainString(name, [self masternodeIdentifierForNameStorage], NO);
        self.name = name;
    }
}

// MARK: - Generating Transactions

- (void)registrationTransactionFundedByAccount:(DSAccount *)fundingAccount toAddress:(NSString *)payoutAddress completion:(void (^_Nullable)(DSProviderRegistrationTransaction *providerRegistrationTransaction))completion {
    [self registrationTransactionFundedByAccount:fundingAccount toAddress:payoutAddress withCollateral:DSUTXO_ZERO completion:completion];
}

- (void)registrationTransactionFundedByAccount:(DSAccount *)fundingAccount toAddress:(NSString *)payoutAddress withCollateral:(DSUTXO)collateral completion:(void (^_Nullable)(DSProviderRegistrationTransaction *providerRegistrationTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_New) return;
    char s[INET6_ADDRSTRLEN];
    NSString *ipAddressString = @(inet_ntop(AF_INET, &self.socketAddress.ipAddress.u32[3], s, sizeof(s)));
    NSString *question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to register a masternode at %@:%d?", nil), ipAddressString, self.socketAddress.port];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question
                                                   forWallet:fundingAccount.wallet
                                                   forAmount:MASTERNODE_COST
                                         forceAuthentication:YES
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                                      if (!seed) {
                                                          completion(nil);
                                                          return;
                                                      }

                                                      NSMutableData *script = [NSMutableData data];

                                                      [script appendScriptPubKeyForAddress:payoutAddress forChain:fundingAccount.wallet.chain];

                                                      DSMasternodeHoldingsDerivationPath *providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self.holdingKeysWallet];
                                                      if (!providerFundsDerivationPath.hasExtendedPublicKey) {
                                                          [providerFundsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.holdingKeysWallet.uniqueIDString];
                                                      }
                                                      DSAuthenticationKeysDerivationPath *providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];
                                                      if (!providerOwnerKeysDerivationPath.hasExtendedPublicKey) {
                                                          [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.ownerKeysWallet.uniqueIDString];
                                                      }
                                                      DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];
                                                      if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
                                                          [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.operatorKeysWallet.uniqueIDString];
                                                      }
                                                      DSECDSAKey *ownerKey;
                                                      if (self.ownerWalletIndex == UINT32_MAX) {
                                                          self.ownerWalletIndex = (uint32_t)[providerOwnerKeysDerivationPath firstUnusedIndex];
                                                          ownerKey = (DSECDSAKey *)[providerOwnerKeysDerivationPath firstUnusedPrivateKeyFromSeed:seed];
                                                      } else {
                                                          ownerKey = (DSECDSAKey *)[providerOwnerKeysDerivationPath privateKeyAtIndex:self.ownerWalletIndex fromSeed:seed];
                                                      }

                                                      UInt160 votingKeyHash;

                                                      UInt160 ownerKeyHash = ownerKey.publicKeyData.hash160;

                                                      if ([fundingAccount.wallet.chain.chainManager.sporkManager deterministicMasternodeListEnabled]) {
                                                          DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self.votingKeysWallet];
                                                          if (!providerVotingKeysDerivationPath.hasExtendedPublicKey) {
                                                              [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.votingKeysWallet.uniqueIDString];
                                                          }
                                                          if (self.votingWalletIndex == UINT32_MAX) {
                                                              self.votingWalletIndex = (uint32_t)[providerVotingKeysDerivationPath firstUnusedIndex];
                                                              votingKeyHash = [providerVotingKeysDerivationPath firstUnusedPublicKey].hash160;
                                                          } else {
                                                              votingKeyHash = [providerVotingKeysDerivationPath publicKeyDataAtIndex:self.votingWalletIndex].hash160;
                                                          }
                                                      } else {
                                                          votingKeyHash = ownerKeyHash;
                                                          self.votingWalletIndex = UINT32_MAX;
                                                      }

                                                      UInt384 operatorKey;
                                                      if (self.operatorWalletIndex == UINT32_MAX) {
                                                          self.operatorWalletIndex = (uint32_t)[providerOperatorKeysDerivationPath firstUnusedIndex];
                                                          operatorKey = [providerOperatorKeysDerivationPath firstUnusedPublicKey].UInt384;
                                                      } else {
                                                          operatorKey = [providerOperatorKeysDerivationPath publicKeyDataAtIndex:self.operatorWalletIndex].UInt384;
                                                      }

                                                      DSProviderRegistrationTransaction *providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithProviderRegistrationTransactionVersion:1 type:0 mode:0 collateralOutpoint:collateral masternodeSocketAddress:self.socketAddress ownerKeyHash:ownerKeyHash operatorKey:operatorKey votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:script onChain:fundingAccount.wallet.chain];


                                                      if (dsutxo_is_zero(collateral)) {
                                                          NSString *holdingAddress = [providerFundsDerivationPath receiveAddress];
                                                          NSMutableData *scriptPayout = [NSMutableData data];
                                                          [scriptPayout appendScriptPubKeyForAddress:holdingAddress forChain:self.holdingKeysWallet.chain];

                                                          [fundingAccount updateTransaction:providerRegistrationTransaction forAmounts:@[@(MASTERNODE_COST)] toOutputScripts:@[scriptPayout] withFee:YES];

                                                      } else {
                                                          [fundingAccount updateTransaction:providerRegistrationTransaction forAmounts:@[] toOutputScripts:@[] withFee:YES];
                                                      }

                                                      [providerRegistrationTransaction updateInputsHash];

                                                      //there is no need to sign the payload here.

                                                      self.status = DSLocalMasternodeStatus_Created;

                                                      completion(providerRegistrationTransaction);
                                                  }];
}

- (void)updateTransactionForResetFundedByAccount:(DSAccount *)fundingAccount completion:(void (^_Nullable)(DSProviderUpdateServiceTransaction *providerRegistrationTransaction))completion {
    [self updateTransactionFundedByAccount:fundingAccount toSocketAddress:self.socketAddress payoutAddress:self.operatorPayoutAddress completion:completion];
}

- (void)updateTransactionFundedByAccount:(DSAccount *)fundingAccount toSocketAddress:(DSSocketAddress)socketAddress payoutAddress:(NSString *)payoutAddress completion:(void (^_Nullable)(DSProviderUpdateServiceTransaction *providerRegistrationTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_Registered) return;
    char s[INET6_ADDRSTRLEN];
    NSString *ipAddressString = @(inet_ntop(AF_INET, &socketAddress.ipAddress.u32[3], s, sizeof(s)));
    NSString *question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to update this masternode to %@:%d?", nil), ipAddressString, self.socketAddress.port];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question
                                                   forWallet:fundingAccount.wallet
                                                   forAmount:0
                                         forceAuthentication:YES
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                                      if (!seed) {
                                                          completion(nil);
                                                          return;
                                                      }
                                                      NSData *scriptPayout;
                                                      if (payoutAddress == nil) {
                                                          scriptPayout = [NSData data];
                                                      } else {
                                                          NSMutableData *mScriptPayout = [NSMutableData data];
                                                          [mScriptPayout appendScriptPubKeyForAddress:payoutAddress forChain:fundingAccount.wallet.chain];
                                                          scriptPayout = mScriptPayout;
                                                      }

                                                      DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];

                                                      NSAssert(self.providerRegistrationTransaction, @"There must be a providerRegistrationTransaction linked here");
                                                      DSBLSKey *operatorKey = (DSBLSKey *)[providerOperatorKeysDerivationPath privateKeyForHash160:[[NSData dataWithUInt384:self.providerRegistrationTransaction.operatorKey] hash160] fromSeed:seed];

                                                      DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = [[DSProviderUpdateServiceTransaction alloc] initWithProviderUpdateServiceTransactionVersion:1 providerTransactionHash:self.providerRegistrationTransaction.txHash masternodeSocketAddress:socketAddress scriptPayout:scriptPayout onChain:fundingAccount.wallet.chain];

                                                      [fundingAccount updateTransaction:providerUpdateServiceTransaction forAmounts:@[] toOutputScripts:@[] withFee:YES];

                                                      [providerUpdateServiceTransaction signPayloadWithKey:operatorKey];

                                                      //there is no need to sign the payload here.

                                                      completion(providerUpdateServiceTransaction);
                                                  }];
}

- (void)updateTransactionFundedByAccount:(DSAccount *)fundingAccount changeOperator:(UInt384)operatorKey changeVotingKeyHash:(UInt160)votingKeyHash changePayoutAddress:(NSString *_Nullable)payoutAddress completion:(void (^_Nullable)(DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_Registered) return;
    NSString *question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to update this masternode to pay to %@?", nil), payoutAddress];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question
                                                   forWallet:fundingAccount.wallet
                                                   forAmount:0
                                         forceAuthentication:YES
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                                      if (!seed) {
                                                          completion(nil);
                                                          return;
                                                      }
                                                      NSData *scriptPayout;
                                                      if (payoutAddress == nil) {
                                                          scriptPayout = [NSData data];
                                                      } else {
                                                          NSMutableData *mScriptPayout = [NSMutableData data];
                                                          [mScriptPayout appendScriptPubKeyForAddress:payoutAddress forChain:fundingAccount.wallet.chain];
                                                          scriptPayout = mScriptPayout;
                                                      }

                                                      DSAuthenticationKeysDerivationPath *providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];

                                                      NSAssert(self.providerRegistrationTransaction, @"There must be a providerRegistrationTransaction linked here");
                                                      DSECDSAKey *ownerKey = (DSECDSAKey *)[providerOwnerKeysDerivationPath privateKeyForHash160:self.providerRegistrationTransaction.ownerKeyHash fromSeed:seed];

                                                      DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction = [[DSProviderUpdateRegistrarTransaction alloc] initWithProviderUpdateRegistrarTransactionVersion:1 providerTransactionHash:self.providerRegistrationTransaction.txHash mode:0 operatorKey:operatorKey votingKeyHash:votingKeyHash scriptPayout:scriptPayout onChain:fundingAccount.wallet.chain];


                                                      [fundingAccount updateTransaction:providerUpdateRegistrarTransaction forAmounts:@[] toOutputScripts:@[] withFee:YES];

                                                      [providerUpdateRegistrarTransaction signPayloadWithKey:ownerKey];

                                                      //there is no need to sign the payload here.

                                                      completion(providerUpdateRegistrarTransaction);
                                                  }];
}

// MARK: - Update from Transaction

- (void)reclaimTransactionToAccount:(DSAccount *)fundingAccount completion:(void (^_Nullable)(DSTransaction *reclaimTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_Registered) return;
    NSString *question = DSLocalizedString(@"Are you sure you would like to reclaim this masternode?", nil);
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question
                                                   forWallet:fundingAccount.wallet
                                                   forAmount:0
                                         forceAuthentication:YES
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                                      if (!seed) {
                                                          completion(nil);
                                                          return;
                                                      }
                                                      NSInteger index = [self.providerRegistrationTransaction masternodeOutputIndex];
                                                      if (index == NSNotFound) {
                                                          completion(nil);
                                                          return;
                                                      }
                                                      NSData *script = [NSMutableData scriptPubKeyForAddress:self.providerRegistrationTransaction.outputs[index].address
                                                                                                    forChain:self.providerRegistrationTransaction.chain];
                                                      uint64_t fee = [self.providerRegistrationTransaction.chain feeForTxSize:194]; // assume we will add a change output
                                                      DSTransaction *reclaimTransaction = [[DSTransaction alloc] initWithInputHashes:@[uint256_obj(self.providerRegistrationTransaction.txHash)] inputIndexes:@[@(index)] inputScripts:@[script] outputAddresses:@[fundingAccount.changeAddress] outputAmounts:@[@(MASTERNODE_COST - fee)] onChain:self.providerRegistrationTransaction.chain];

                                                      //there is no need to sign the payload here.
                                                      completion(reclaimTransaction);
                                                  }];
}


- (void)updateWithUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction *)providerUpdateRegistrarTransaction save:(BOOL)save {
    if (![_providerUpdateRegistrarTransactions containsObject:providerUpdateRegistrarTransaction]) {
        [_providerUpdateRegistrarTransactions addObject:providerUpdateRegistrarTransaction];

        uint32_t operatorNewWalletIndex;
        if (self.operatorKeysWallet) {
            DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];
            operatorNewWalletIndex = (uint32_t)[providerOperatorKeysDerivationPath indexOfKnownAddress:providerUpdateRegistrarTransaction.operatorAddress];
        } else {
            DSWallet *operatorKeysWallet = [self.chain walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:&operatorNewWalletIndex];
            if (operatorKeysWallet) {
                self.operatorKeysWallet = operatorKeysWallet;
            }
        }

        if (self.operatorKeysWallet && (self.operatorWalletIndex != operatorNewWalletIndex)) {
            if (self.operatorWalletIndex != UINT32_MAX && ![self.previousOperatorWalletIndexes containsIndex:self.operatorWalletIndex]) {
                [self.previousOperatorWalletIndexes addIndex:self.operatorWalletIndex];
            }
            if ([self.previousOperatorWalletIndexes containsIndex:operatorNewWalletIndex]) {
                [self.previousOperatorWalletIndexes removeIndex:operatorNewWalletIndex];
            }
            self.operatorWalletIndex = operatorNewWalletIndex;
        }

        uint32_t votingNewWalletIndex;
        if (self.votingKeysWallet) {
            DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self.votingKeysWallet];
            votingNewWalletIndex = (uint32_t)[providerVotingKeysDerivationPath indexOfKnownAddress:providerUpdateRegistrarTransaction.votingAddress];
        } else {
            DSWallet *votingKeysWallet = [self.chain walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:&votingNewWalletIndex];
            if (votingKeysWallet) {
                self.votingKeysWallet = votingKeysWallet;
            }
        }

        if (self.votingKeysWallet && (self.votingWalletIndex != votingNewWalletIndex)) {
            if (self.votingWalletIndex != UINT32_MAX && ![self.previousVotingWalletIndexes containsIndex:self.votingWalletIndex]) {
                [self.previousVotingWalletIndexes addIndex:self.votingWalletIndex];
            }
            if ([self.previousVotingWalletIndexes containsIndex:votingNewWalletIndex]) {
                [self.previousVotingWalletIndexes removeIndex:votingNewWalletIndex];
            }
            self.votingWalletIndex = votingNewWalletIndex;
        }

        if (save) {
            [self save];
        }
    }
}

- (void)updateWithUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction *)providerUpdateRevocationTransaction save:(BOOL)save {
    if (![_providerUpdateRevocationTransactions containsObject:providerUpdateRevocationTransaction]) {
        [_providerUpdateRevocationTransactions addObject:providerUpdateRevocationTransaction];
        if (save) {
            [self save];
        }
    }
}

- (void)updateWithUpdateServiceTransaction:(DSProviderUpdateServiceTransaction *)providerUpdateServiceTransaction save:(BOOL)save {
    if (![_providerUpdateServiceTransactions containsObject:providerUpdateServiceTransaction]) {
        [_providerUpdateServiceTransactions addObject:providerUpdateServiceTransaction];
        self.socketAddress = providerUpdateServiceTransaction.masternodeSocketAddress;
        if (save) {
            [self save];
        }
    }
}

// MARK: - Persistence

- (void)save {
    [self saveInContext:[NSManagedObjectContext chainContext]];
}

- (void)saveInContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{ // add the transaction to core data
        if ([DSLocalMasternodeEntity
                countObjectsInContext:context
                             matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)] == 0) {
            DSProviderRegistrationTransactionEntity *providerRegistrationTransactionEntity = [DSProviderRegistrationTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)];
            if (!providerRegistrationTransactionEntity) {
                [self.providerRegistrationTransaction save];
            }
            DSLocalMasternodeEntity *localMasternode = [DSLocalMasternodeEntity managedObjectInBlockedContext:context];
            [localMasternode setAttributesFromLocalMasternode:self];
            [context ds_save];
        } else {
            DSLocalMasternodeEntity *localMasternode = [DSLocalMasternodeEntity anyObjectInContext:context matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)];
            [localMasternode setAttributesFromLocalMasternode:self];
            [context ds_save];
        }
    }];
}

@end
