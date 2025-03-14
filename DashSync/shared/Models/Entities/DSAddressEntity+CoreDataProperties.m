//
//  DSAddressEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 5/8/19.
//
//

#import "DSAddressEntity+CoreDataProperties.h"

@implementation DSAddressEntity (CoreDataProperties)

+ (NSFetchRequest<DSAddressEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSAddressEntity"];
}

@dynamic address;
@dynamic index;
@dynamic identityIndex;
@dynamic internal;
@dynamic standalone;
@dynamic derivationPath;
@dynamic usedInInputs;
@dynamic usedInOutputs;
//@dynamic usedInSimplifiedMasternodeEntries;
@dynamic usedInSpecialTransactions;

@end
