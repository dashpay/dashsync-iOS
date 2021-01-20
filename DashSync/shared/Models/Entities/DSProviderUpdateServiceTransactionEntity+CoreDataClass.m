//
//  DSProviderUpdateServiceTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//
//

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSKey.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "NSString+Dash.h"

@implementation DSProviderUpdateServiceTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)transaction {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:transaction];
        DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        self.specialTransactionVersion = providerUpdateServiceTransaction.providerUpdateServiceTransactionVersion;
        self.ipAddress = uint128_data(providerUpdateServiceTransaction.ipAddress);
        self.port = providerUpdateServiceTransaction.port;
        self.scriptPayout = providerUpdateServiceTransaction.scriptPayout;
        self.payloadSignature = providerUpdateServiceTransaction.payloadSignature;
        self.providerRegistrationTransactionHash = [NSData dataWithUInt256:providerUpdateServiceTransaction.providerRegistrationTransactionHash];
        NSString *payoutAddress = [NSString addressWithScriptPubKey:self.scriptPayout onChain:transaction.chain];

        NSArray *payoutAddressEntities = [DSAddressEntity objectsInContext:self.managedObjectContext matching:@"address == %@ && derivationPath.chain == %@", payoutAddress, [transaction.chain chainEntityInContext:self.managedObjectContext]];
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
