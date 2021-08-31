//
//  DSTxOutputEntity+CoreDataClass.m
//
//
//  Created by Sam Westrich on 5/20/18.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSTxOutputEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)transaction outputIndex:(NSUInteger)index forTransactionEntity:(DSTransactionEntity *)transactionEntity {
    UInt256 txHash = transaction.txHash;

    self.txHash = [NSData dataWithBytes:&txHash length:sizeof(txHash)];
    self.n = (int32_t)index;
    self.address = (transaction.outputAddresses[index] == [NSNull null]) ? nil : transaction.outputAddresses[index];
    self.script = transaction.outputScripts[index];
    self.value = [transaction.outputAmounts[index] longLongValue];
    self.shapeshiftOutboundAddress = [DSTransaction shapeshiftOutboundAddressForScript:self.script onChain:transaction.chain];
    self.transaction = transactionEntity;
    if (self.address) {
        DSChainEntity *chainEntity = transactionEntity.transactionHash.chain;
        NSArray *addressEntities = [DSAddressEntity objectsInContext:transactionEntity.managedObjectContext matching:@"address == %@ && derivationPath.chain == %@", self.address, chainEntity ? chainEntity : [transaction.chain chainEntityInContext:transactionEntity.managedObjectContext]];
        if ([addressEntities count]) {
            NSAssert([addressEntities count] == 1, @"addresses should not be duplicates");
            self.localAddress = addressEntities[0];
            self.account = self.localAddress.derivationPath.account; //this is to make the outputs easily accessible for an account
        }
    } else {
        DSLog(@"Output had no address");
    }
    return self;
}

@end
