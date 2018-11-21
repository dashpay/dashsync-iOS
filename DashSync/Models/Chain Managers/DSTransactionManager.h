//
//  DSTransactionManager.h
//  DashSync
//
//  Created by Sam Westrich on 11/20/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChain;

@interface DSTransactionManager : NSObject

@property (nonatomic,readonly) DSChain * chain;

-(instancetype)initWithChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
