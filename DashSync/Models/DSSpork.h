//
//  DSSpork.h
//  dashwallet
//
//  Created by Sam Westrich on 10/18/17.
//  Copyright © 2017 Aaron Voisine. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint32_t,DSSporkIdentifier) {
    DSSporkIdentifier_Spork2InstantSendEnabled = 10001,
    DSSporkIdentifier_Spork3InstantSendBlockFiltering = 1002,
    DSSporkIdentifier_Spork5InstantSendMaxValue = 10004,
    DSSporkIdentifier_Spork8MasternodePaymentEnforcement = 10007,
    DSSporkIdentifier_Spork9SuperblocksEnabled = 10008,
    DSSporkIdentifier_Spork10MasternodePayUpdatedNodes = 10009,
    DSSporkIdentifier_Spork12ReconsiderBlocks = 10011,
    DSSporkIdentifier_Spork13OldSuperblockFlag = 10012,
    DSSporkIdentifier_Spork14RequireSentinelFlag = 10013
};


@interface DSSpork : NSObject

@property (nonatomic,assign,readonly) DSSporkIdentifier identifier;
@property (nonatomic,assign,readonly,getter=isValid) BOOL valid;
@property (nonatomic,assign,readonly) uint64_t timeSigned;
@property (nonatomic,assign,readonly) uint64_t value;
@property (nonatomic,strong,readonly) NSData * signature;

+ (instancetype)sporkWithMessage:(NSData *)message;
    
- (instancetype)initWithIdentifier:(DSSporkIdentifier)identifier value:(uint64_t)value timeSigned:(uint64_t)timeSigned signature:(NSData*)signature;
    
-(BOOL)isEqualToSpork:(DSSpork*)spork;

@end
