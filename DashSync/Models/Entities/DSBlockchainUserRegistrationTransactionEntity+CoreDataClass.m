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
#import "DSTransaction.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

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
    DSBlockchainUserRegistrationTransaction * transaction = (DSBlockchainUserRegistrationTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionRegistration;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainUserRegistrationTransactionVersion = self.specialTransactionVersion;
        transaction.pubkeyHash = self.publicKey.UInt160;
        DSDLog(@"%@",uint160_hex(transaction.pubkeyHash));
        transaction.username = self.username;
        transaction.payloadSignature = self.payloadSignature;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainUserRegistrationTransaction class];
}

@end

