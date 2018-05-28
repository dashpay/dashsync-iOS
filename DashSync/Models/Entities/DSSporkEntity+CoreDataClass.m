//
//  DSSporkEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/28/18.
//
//

#import "DSSporkEntity+CoreDataClass.h"
#import "DSSpork.h"

@implementation DSSporkEntity

- (void)setAttributesFromSpork:(DSSpork *)spork
{
    [self.managedObjectContext performBlockAndWait:^{
        self.identifier = spork.identifier;
        self.signature = spork.signature;
        self.timeSigned = spork.timeSigned;
        self.value = spork.value;
    }];
}

@end
