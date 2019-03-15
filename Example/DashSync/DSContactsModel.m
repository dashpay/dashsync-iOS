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

@end

@implementation DSContactsModel

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
        
        [strongSelf sendDapObject:contactObject completion:completion];
    }];
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

@end

NS_ASSUME_NONNULL_END
