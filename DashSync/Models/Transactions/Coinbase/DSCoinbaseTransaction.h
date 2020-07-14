//
//  DSCoinbaseTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransaction.h"

@interface DSCoinbaseTransaction : DSTransaction

@property (nonatomic,assign) uint16_t coinbaseTransactionVersion;
@property (nonatomic,assign) uint32_t height;
@property (nonatomic,assign) UInt256 merkleRootMNList;
@property (nonatomic,assign) UInt256 merkleRootLLMQList;

-(instancetype)initWithCoinbaseMessage:(NSString*)coinbaseMessage atHeight:(uint32_t)height onChain:(DSChain*)chain;
-(instancetype)initWithCoinbaseMessage:(NSString*)coinbaseMessage paymentAddresses:(NSArray<NSString*>*)paymentAddresses atHeight:(uint32_t)height onChain:(DSChain*)chain;

@end
