# DashSync Models

This directory contains the core domain models for DashSync, organized by functional area.

## Directory Structure

| Directory | Purpose |
|-----------|---------|
| `Chain/` | Blockchain state - chains, blocks, merkle trees, chain locks |
| `Wallet/` | HD wallet - accounts, addresses, authentication |
| `Transactions/` | Transaction types - base, coinbase, provider, quorums |
| `Managers/` | Service coordinators - chain managers, service managers |
| `Derivation Paths/` | BIP32/44 key derivation paths |
| `Entities/` | Core Data entity definitions (83 entities) |
| `Identity/` | Blockchain identities, invitations, contacts |
| `Platform/` | Dash Platform - contracts, documents, transitions |
| `Masternode/` | Masternode lists, quorums, rotations |
| `DAPI/` | Decentralized API client and queries |
| `CoinJoin/` | Privacy mixing protocol |
| `Governance/` | Governance objects and voting |
| `Network/` | P2P networking - peers, bloom filters |
| `Messages/` | P2P protocol message handlers |
| `Keys/` | Cryptographic key management |
| `Crypto/` | Cryptography - sparse merkle trees |
| `Persistence/` | Data layer - Core Data controller, migrations |
| `Payment/` | Payment protocol support |
| `Spork/` | Network parameter updates |
| `System/` | Environment and error handling |
| `Notifications/` | Notification definitions |

## Key Patterns

### Model Hierarchy

```
DSChain (root object)
├── DSWallet[]
│   └── DSAccount[]
│       └── DSDerivationPath[]
├── DSBlock[] / DSMerkleBlock[]
├── DSMasternodeList[]
│   └── DSSimplifiedMasternodeEntry[]
├── DSQuorum[]
└── DSSpork[]
```

### Manager Hierarchy

```
DSChainsManager (singleton)
└── DSChainManager (per chain)
    ├── DSPeerManager
    ├── DSTransactionManager
    ├── DSMasternodeManager
    ├── DSIdentitiesManager
    ├── DSGovernanceSyncManager
    ├── DSSporkManager
    └── DSKeyManager
```

## Transactions/

Transaction type inheritance:

```
DSTransaction (base)
├── DSCoinbaseTransaction
├── DSProviderRegistrationTransaction
├── DSProviderUpdateServiceTransaction
├── DSProviderUpdateRegistrarTransaction
├── DSProviderUpdateRevocationTransaction
├── DSQuorumCommitmentTransaction
├── DSAssetLockTransaction
├── DSAssetUnlockTransaction
└── DSCreditFundingTransaction
```

Use `DSTransactionFactory` to instantiate transactions from serialized data.

## Managers/

### Chain Managers (`Managers/Chain Managers/`)
Coordinate blockchain operations:
- `DSChainManager` - Main chain coordinator
- `DSPeerManager` - P2P peer connections
- `DSTransactionManager` - Transaction pool
- `DSMasternodeManager` - Masternode operations
- `DSIdentitiesManager` - Identity management
- `DSGovernanceSyncManager` - Governance sync
- `DSSporkManager` - Spork handling
- `DSKeyManager` - Key operations

### Service Managers (`Managers/Service Managers/`)
Handle external services:
- `DSAuthenticationManager` - User authentication
- `DSPriceManager` - Cryptocurrency pricing
- `DSInsightManager` - Blockchain explorer APIs

## Entities/

Core Data entities for persistence. Each model typically has a corresponding entity:
- `DSChainEntity` ↔ `DSChain`
- `DSWalletEntity` ↔ `DSWallet`
- `DSTransactionEntity` ↔ `DSTransaction`

Entity files:
- `*Entity+CoreDataClass.{h,m}` - Auto-generated Core Data class
- `*Entity+CoreDataProperties.{h,m}` - Auto-generated properties
- `*Entity.{h,m}` - Custom methods and logic

## Identity/

Dash Platform identity management:
- `DSBlockchainIdentity` - Main identity class
- `DSBlockchainIdentityRegistrationTransition` - Identity creation
- `DSBlockchainIdentityUpdateTransition` - Identity updates
- `DSBlockchainInvitation` - Contact invitations
- `DSDashpayUserEntity` - Dashpay contacts

## Platform/

Dash Platform Layer 2 objects:
- `DPContract` - Platform contracts
- `DPDocument` - Platform documents
- `DSPlatformDocumentsRequest` - Document queries
- State transitions for identity/document operations

## Derivation Paths/

BIP32/44 key derivation:
- `DSDerivationPath` - Base derivation path
- `DSFundsDerivationPath` - Funds-related paths
- `DSAuthenticationKeysDerivationPath` - Auth keys
- `DSMasternodeHoldingsDerivationPath` - Masternode keys
- `DSCreditFundingDerivationPath` - Platform credit funding

## Persistence/

- `DSDataController` - Core Data stack management
- `Migration/` - Database migration logic
- `Transformers/` - Custom value transformers (CBOR, JSON, etc.)

## Common Conventions

### Protected Interfaces
Files ending in `+Protected.h` expose internal methods for subclasses:
```objc
#import "DSTransaction+Protected.h"  // For subclass access
```

### Entity Lookups
Entities provide class methods for Core Data queries:
```objc
+ (DSChainEntity *)chainEntityForType:(DSChainType)type
                        devnetIdentifier:(NSString *)devnetIdentifier
                            inContext:(NSManagedObjectContext *)context;
```

### Model-Entity Bridging
```objc
// Model to Entity
DSTransactionEntity *entity = [transaction transactionEntityInContext:context];

// Entity to Model
DSTransaction *tx = [entity transactionForChain:chain];
```
