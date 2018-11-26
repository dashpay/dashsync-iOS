//
//  DSBlockchainUserRegistrationTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainUserRegistrationTransactionEntity+CoreDataClass.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSBlockchainUserRegistrationTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction*)tx;
        self.specialTransactionVersion = blockchainUserRegistrationTransaction.blockchainUserRegistrationTransactionVersion;
        self.publicKey = [NSData dataWithUInt160:blockchainUserRegistrationTransaction.pubkeyHash];
        self.username = blockchainUserRegistrationTransaction.username;
        self.payloadSignature = blockchainUserRegistrationTransaction.payloadSignature;
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSBlockchainUserRegistrationTransaction * transaction = (DSBlockchainUserRegistrationTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionRegistration;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainUserRegistrationTransactionVersion = self.specialTransactionVersion;
        transaction.pubkeyHash = self.publicKey.UInt160;
        transaction.username = self.username;
        transaction.payloadSignature = self.payloadSignature;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainUserRegistrationTransaction class];
}

@end
