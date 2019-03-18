//
//  DSContactsModel.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSContactsModel.h"

#import <DashSync/DashSync.h>
#import <DashSync/DSTransition.h>
#import <ios-dpp/DSDAPObjectsFactory.h>
#import <ios-dpp/DSSchemaObject.h>
#import <ios-dpp/DSSchemaHashUtils.h>
#import <DSJSONSchemaValidation/NSDictionary+DSJSONDeepMutableCopy.h>
#import <TinyCborObjc/NSObject+DSCborEncoding.h>

static NSString * const ContactsDAPId = @"9ae7bb6e437218d8be36b04843f63a135491c898ff22d1ead73c43e105cc2444";
static NSString * const DashpayDAPId = @"7723be402fbd457bc8e8435addd4efcbe41c1d548db9fc3075a03bb68929fc61";

NS_ASSUME_NONNULL_BEGIN

@interface DSContactsModel ()

@property (copy, nonatomic) NSDictionary *blockchainUserData;

@property (copy, nonatomic) NSArray <NSString *> *contacts;
@property (copy, nonatomic) NSArray <NSString *> *outgoingContactRequests;
@property (copy, nonatomic) NSArray <NSString *> *incomingContactRequests;

@end

@implementation DSContactsModel

- (instancetype)init {
    self = [super init];
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
        [self fetchBlockchainUserData:self.blockchainUser.username completion:^(NSDictionary * _Nullable blockchainUser) {
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
    [self fetchBlockchainUserData:username completion:^(NSDictionary * _Nullable blockchainUser) {
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
        
        NSMutableDictionary<NSString *, id> *contactObject = [DSDAPObjectsFactory createDAPObjectForTypeName:@"contact"];
        contactObject[@"user"] = blockchainUser[@"regtxid"];
        contactObject[@"username"] = username;
        
        NSMutableDictionary<NSString *, id> *me = [NSMutableDictionary dictionary];
        me[@"id"] = strongSelf.blockchainUserData[@"regtxid"];
        me[@"username"] = strongSelf.blockchainUser.username;
        
        contactObject[@"sender"] = me;
        
        [strongSelf sendDapObject:contactObject completion:^(BOOL success) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
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
    NSDictionary *query = @{@"data.user": self.blockchainUserData[@"regtxid"]};
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
    
    __weak typeof(self) weakSelf = self;
    [self.chainManager.DAPIClient fetchDapObjectsForId:ContactsDAPId objectsType:@"contact" options:options success:^(NSArray<NSDictionary *> * _Nonnull dapObjects) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        [strongSelf handleContacts:dapObjects];
        
        if (completion) {
            completion(YES);
        }
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            completion(NO);
        }
    }];
}

- (void)removeIncomingContactRequest:(NSString *)username {
    NSMutableArray <NSString *> *incomingContactRequests = [self.incomingContactRequests mutableCopy];
    [incomingContactRequests removeObject:username];
    self.incomingContactRequests = incomingContactRequests;
}

#pragma mark - Private

- (void)createProfileWithCompletion:(void (^)(BOOL success))completion {
    NSMutableDictionary<NSString *, id> *userObject = [DSDAPObjectsFactory createDAPObjectForTypeName:@"user"];
    userObject[@"aboutme"] = [NSString stringWithFormat:@"Hey I'm a demo user %@", self.blockchainUser.username];
    userObject[@"username"] = self.blockchainUser.username;
    
    __weak typeof(self) weakSelf = self;
    [self sendDapObject:userObject completion:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (success) {
            [strongSelf fetchBlockchainUserData:strongSelf.blockchainUser.username completion:^(NSDictionary * _Nullable blockchainUser) {
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

- (void)sendDapObject:(NSMutableDictionary<NSString *, id> *)dapObject completion:(void (^)(BOOL success))completion {
    NSMutableArray *dapObjects = [NSMutableArray array];
    [dapObjects addObject:dapObject];
    
    NSMutableDictionary<NSString *, id> *stPacket = [[DSDAPObjectsFactory createSTPacketInstance] ds_deepMutableCopy];
    NSMutableDictionary<NSString *, id> *stPacketObject = stPacket[DS_STPACKET];
    stPacketObject[DS_DAPOBJECTS] = dapObjects;
    stPacketObject[@"dapid"] = ContactsDAPId;
    
    NSData *serializedSTPacketObject = [stPacketObject ds_cborEncodedObject];
    
    __block NSData *serializedSTPacketObjectHash = [DSSchemaHashUtils hashOfObject:stPacketObject];
    
    __block DSTransition *transition = [self.blockchainUser transitionForStateTransitionPacketHash:serializedSTPacketObjectHash.UInt256];
    
    [self.blockchainUser signStateTransition:transition
                                  withPrompt:@"" completion:^(BOOL success) {
                                      if (success) {
                                          NSData *transitionData = [transition toData];
                                          
                                          NSString *transitionDataHex = [transitionData hexString];
                                          NSString *serializedSTPacketObjectHex = [serializedSTPacketObject hexString];
                                          
                                          [self.chainManager.DAPIClient sendRawTransitionWithRawTransitionHeader:transitionDataHex rawTransitionPacket:serializedSTPacketObjectHex success:^(NSString * _Nonnull headerId) {
                                              NSLog(@"Header ID %@", headerId);
                                              
                                              [self.chainManager.chain registerSpecialTransaction:transition];
                                              [transition save];
                                              
                                              if (completion) {
                                                  completion(YES);
                                              }
                                          } failure:^(NSError * _Nonnull error) {
                                              NSLog(@"Error: %@", error);
                                              if (completion) {
                                                  completion(NO);
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

- (void)fetchBlockchainUserData:(NSString *)username completion:(void (^)(NSDictionary * _Nullable blockchainUser))completion {
    [self.chainManager.DAPIClient getUserByName:username success:^(NSDictionary * _Nonnull blockchainUser) {
        NSLog(@"%@", blockchainUser);

        if (completion) {
            completion(blockchainUser);
        }
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"%@", error);
        
        if (completion) {
            completion(nil);
        }
    }];
}

- (void)handleContacts:(NSArray<NSDictionary *> *)rawContacts {
    NSMutableArray <NSString *> *contactsAndIncomingRequests = [NSMutableArray array];
    for (NSDictionary *rawContact in rawContacts) {
        NSDictionary *sender = rawContact[@"sender"];
        NSString *username = sender[@"username"];
        [contactsAndIncomingRequests addObject:username];
    }
    
    NSMutableArray <NSString *> *contacts = [NSMutableArray array];
    NSMutableArray <NSString *> *outgoingContactRequests = [self.outgoingContactRequests mutableCopy];
    NSMutableArray <NSString *> *incomingContactRequests = [NSMutableArray array];
    
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
