//
//  DSContactsModel.h
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChainManager, DSBlockchainUser;

@interface DSContactsModel : NSObject

@property (nonatomic,strong) DSChainManager * chainManager;
@property (nonatomic,strong) DSBlockchainUser * blockchainUser;

- (void)getUser:(void (^)(BOOL success))completion;

- (void)contactRequestUsername:(NSString *)username completion:(void (^)(BOOL))completion;

@end

NS_ASSUME_NONNULL_END
