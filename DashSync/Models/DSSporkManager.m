//
//  DSSporkManager.m
//  dashwallet
//
//  Created by Sam Westrich on 10/18/17.
//  Copyright © 2017 Aaron Voisine. All rights reserved.
//

#import "DSSporkManager.h"
#import "DSSpork.h"
#import "DSSporkEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"

@interface DSSporkManager()
    
@property (nonatomic,strong) NSMutableDictionary * sporkDictionary;
@property (nonatomic,strong) DSChain * chain;
    
@end

@implementation DSSporkManager

- (instancetype)initWithChain:(id)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    _sporkDictionary = [NSMutableDictionary dictionary];
    NSArray * sporkEntities = [DSSporkEntity allObjects];
    for (DSSporkEntity * sporkEntity in sporkEntities) {
        DSSpork * spork = [[DSSpork alloc] initWithIdentifier:sporkEntity.identifier value:sporkEntity.value timeSigned:sporkEntity.timeSigned signature:sporkEntity.signature onChain:chain];
        _sporkDictionary[@(spork.identifier)] = spork;
    }
    return self;
}
    
-(BOOL)instantSendActive {
    DSSpork * instantSendSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork2InstantSendEnabled)];
    if (!instantSendSpork) return TRUE;//assume true
    return !!instantSendSpork.value;
}

-(NSDictionary*)sporkDictionary {
    return [_sporkDictionary copy];
}
    
- (void)peer:(DSPeer *)peer relayedSpork:(DSSpork *)spork {
    if (!spork.isValid) return; //sanity check
    DSSpork * currentSpork = self.sporkDictionary[@(spork.identifier)];
    BOOL updatedSpork = FALSE;
    __block NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
    if (currentSpork) {
        //there was already a spork
        if (![currentSpork isEqualToSpork:spork]) {
            _sporkDictionary[@(spork.identifier)] = spork; //set it to new one
            updatedSpork = TRUE;
            [dictionary setObject:currentSpork forKey:@"old"];
        } else {
            return; //nothing more to do
        }
    } else {
        _sporkDictionary[@(spork.identifier)] = spork;
    }
    [dictionary setObject:spork forKey:@"new"];
    
    if (!currentSpork || updatedSpork) {
        @autoreleasepool {
            [[DSSporkEntity managedObject] setAttributesFromSpork:spork]; // add new peers
            [DSSporkEntity saveContext];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSSporkManagerSporkUpdateNotification object:nil userInfo:dictionary];
        });
    }
}
    
@end
