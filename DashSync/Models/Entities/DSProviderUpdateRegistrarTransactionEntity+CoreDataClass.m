//
//  DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/22/19.
//
//

#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "DSKey.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChain.h"
#import "NSString+Dash.h"

@implementation DSProviderUpdateRegistrarTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction*)tx;
        self.specialTransactionVersion = providerUpdateRegistrarTransaction.providerUpdateRegistrarTransactionVersion;
        self.providerMode = providerUpdateRegistrarTransaction.providerMode;
        self.operatorKey = [NSData dataWithUInt384:providerUpdateRegistrarTransaction.operatorKey];
        self.scriptPayout = providerUpdateRegistrarTransaction.scriptPayout;
        self.payloadSignature = providerUpdateRegistrarTransaction.payloadSignature;
        self.votingKeyHash = [NSData dataWithUInt160:providerUpdateRegistrarTransaction.votingKeyHash];
        self.providerRegistrationTransactionHash = [NSData dataWithUInt256:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash];
        
        NSString * operatorAddress = [DSKey addressWithPublicKeyData:self.operatorKey forChain:tx.chain];
        NSString * votingAddress = [self.votingKeyHash addressFromHash160DataForChain:tx.chain];
        NSString * payoutAddress = [NSString addressWithScriptPubKey:self.scriptPayout onChain:tx.chain];
        
        NSArray * operatorAddressEntities = [DSAddressEntity objectsMatching:@"address == %@ && derivationPath.chain == %@",operatorAddress,tx.chain.chainEntity];
        if ([operatorAddressEntities count]) {
            NSAssert([operatorAddressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[operatorAddressEntities firstObject]];
        }
        
        NSArray * votingAddressEntities = [DSAddressEntity objectsMatching:@"address == %@ && derivationPath.chain == %@",votingAddress,tx.chain.chainEntity];
        if ([votingAddressEntities count]) {
            NSAssert([votingAddressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[votingAddressEntities firstObject]];
        }
        
        NSArray * payoutAddressEntities = [DSAddressEntity objectsMatching:@"address == %@ && derivationPath.chain == %@",payoutAddress,tx.chain.chainEntity];
        if ([payoutAddressEntities count]) {
            NSAssert([payoutAddressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[payoutAddressEntities firstObject]];
        }
        
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSProviderUpdateRegistrarTransaction * transaction = (DSProviderUpdateRegistrarTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_ProviderUpdateRegistrar;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.providerUpdateRegistrarTransactionVersion = self.specialTransactionVersion;
        transaction.providerMode = self.providerMode;
        transaction.operatorKey = self.operatorKey.UInt384;
        transaction.scriptPayout = self.scriptPayout;
        transaction.payloadSignature = self.payloadSignature;
        transaction.votingKeyHash = self.votingKeyHash.UInt160;
        transaction.providerRegistrationTransactionHash = self.providerRegistrationTransactionHash.UInt256;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSProviderUpdateRegistrarTransaction class];
}

@end
