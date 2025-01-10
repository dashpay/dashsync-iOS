//
//  DSContractEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/11/20.
//
//

#import "DSContractEntity+CoreDataClass.h"
#import "DSChain.h"

@implementation DSContractEntity

+ (instancetype)entityWithLocalContractIdentifier:(NSString *)identifier
                                          onChain:(DSChain *)chain
                                        inContext:(NSManagedObjectContext *)context {
    return [DSContractEntity anyObjectInContext:context matching:@"localContractIdentifier == %@ && chain == %@", identifier, [chain chainEntityInContext:context]];
}

@end
