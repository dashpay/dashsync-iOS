//
//  DSBlockchainIdentityEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentity+Protected.h"

@implementation DSBlockchainIdentityEntity

-(DSBlockchainIdentity*)blockchainIdentity {
    return [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:self];
}

@end
