//
//  DSBlockchainUser.h
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import <Foundation/Foundation.h>

@class DSWallet,DSBlockchainUserRegistrationTransaction,DSBlockchainUserTopupTransaction,DSBlockchainUserResetTransaction,DSAccount,DSChain;

@interface DSBlockchainUser : NSObject

@property (nonatomic,readonly) DSWallet * wallet;
@property (nonatomic,readonly) NSString * uniqueIdentifier;
@property (nonatomic,readonly) UInt256 registrationTransactionHash;
@property (nonatomic,readonly) uint32_t index;
@property (nonatomic,readonly) NSString * username;
@property (nonatomic,readonly) NSString * publicKeyHash;

-(instancetype)initWithUsername:(NSString* _Nonnull)username atIndex:(uint32_t)index inWallet:(DSWallet* _Nonnull)wallet;

-(instancetype)initWithUsername:(NSString* _Nonnull)username atIndex:(uint32_t)index inWallet:(DSWallet* _Nonnull)wallet createdWithTransactionHash:(UInt256)registrationTransactionHash lastBlockchainUserTransactionHash:(UInt256)lastBlockchainUserTransactionHash;

-(void)generateBlockchainUserExtendedPublicKey:(void (^ _Nullable)(BOOL registered))completion;

-(void)registerInWallet;

-(void)registrationTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount* _Nonnull)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction))completion;

-(void)topupTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount* _Nonnull)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction))completion;

-(void)resetTransactionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainUserResetTransaction * blockchainUserResetTransaction))completion;

@end
