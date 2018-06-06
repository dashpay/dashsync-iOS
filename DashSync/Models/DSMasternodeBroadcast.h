//
//  DSMasternodeBroadcast.h
//  DashSync
//
//  Created by Sam Westrich on 5/31/18.
//

#import <Foundation/Foundation.h>
#import "DSChain.h"
#import "IntTypes.h"

@class DSMasternodePing;

@interface DSMasternodeBroadcast : NSObject

@property (nonatomic,readonly) DSUTXO utxo;
@property (nonatomic,readonly) NSData * signature;
@property (nonatomic,readonly) NSTimeInterval signatureTimestamp;
@property (nonatomic,strong) DSMasternodePing * lastPing;
@property (nonatomic,readonly) UInt128 ipAddress;
@property (nonatomic,readonly) uint16_t port;
@property (nonatomic,readonly) uint32_t protocolVersion;
@property (nonatomic,readonly) NSData * publicKey;
@property (nonatomic,readonly) UInt256 masternodeBroadcastHash;

+(DSMasternodeBroadcast*)masternodeBroadcastFromMessage:(NSData *)message;
-(instancetype)initWithUTXO:(DSUTXO)utxo ipAddress:(UInt128)ipAddress port:(uint16_t)port protocolVersion:(uint32_t)protocolVersion publicKey:(NSData* _Nonnull)publicKey signature:(NSData* _Nonnull)signature signatureTimestamp:(NSTimeInterval)signatureTimestamp;

@end
