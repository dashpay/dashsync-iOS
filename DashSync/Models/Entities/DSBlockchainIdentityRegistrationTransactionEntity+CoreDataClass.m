//
//  DSBlockchainIdentityRegistrationTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainIdentityRegistrationTransactionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityRegistrationTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "DSTransaction.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSBlockchainIdentityRegistrationTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSBlockchainIdentityRegistrationTransaction * blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransaction*)tx;
        self.specialTransactionVersion = blockchainIdentityRegistrationTransaction.blockchainIdentityRegistrationTransactionVersion;
        self.publicKey = [NSData dataWithUInt160:blockchainIdentityRegistrationTransaction.pubkeyHash];
        self.username = blockchainIdentityRegistrationTransaction.username;
        self.payloadSignature = blockchainIdentityRegistrationTransaction.payloadSignature;
        
        //for when we switch to BLS -> [DSKey addressWithPublicKeyData:self.publicKey forChain:tx.chain];
        NSString * publicKeyAddress = [self.publicKey addressFromHash160DataForChain:tx.chain];
        NSArray * addressEntities = [DSAddressEntity objectsMatching:@"address == %@ && derivationPath.chain == %@",publicKeyAddress,tx.chain.chainEntity];
        if ([addressEntities count]) {
            NSAssert([addressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[addressEntities firstObject]];
        } else {
            DSDLog(@"Address %@ is not known", publicKeyAddress);
        }
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSBlockchainIdentityRegistrationTransaction * transaction = (DSBlockchainIdentityRegistrationTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionRegistration;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainIdentityRegistrationTransactionVersion = self.specialTransactionVersion;
        transaction.pubkeyHash = self.publicKey.UInt160;
        DSDLog(@"%@",uint160_hex(transaction.pubkeyHash));
        transaction.username = self.username;
        transaction.payloadSignature = self.payloadSignature;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainIdentityRegistrationTransaction class];
}

@end

