//
//  DSChainEntity+CoreDataProperties.m
//  
//
//  Created by Sam Westrich on 5/12/18.
//
//

#import "DSChainEntity+CoreDataProperties.h"

@implementation DSChainEntity (CoreDataProperties)

+ (NSFetchRequest<DSChainEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSChainEntity"];
}

@dynamic genesisBlockHash;
@dynamic standardPort;
@dynamic type;
@dynamic checkpoints;
@dynamic peers;

@end
