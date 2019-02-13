//
//  DSLocalMasternode.h
//  DashSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSWallet,DSAccount, DSProviderRegistrationTransaction;

@interface DSLocalMasternode : NSObject

@property(nonatomic,readonly) UInt128 ipAddress;
@property(nonatomic,readonly) uint32_t port;
@property(nonatomic,readonly) DSWallet * operatorKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,readonly) uint32_t operatorWalletIndex; //the derivation path index of keys
@property(nonatomic,readonly) DSWallet * fundsWallet; //only if this is contained in the wallet.
@property(nonatomic,readonly) uint32_t fundsWalletIndex;
@property(nonatomic,readonly) DSWallet * ownerKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,readonly) uint32_t ownerWalletIndex;
@property(nonatomic,readonly) DSWallet * votingKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,readonly) uint32_t votingWalletIndex;
@property(nonatomic,readonly) DSProviderRegistrationTransaction * providerRegistrationTransaction;

-(instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet*)wallet;

-(instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet*)wallet inOperatorWallet:(DSWallet*)operatorWallet inOwnerWallet:(DSWallet*)ownerWallet inVotingWallet:(DSWallet*)votingWallet;

-(void)registrationTransactionFundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSProviderRegistrationTransaction * providerRegistrationTransaction))completion;

@end

NS_ASSUME_NONNULL_END
