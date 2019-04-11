//
//  DSContactsModel.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSContactsModel.h"

#import <DashSync/DSTransition.h>
#import <DashSync/DashSync.h>

#import "DashPlatformProtocol+DashSync.h"

static NSString *const ContactsDAPId = @"9ae7bb6e437218d8be36b04843f63a135491c898ff22d1ead73c43e105cc2444";
static NSString *const DashpayDAPId = @"7723be402fbd457bc8e8435addd4efcbe41c1d548db9fc3075a03bb68929fc61";

NS_ASSUME_NONNULL_BEGIN

@interface DSContactsModel ()

@property (copy, nonatomic) NSDictionary *blockchainUserData;

@property (copy, nonatomic) NSArray<NSString *> *contacts;
@property (copy, nonatomic) NSArray<NSString *> *outgoingContactRequests;
@property (copy, nonatomic) NSArray<NSString *> *incomingContactRequests;

@end

@implementation DSContactsModel

- (instancetype)initWithChainManager:(DSChainManager *)chainManager blockchainUser:(DSBlockchainUser *)blockchainUser {
    self = [super initWithChainManager:chainManager blockchainUser:blockchainUser];
    if (self) {
        _contacts = @[];
        _outgoingContactRequests = @[];
        _incomingContactRequests = @[];
    }
    return self;
}

- (void)getUser:(void (^)(BOOL))completion {
    NSString *userKey = [NSString stringWithFormat:@"ds_contacts_user_profile_%@", self.blockchainUser.username];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:userKey]) {
        __weak typeof(self) weakSelf = self;
        [self fetchBlockchainUserData:self.blockchainUser.username completion:^(NSDictionary *_Nullable blockchainUser) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            strongSelf.blockchainUserData = blockchainUser;

            if (completion) {
                completion(!!blockchainUser);
            }
        }];
    }
    else {
        [self createProfileWithCompletion:^(BOOL success) {
            if (success) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:userKey];
            }

            if (completion) {
                completion(success);
            }
        }];
    }
}

- (void)contactRequestUsername:(NSString *)username completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    [self fetchBlockchainUserData:username completion:^(NSDictionary *_Nullable blockchainUser) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (!blockchainUser) {
            if (completion) {
                completion(NO);
            }

            return;
        }

        DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
        NSError *error = nil;
        DPJSONObject *data = @{
            @"toUserId" : blockchainUser[@"regtxid"],
            // TODO: fix me 😭
//            @"extendedPublicKey" : ?,
        };
        DPDocument *contact = [dpp.documentFactory documentWithType:@"contact" data:data error:&error];
        NSAssert(error == nil, @"Failed to build a contact");

        __weak typeof(self) weakSelf = self;
        [strongSelf sendDocument:contact contractId:ContactsDAPId completion:^(NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            BOOL success = error == nil;

            if (success) {
                strongSelf.outgoingContactRequests = [strongSelf.outgoingContactRequests arrayByAddingObject:username];
            }

            if (completion) {
                completion(success);
            }
        }];
    }];
}

- (void)fetchContacts:(void (^)(BOOL success))completion {
    NSDictionary *query = @{ @"data.user" : self.blockchainUserData[@"regtxid"] };
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];

    __weak typeof(self) weakSelf = self;
    [self.chainManager.DAPIClient fetchDocumentsForContractId:ContactsDAPId objectsType:@"contact" options:options success:^(NSArray<NSDictionary *> *_Nonnull documents) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        [strongSelf handleContacts:documents];

        if (completion) {
            completion(YES);
        }
    }
        failure:^(NSError *_Nonnull error) {
            if (completion) {
                completion(NO);
            }
        }];
}

- (void)removeIncomingContactRequest:(NSString *)username {
    NSMutableArray<NSString *> *incomingContactRequests = [self.incomingContactRequests mutableCopy];
    [incomingContactRequests removeObject:username];
    self.incomingContactRequests = incomingContactRequests;
}

#pragma mark - Private

- (void)createProfileWithCompletion:(void (^)(BOOL success))completion {
    DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
    NSError *error = nil;
    DPJSONObject *data = @{
        @"about" : [NSString stringWithFormat:@"Hey I'm a demo user %@", self.blockchainUser.username],
        @"avatarUrl" : [NSString stringWithFormat:@"https://api.adorable.io/avatars/120/%@.png", self.blockchainUser.username],
    };
    DPDocument *user = [dpp.documentFactory documentWithType:@"profile" data:data error:&error];
    NSAssert(error == nil, @"Failed to build a user");

    __weak typeof(self) weakSelf = self;
    [self sendDocument:user contractId:ContactsDAPId completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        BOOL success = error == nil;

        if (success) {
            [strongSelf fetchBlockchainUserData:strongSelf.blockchainUser.username completion:^(NSDictionary *_Nullable blockchainUser) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }

                strongSelf.blockchainUserData = blockchainUser;

                if (completion) {
                    completion(!!blockchainUser);
                }
            }];
        }
        else {
            if (completion) {
                completion(NO);
            }
        }
    }];
}

- (void)fetchBlockchainUserData:(NSString *)username completion:(void (^)(NSDictionary *_Nullable blockchainUser))completion {
    [self.chainManager.DAPIClient getUserByName:username success:^(NSDictionary *_Nonnull blockchainUser) {
        NSLog(@"%@", blockchainUser);

        if (completion) {
            completion(blockchainUser);
        }
    }
        failure:^(NSError *_Nonnull error) {
            NSLog(@"%@", error);

            if (completion) {
                completion(nil);
            }
        }];
}

- (void)handleContacts:(NSArray<NSDictionary *> *)rawContacts {
    NSMutableArray<NSString *> *contactsAndIncomingRequests = [NSMutableArray array];
    for (NSDictionary *rawContact in rawContacts) {
        NSDictionary *sender = rawContact[@"sender"];
        NSString *username = sender[@"username"];
        [contactsAndIncomingRequests addObject:username];
    }

    NSMutableArray<NSString *> *contacts = [NSMutableArray array];
    NSMutableArray<NSString *> *outgoingContactRequests = [self.outgoingContactRequests mutableCopy];
    NSMutableArray<NSString *> *incomingContactRequests = [NSMutableArray array];

    for (NSString *username in contactsAndIncomingRequests) {
        if ([outgoingContactRequests containsObject:username]) { // it's a match!
            [outgoingContactRequests removeObject:username];
            [contacts addObject:username];
        }
        else { // incoming request
            [incomingContactRequests addObject:username];
        }
    }

    self.contacts = contacts;
    self.outgoingContactRequests = outgoingContactRequests;
    self.incomingContactRequests = incomingContactRequests;
}

@end

NS_ASSUME_NONNULL_END
