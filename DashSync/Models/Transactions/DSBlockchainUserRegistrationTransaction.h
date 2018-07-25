//
//  DSBlockchainUserRegistrationTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransaction.h"
#import "IntTypes.h"

@interface DSBlockchainUserRegistrationTransaction : DSTransaction

@property (nonatomic,assign) uint16_t blockchainUserRegistrationTransactionVersion;
@property (nonatomic,copy) NSString * username;
@property (nonatomic,assign) UInt160 pubkeyHash;
@property (nonatomic,strong) NSData * signature;

@end
