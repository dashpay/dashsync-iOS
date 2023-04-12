//
//  DSProviderRegistrationTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//
//

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSKeyManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSString+Dash.h"

@implementation DSProviderRegistrationTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)transaction {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:transaction];
        DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
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

        NSString *ownerAddress = [self.ownerKeyHash addressFromHash160DataForChain:transaction.chain];
        NSString *operatorAddress = [DSKeyManager addressWithPublicKeyData:self.operatorKey forChain:transaction.chain];
//        NSString *operatorAddress = [DSKey addressWithPublicKeyData:self.operatorKey forChain:transaction.chain];
        NSString *votingAddress = [self.votingKeyHash addressFromHash160DataForChain:transaction.chain];
        NSString *payoutAddress = [NSString addressWithScriptPubKey:self.scriptPayout onChain:transaction.chain];

        NSArray *ownerAddressEntities = [DSAddressEntity objectsInContext:self.managedObjectContext matching:@"address == %@ && derivationPath.chain == %@", ownerAddress, [transaction.chain chainEntityInContext:self.managedObjectContext]];
        if ([ownerAddressEntities count]) {
            NSAssert([ownerAddressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[ownerAddressEntities firstObject]];
        }

        NSArray *operatorAddressEntities = [DSAddressEntity objectsInContext:self.managedObjectContext matching:@"address == %@ && derivationPath.chain == %@", operatorAddress, [transaction.chain chainEntityInContext:self.managedObjectContext]];
        if ([operatorAddressEntities count]) {
            NSAssert([operatorAddressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[operatorAddressEntities firstObject]];
        }

        NSArray *votingAddressEntities = [DSAddressEntity objectsInContext:self.managedObjectContext matching:@"address == %@ && derivationPath.chain == %@", votingAddress, [transaction.chain chainEntityInContext:self.managedObjectContext]];
        if ([votingAddressEntities count]) {
            NSAssert([votingAddressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[votingAddressEntities firstObject]];
        }

        NSArray *payoutAddressEntities = [DSAddressEntity objectsInContext:self.managedObjectContext matching:@"address == %@ && derivationPath.chain == %@", payoutAddress, [transaction.chain chainEntityInContext:self.managedObjectContext]];
        if ([payoutAddressEntities count]) {
            NSAssert([payoutAddressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[payoutAddressEntities firstObject]];
        }
    }];

    return self;
}

- (DSTransaction *)transactionForChain:(DSChain *)chain {
    DSProviderRegistrationTransaction *transaction = (DSProviderRegistrationTransaction *)[super transactionForChain:chain];
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

- (Class)transactionClass {
    return [DSProviderRegistrationTransaction class];
}

@end
