//
//  DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "DSTransaction.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSBlockchainIdentityRegistrationTransitionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransition*)tx;
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
    DSBlockchainIdentityRegistrationTransition * transaction = (DSBlockchainIdentityRegistrationTransition *)[super transactionForChain:chain];
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
    return [DSBlockchainIdentityRegistrationTransition class];
}

@end
