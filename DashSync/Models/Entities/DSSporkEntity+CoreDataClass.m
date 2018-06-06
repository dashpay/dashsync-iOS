//
//  DSSporkEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/28/18.
//
//

#import "DSSporkEntity+CoreDataClass.h"
#import "DSSpork.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"

@implementation DSSporkEntity

- (void)setAttributesFromSpork:(DSSpork *)spork
{
    [self.managedObjectContext performBlockAndWait:^{
        self.identifier = spork.identifier;
        self.signature = spork.signature;
        self.timeSigned = spork.timeSigned;
        self.value = spork.value;
        self.chain = [DSChainEntity chainEntityForType:spork.chain.chainType genesisBlock:spork.chain.genesisHash checkpoints:nil];
    }];
}

@end
