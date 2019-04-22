//
//  DSBlockchainUser.h
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import <Foundation/Foundation.h>
#import "DSDAPIClient.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN
@class DSWallet,DSBlockchainUserRegistrationTransaction,DSBlockchainUserTopupTransaction,DSBlockchainUserResetTransaction,DSBlockchainUserCloseTransaction,DSAccount,DSChain,DSTransition,DSContactEntity,DSPotentialContact,DSTransaction;

@interface DSBlockchainUser : NSObject

@property (nonatomic,weak,readonly) DSWallet * wallet;
@property (nonatomic,readonly) NSString * uniqueIdentifier;
@property (nonatomic,readonly) UInt256 registrationTransactionHash;
@property (nonatomic,readonly) NSString * registrationTransactionHashIdentifier;
@property (nonatomic,readonly) UInt256 lastTransitionHash;
@property (nonatomic,readonly) uint32_t index;
@property (nonatomic,readonly) NSString * username;
@property (nonatomic,readonly) NSString * dashpayBioString;
@property (nonatomic,readonly) uint64_t creditBalance;
@property (nonatomic,readonly) uint64_t syncHeight;
@property (nonatomic,readonly) NSArray<DSTransaction*>*allTransitions;

@property (nonatomic,readonly) DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction;

@property (nonatomic,readonly) DSContactEntity* ownContact;

-(instancetype)initWithUsername:(NSString* _Nonnull)username atIndex:(uint32_t)index inWallet:(DSWallet* _Nonnull)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithUsername:(NSString* _Nonnull)username atIndex:(uint32_t)index inWallet:(DSWallet* _Nonnull)wallet createdWithTransactionHash:(UInt256)registrationTransactionHash lastTransitionHash:(UInt256)lastTransitionHash inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithBlockchainUserRegistrationTransaction:(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(void)generateBlockchainUserExtendedPublicKey:(void (^ _Nullable)(BOOL registered))completion;

-(void)registerInWallet;

-(void)registrationTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction))completion;

-(void)topupTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction))completion;

-(void)resetTransactionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainUserResetTransaction * blockchainUserResetTransaction))completion;

-(void)updateWithTopupTransaction:(DSBlockchainUserTopupTransaction*)blockchainUserTopupTransaction save:(BOOL)save;
-(void)updateWithResetTransaction:(DSBlockchainUserResetTransaction*)blockchainUserResetTransaction save:(BOOL)save;
-(void)updateWithCloseTransaction:(DSBlockchainUserCloseTransaction*)blockchainUserCloseTransaction save:(BOOL)save;
-(void)updateWithTransition:(DSTransition*)transition save:(BOOL)save;

-(DSTransition*)transitionForStateTransitionPacketHash:(UInt256)stateTransitionHash;

-(void)signStateTransition:(DSTransition*)transition withPrompt:(NSString * _Nullable)prompt completion:(void (^ _Nullable)(BOOL success))completion;

-(void)sendDapObject:(NSMutableDictionary<NSString *, id> *)dapObject completion:(void (^)(BOOL success))completion;

- (void)sendNewContactRequestToPotentialContact:(DSPotentialContact*)potentialContact completion:(void (^)(BOOL))completion;

- (void)fetchContactRequests:(void (^)(BOOL success))completion;

- (void)fetchProfile:(void (^)(BOOL success))completion;

- (void)createProfileWithAboutMeString:(NSString*)aboutme completion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
