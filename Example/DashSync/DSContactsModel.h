//
//  DSContactsModel.h
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSBaseStateTransitionModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSContactsModel : DSBaseStateTransitionModel

@property (readonly, copy, nonatomic) NSArray <NSString *> *contacts;
@property (readonly, copy, nonatomic) NSArray <NSString *> *outgoingContactRequests;
@property (readonly, copy, nonatomic) NSArray <NSString *> *incomingContactRequests;

- (void)getUser:(void (^)(BOOL success))completion;

- (void)contactRequestUsername:(NSString *)username completion:(void (^)(BOOL))completion;

- (void)fetchContacts:(void (^)(BOOL success))completion;

- (void)removeIncomingContactRequest:(NSString *)username;

@end

NS_ASSUME_NONNULL_END
