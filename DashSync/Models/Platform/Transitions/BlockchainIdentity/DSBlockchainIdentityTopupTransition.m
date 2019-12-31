//
//  DSBlockchainIdentityTopupTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/30/18.
//

#import "DSBlockchainIdentityTopupTransition.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSBlockchainIdentityTopupTransitionEntity+CoreDataClass.h"

@interface DSBlockchainIdentityTopupTransition()

@end

@implementation DSBlockchainIdentityTopupTransition

-(Class)entityClass {
    return [DSBlockchainIdentityTopupTransitionEntity class];
}

@end
