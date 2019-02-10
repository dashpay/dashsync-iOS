//
//  DSProviderRegistrationTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//
//

#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSProviderRegistrationTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction*)tx;
        self.specialTransactionVersion = providerRegistrationTransaction.providerRegistrationTransactionVersion;
        self.providerType = providerRegistrationTransaction.providerType;
        self.providerMode = providerRegistrationTransaction.providerMode;
        self.collateralOutpoint = dsutxo_data(providerRegistrationTransaction.collateralOutpoint);
        self.ipAddress = uint128_data(providerRegistrationTransaction.ipAddress);
        self.port = providerRegistrationTransaction.port;
        self.ownerKeyHash = uint160_data(providerRegistrationTransaction.ownerKeyHash);
        self.operatorKey = uint384_data(providerRegistrationTransaction.operatorKey);
        self.votingKeyHash = uint160_data(providerRegistrationTransaction.votingKeyHash);
        self.operatorReward = providerRegistrationTransaction.operatorReward;
        self.scriptPayout = providerRegistrationTransaction.scriptPayout;
        self.payloadSignature = providerRegistrationTransaction.payloadSignature;
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSProviderRegistrationTransaction * transaction = (DSProviderRegistrationTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_ProviderRegistration;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.providerRegistrationTransactionVersion = self.specialTransactionVersion;
        transaction.providerType = self.providerType;
        transaction.providerMode = self.providerMode;
        transaction.collateralOutpoint = self.collateralOutpoint.transactionOutpoint;
        transaction.ipAddress = self.ipAddress.UInt128;
        transaction.port = self.port;
        transaction.ownerKeyHash = self.ownerKeyHash.UInt160;
        transaction.operatorKey = self.operatorKey.UInt384;
        transaction.votingKeyHash = self.votingKeyHash.UInt160;
        transaction.operatorReward = self.operatorReward;
        transaction.scriptPayout = self.scriptPayout;
        transaction.payloadSignature = self.payloadSignature;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSProviderRegistrationTransaction class];
}

@end
