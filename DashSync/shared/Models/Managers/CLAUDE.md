# DashSync Managers

Managers are service coordinators that handle specific functional areas of DashSync. They follow the Model-Manager pattern where models hold data and managers coordinate operations.

## Directory Structure

```
Managers/
├── Chain Managers/      # Blockchain operation coordinators
└── Service Managers/    # External service coordinators
```

## Chain Managers

Located in `Chain Managers/`, these coordinate blockchain operations.

### DSChainsManager (Singleton)
Entry point for multi-chain management.
```objc
[DSChainsManager sharedInstance]
```
- Manages multiple chain instances (mainnet, testnet, devnets)
- Chain registration and retrieval
- Cross-chain coordination

### DSChainManager
Per-chain coordinator with sub-managers.
```objc
chain.chainManager
```
- Coordinates sync operations
- Manages chain state transitions
- Sub-manager lifecycle management

**Categories:**
- `DSChainManager+Mining.h` - Mining operations
- `DSChainManager+Transactions.h` - Transaction operations
- `DSChainManager+Protected.h` - Internal interface

### DSPeerManager (~50K lines)
P2P network management.
```objc
chain.chainManager.peerManager
```
- Peer discovery and connection
- Message sending/receiving
- Network health monitoring
- Bloom filter management

### DSTransactionManager (~108K lines)
Transaction pool management.
```objc
chain.chainManager.transactionManager
```
- Transaction broadcasting
- Transaction verification
- Mempool management
- InstantSend handling

### DSMasternodeManager (~49K lines)
Masternode operations.
```objc
chain.chainManager.masternodeManager
```
- Masternode list sync
- Quorum management
- Rotation handling

**Categories:**
- `DSMasternodeManager+LocalMasternode.h` - Local masternode ops
- `DSMasternodeManager+Mndiff.h` - Masternode diff processing

### DSIdentitiesManager
Blockchain identity operations.
```objc
chain.chainManager.identitiesManager
```
- Identity creation/retrieval
- Contact management
- Dashpay integration

### DSGovernanceSyncManager
Governance synchronization.
```objc
chain.chainManager.governanceSyncManager
```
- Proposal sync
- Vote tracking
- Superblock processing

### DSSporkManager
Network parameters.
```objc
chain.chainManager.sporkManager
```
- Spork state management
- Feature flag tracking

### DSKeyManager
Cryptographic key operations.
```objc
chain.chainManager.keyManager
```
- Key generation
- Signature operations
- Key derivation

### DSBackgroundManager
Background task coordination.
- iOS background fetch
- Background processing tasks
- Sync scheduling

## Service Managers

Located in `Service Managers/`, these handle external services.

### DSAuthenticationManager (`Auth/`)
User authentication.
```objc
[DSAuthenticationManager sharedInstance]
```
- Biometric authentication (Touch ID, Face ID)
- PIN management
- Spend limits
- Device passcode verification

### DSPriceManager (`Price/`)
Cryptocurrency pricing.
```objc
[DSPriceManager sharedInstance]
```
- Price fetching from multiple sources
- Currency conversion
- Price caching
- Exchange rate updates

### DSInsightManager
Blockchain explorer APIs.
- Transaction lookup
- Address balance queries
- External block explorer integration

### DSVersionManager
App version management.
- Version checking
- Migration handling
- Compatibility verification

### DSEventManager
Analytics and events.
- Event tracking
- User action logging
- Analytics integration

### DSOptionsManager
User preferences.
- Configuration settings
- Feature toggles
- User preferences storage

### DSShapeshiftManager
Exchange integration.
- Asset conversion
- Exchange rate queries
- Transaction tracking

### DSErrorSimulationManager
Testing utilities.
- Error injection
- Failure simulation
- Debug scenarios

## Common Patterns

### Accessing Managers
```objc
// Chain managers (via chain)
DSChain *chain = [[DSChainsManager sharedInstance] mainnetChain];
DSPeerManager *peers = chain.chainManager.peerManager;
DSTransactionManager *txManager = chain.chainManager.transactionManager;

// Service managers (singletons)
DSPriceManager *prices = [DSPriceManager sharedInstance];
DSAuthenticationManager *auth = [DSAuthenticationManager sharedInstance];
```

### Protected Interfaces
Files ending in `+Protected.h` expose internal methods:
```objc
#import "DSPeerManager+Protected.h"  // For testing or subclasses
```

### Manager Lifecycle
```objc
// Managers are typically created by their parent
// DSChainManager creates sub-managers on init
// Service managers are singletons with lazy initialization
```

### Notifications
Managers post notifications for state changes:
```objc
DSPeerManagerConnectedPeersDidChangeNotification
DSTransactionManagerTransactionStatusDidChangeNotification
DSChainManagerSyncPhaseDidChangeNotification
```

## File Size Reference

| Manager | Lines | Complexity |
|---------|-------|------------|
| DSTransactionManager | ~108K | Very High |
| DSPeerManager | ~50K | High |
| DSMasternodeManager | ~49K | High |
| DSIdentitiesManager | ~35K | High |
| DSGovernanceSyncManager | ~31K | Medium |
| DSPriceManager | ~30K | Medium |
| DSShapeshiftManager | ~26K | Medium |
| DSChainManager | ~22K | Medium |
