//
//  DSBlockchainUserRegistrationTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransaction.h"
#import "IntTypes.h"

@class DSKey;

@interface DSBlockchainUserRegistrationTransaction : DSTransaction

@property (nonatomic,readonly) uint16_t blockchainUserRegistrationTransactionVersion;
@property (nonatomic,readonly) NSString * username;
@property (nonatomic,readonly) NSString * amount;
@property (nonatomic,readonly) UInt160 pubkeyHash;
@property (nonatomic,readonly) NSData * signature;
@property (nonatomic,readonly) UInt256 payloadHash;

-(instancetype)initWithBlockchainUserRegistrationTransactionVersion:(uint16_t)version username:(NSString* _Nonnull)username pubkeyHash:(UInt160)pubkeyHash onChain:(DSChain * _Nonnull)chain;

-(void)signPayloadWithKey:(DSKey* _Nonnull)privateKey;

-(BOOL)checkPayloadSignature;

@end
