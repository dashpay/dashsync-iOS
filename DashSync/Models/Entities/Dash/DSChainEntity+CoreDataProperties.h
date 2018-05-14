//
//  DSChainEntity+CoreDataProperties.h
//  
//
//  Created by Sam Westrich on 5/12/18.
//
//

#import "DSChainEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSChainEntity (CoreDataProperties)

+ (NSFetchRequest<DSChainEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSString *genesisBlockHash;
@property (nullable, nonatomic, copy) NSNumber *standardPort;
@property (nullable, nonatomic, copy) NSNumber *type;
@property (nullable, nonatomic, retain) NSData *checkpoints;
@property (nullable, nonatomic, retain) NSSet<DSPeerEntity *> *peers;

@end

@interface DSChainEntity (CoreDataGeneratedAccessors)

- (void)addPeersObject:(DSPeerEntity *)value;
- (void)removePeersObject:(DSPeerEntity *)value;
- (void)addPeers:(NSSet<DSPeerEntity *> *)values;
- (void)removePeers:(NSSet<DSPeerEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
