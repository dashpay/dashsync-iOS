//
//  DSBlockchainUser.h
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import <Foundation/Foundation.h>

@class DSWallet,DSBlockchainUserRegistrationTransaction,DSAccount,DSChain;

@interface DSBlockchainUser : NSObject

@property (nonatomic,readonly) DSWallet * wallet;
@property (nonatomic,readonly) NSString * uniqueIdentifier;
@property (nonatomic,readonly) UInt256 registrationTransactionHash;
@property (nonatomic,readonly) uint32_t index;
@property (nonatomic,readonly) NSString * username;
@property (nonatomic,readonly) NSString * publicKeyHash;

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet;

-(void)registerBlockchainUser:(void (^ _Nullable)(BOOL registered))completion;

-(void)registrationTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount* _Nonnull)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction))completion;

@end
