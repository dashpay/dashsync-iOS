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

typedef NS_ENUM(NSUInteger, DSLocalMasternodeStatus) {
    DSLocalMasternodeStatus_New = 0,
    DSLocalMasternodeStatus_Created = 1,
    DSLocalMasternodeStatus_Registered = 2,
};

@interface DSLocalMasternode : NSObject

@property(nonatomic,readonly) UInt128 ipAddress;
@property(nonatomic,readonly) uint32_t port;
@property(nonatomic,readonly) DSWallet * operatorKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,readonly) uint32_t operatorWalletIndex; //the derivation path index of keys
@property(nonatomic,readonly) DSWallet * ownerKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,readonly) uint32_t ownerWalletIndex;
@property(nonatomic,readonly) DSWallet * votingKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,readonly) uint32_t votingWalletIndex;
@property(nonatomic,readonly) DSWallet * holdingKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,readonly) uint32_t holdingWalletIndex;
@property(nonatomic,readonly) NSString* payoutAddress;
@property(nonatomic,readonly) DSProviderRegistrationTransaction * providerRegistrationTransaction;
@property(nonatomic,readonly) DSLocalMasternodeStatus status;

-(void)registrationTransactionFundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSProviderRegistrationTransaction * providerRegistrationTransaction))completion;

-(void)updateTransactionFundedByAccount:(DSAccount*)fundingAccount toIPAddress:(UInt128)ipAddress port:(uint32_t)port payoutAddress:(NSString*)payoutAddress completion:(void (^ _Nullable)(DSProviderRegistrationTransaction * providerRegistrationTransaction))completion;

-(void)save;

@end

NS_ASSUME_NONNULL_END
