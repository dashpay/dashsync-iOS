//
//  DSProviderUpdateServiceTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//
//

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSKey.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "NSString+Dash.h"

@implementation DSProviderUpdateServiceTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)tx;
        self.specialTransactionVersion = providerUpdateServiceTransaction.providerUpdateServiceTransactionVersion;
        self.ipAddress = uint128_data(providerUpdateServiceTransaction.ipAddress);
        self.port = providerUpdateServiceTransaction.port;
        self.scriptPayout = providerUpdateServiceTransaction.scriptPayout;
        self.payloadSignature = providerUpdateServiceTransaction.payloadSignature;
        self.providerRegistrationTransactionHash = [NSData dataWithUInt256:providerUpdateServiceTransaction.providerRegistrationTransactionHash];
        NSString *payoutAddress = [NSString addressWithScriptPubKey:self.scriptPayout onChain:tx.chain];

        NSArray *payoutAddressEntities = [DSAddressEntity objectsMatching:@"address == %@ && derivationPath.chain == %@", payoutAddress, tx.chain.chainEntity];
        if ([payoutAddressEntities count]) {
            NSAssert([payoutAddressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[payoutAddressEntities firstObject]];
        }
    }];

    return self;
}

- (DSTransaction *)transactionForChain:(DSChain *)chain {
    DSProviderUpdateServiceTransaction *transaction = (DSProviderUpdateServiceTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_ProviderUpdateService;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.providerUpdateServiceTransactionVersion = self.specialTransactionVersion;
        transaction.providerRegistrationTransactionHash = self.providerRegistrationTransactionHash.UInt256;
        transaction.ipAddress = self.ipAddress.UInt128;
        transaction.port = self.port;
        transaction.scriptPayout = self.scriptPayout;
        transaction.payloadSignature = self.payloadSignature;
    }];

    return transaction;
}

- (Class)transactionClass {
    return [DSProviderUpdateServiceTransaction class];
}

@end
