//
//  DSLocalMasternode+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/14/19.
//

#import "DSLocalMasternode.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSLocalMasternode ()

- (instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint16_t)port inWallet:(DSWallet *)wallet;

- (instancetype)initWithIPAddress:(UInt128)ipAddress
                           onPort:(uint16_t)port
                    inFundsWallet:(DSWallet *)wallet
                 inOperatorWallet:(DSWallet *)operatorWallet
                    inOwnerWallet:(DSWallet *)ownerWallet
                   inVotingWallet:(DSWallet *)votingWallet
             inPlatformNodeWallet:(DSWallet *)platformNodeWallet;

- (instancetype)initWithIPAddress:(UInt128)ipAddress
                           onPort:(uint16_t)port
                    inFundsWallet:(DSWallet *_Nullable)wallet
                 fundsWalletIndex:(uint32_t)fundsWalletIndex
                 inOperatorWallet:(DSWallet *_Nullable)operatorWallet
              operatorWalletIndex:(uint32_t)operatorWalletIndex
                    inOwnerWallet:(DSWallet *_Nullable)ownerWallet
                 ownerWalletIndex:(uint32_t)ownerWalletIndex
                   inVotingWallet:(DSWallet *_Nullable)votingWallet
                votingWalletIndex:(uint32_t)votingWalletIndex
             inPlatformNodeWallet:(DSWallet *_Nullable)platformNodeWallet
          platformNodeWalletIndex:(uint32_t)platformNodeWalletIndex;
;

- (instancetype)initWithProviderTransactionRegistration:(DSProviderRegistrationTransaction *)providerRegistrationTransaction;

- (void)updateWithUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction *)providerUpdateRegistrarTransaction save:(BOOL)save;

- (void)updateWithUpdateServiceTransaction:(DSProviderUpdateServiceTransaction *)providerUpdateServiceTransaction save:(BOOL)save;

- (void)updateWithUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction *)providerUpdateRevocationTransaction save:(BOOL)save;

@end

NS_ASSUME_NONNULL_END
