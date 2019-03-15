//
//  DSContactsViewController.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 08/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSContactsViewController.h"

#import <DashSync/DashSync.h>
#import <DashSync/DSTransition.h>
#import <ios-dpp/DSDAPObjectsFactory.h>
#import <ios-dpp/DSSchemaObject.h>
#import <ios-dpp/DSSchemaHashUtils.h>
#import <DSJSONSchemaValidation/NSDictionary+DSJSONDeepMutableCopy.h>
#import <TinyCborObjc/NSObject+DSCborEncoding.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const ContactsDAPId = @"9ae7bb6e437218d8be36b04843f63a135491c898ff22d1ead73c43e105cc2444";
static NSString * const DashpayDAPId = @"7723be402fbd457bc8e8435addd4efcbe41c1d548db9fc3075a03bb68929fc61";

@interface DSContactsViewController ()

@end

@implementation DSContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self createProfile];
//    DSTransition *transition = []
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private

- (void)createProfile {
    NSMutableDictionary<NSString *, id> *userObject = [DSDAPObjectsFactory createDAPObjectForTypeName:@"user"];
    userObject[@"aboutme"] = [NSString stringWithFormat:@"Hey I'm a demo user %@", self.blockchainUser.username];
    userObject[@"username"] = self.blockchainUser.username;
    
    NSMutableArray *dapObjects = [NSMutableArray array];
    [dapObjects addObject:userObject];
    
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
                                          } failure:^(NSError * _Nonnull error) {
                                              NSLog(@"Error: %@", error);
                                          }];
                                          
                                      }
                                  }];
    

}

@end

NS_ASSUME_NONNULL_END
