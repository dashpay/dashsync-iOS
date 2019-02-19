//
//  DSLocalMasternodeEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/14/19.
//
//

#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSLocalMasternode+Protected.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataProperties.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSWallet.h"
#import "DSMasternodeManager.h"

@implementation DSLocalMasternodeEntity

- (DSLocalMasternode*)loadLocalMasternode {
    DSChain * chain = self.providerRegistrationTransaction.chain.chain;
    DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)[self.providerRegistrationTransaction transactionForChain:chain];
    
    return [chain.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction];
}

-(void)setAttributesFromLocalMasternode:(DSLocalMasternode*)localMasternode {
    self.holdingKeysWalletUniqueId = localMasternode.holdingKeysWallet.uniqueID;
    self.holdingKeysIndex = localMasternode.holdingWalletIndex;
    self.votingKeysIndex = localMasternode.votingWalletIndex;
    self.votingKeysWalletUniqueId = localMasternode.votingKeysWallet.uniqueID;
    self.ownerKeysWalletUniqueId = localMasternode.ownerKeysWallet.uniqueID;
    self.ownerKeysIndex = localMasternode.ownerWalletIndex;
    self.operatorKeysIndex = localMasternode.operatorWalletIndex;
    self.operatorKeysWalletUniqueId = localMasternode.operatorKeysWallet.uniqueID;
    
}

@end
