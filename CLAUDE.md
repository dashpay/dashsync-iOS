# DashSync iOS

DashSync is a lightweight blockchain client library for iOS/macOS that enables applications to interact with the Dash cryptocurrency network. It supports both Dash Core Network (Layer 1) and Dash Platform (Layer 2).

## Quick Reference

- **Language**: Objective-C with C/C++/Rust interop
- **Build System**: Xcode + CocoaPods
- **Deployment**: iOS 13.0+, macOS 10.15+
- **Pod Name**: `DashSyncPod`

## Build Requirements

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim

# Install protobuf and grpc
brew install protobuf grpc cmake
```

## Common Commands

```bash
# Run example project
cd Example && pod install && open DashSync.xcworkspace

# Run tests
cd Example && xcodebuild test -workspace DashSync.xcworkspace -scheme DashSync-Example -destination 'platform=iOS Simulator,name=iPhone 15'

# Update pods
cd Example && pod update
```

## Project Structure

```
DashSync/
├── DashSync/shared/           # Main framework source (cross-platform)
│   ├── Models/                # Core domain models (24 subdirectories)
│   ├── Libraries/             # Utility libraries
│   └── DashSync.xcdatamodeld/ # Core Data model (83 entities)
├── DashSync/iOS/              # iOS-specific code
├── DashSync/macOS/            # macOS-specific code
├── Example/                   # Reference app and tests
├── Scripts/                   # Build utilities
└── ChainResources/            # Blockchain data files
```

## Architecture

### Two-Layer Design
- **Layer 1 (Core)**: Traditional blockchain - transactions, blocks, masternodes
- **Layer 2 (Platform)**: Decentralized apps - identities, documents, contracts

### Model-Manager Pattern
- **Models**: Data structures (`DSChain`, `DSWallet`, `DSTransaction`)
- **Managers**: Service coordinators (`DSChainManager`, `DSPeerManager`)

### Key Managers
| Manager | Purpose |
|---------|---------|
| `DSChainsManager` | Multi-chain coordinator (singleton) |
| `DSChainManager` | Single chain operations |
| `DSPeerManager` | P2P network connectivity |
| `DSTransactionManager` | Transaction pool |
| `DSMasternodeManager` | Masternode lists & quorums |
| `DSIdentitiesManager` | Blockchain identities |
| `DSGovernanceSyncManager` | Governance data sync |

### Persistence
- **Core Data** with SQLite backend
- 83 entity definitions in `DashSync.xcdatamodeld`
- Custom transformers in `Models/Persistence/Transformers/`

## Code Conventions

### Naming
- All classes prefixed with `DS` (e.g., `DSChain`, `DSWallet`)
- Entities suffixed with `Entity` (e.g., `DSChainEntity`)
- Managers suffixed with `Manager` (e.g., `DSPeerManager`)

### File Organization
- Public headers in main directory
- `+Protected.h` files for subclass-accessible interfaces
- Categories in `Categories/` subdirectories

### Notifications
Event-driven via `NSNotificationCenter`:
- `DSChainBlocksDidFinishSyncingNotification`
- `DSWalletBalanceDidChangeNotification`
- `DSPeerManagerConnectedPeersDidChangeNotification`

## Key Classes

### Chain & Sync
- `DSChain` (3,562 lines) - Central blockchain state manager
- `DSBlock`, `DSMerkleBlock` - Block representations
- `DSChainLock` - Chain lock mechanism

### Wallet
- `DSWallet` - HD wallet management
- `DSAccount` - Account within wallet
- `DSBIP39Mnemonic` - Mnemonic seed handling
- `DSDerivationPath` - BIP32/44 key derivation

### Transactions
- `DSTransaction` - Base transaction class
- `DSCoinbaseTransaction` - Mining rewards
- `DSProviderRegistrationTransaction` - Masternode registration
- `DSQuorumCommitmentTransaction` - Quorum operations
- `DSCreditFundingTransaction` - Platform funding

### Identity & Platform
- `DSBlockchainIdentity` - Dash Platform identity
- `DSBlockchainInvitation` - Contact requests
- `DPContract` - Platform smart contracts
- `DPDocument` - Platform documents

### Privacy
- `DSCoinJoinManager` - CoinJoin mixing coordination
- `DSCoinJoinWrapper` - Protocol implementation

## Network Support

| Network | Purpose |
|---------|---------|
| Mainnet | Production Dash network |
| Testnet | Testing environment |
| Devnet | Development chains |
| Regnet | Local regression testing |

## Testing

Tests located in `Example/Tests/`:
- `DSChainTests.m` - Chain operations
- `DSTransactionTests.m` - Transaction handling
- `DSDeterministicMasternodeListTests.m` - Masternode lists
- `DSCoinJoinSessionTest.m` - Privacy mixing
- `DSDIP14Tests.m` - DIP compliance

## CI/CD Workflows

- `build.yml` - Main CI pipeline
- `test.yml` - Unit tests
- `lint.yml` - Code linting
- `coverage.yml` - Code coverage
- `syncTestMainnet.yml` / `syncTestTestnet.yml` - Network sync tests

## Dependencies

Key CocoaPods:
- **DashSharedCore** - Rust-based cryptographic primitives
- **CocoaLumberjack** - Logging framework
- **DAPI-GRPC** - Decentralized API protocol
- **TinyCborObjc** - CBOR serialization

## Localization

Supports 15+ languages: en, de, es, ja, zh-Hans, zh-Hant-TW, uk, bg, el, it, cs, sk, ko, pl, tr, vi

## Development Workflow

### Git Workflow Policy

**NEVER commit or push changes without explicit user permission.**

When the user asks you to make code changes:
1. Make the requested changes to the code
2. Show what was changed (using `git diff` or explanation)
3. **STOP and WAIT** for explicit permission to commit/push
4. Only commit/push when the user explicitly says to do so

**Example phrases that give permission to commit/push:**
- "commit these changes"
- "push to github"
- "create a commit and push"
- "commit and push all changes"

**Do NOT commit/push** just because the user asked for code changes. They may want to test first.

#### Permission Does NOT Carry Over

**Each set of changes requires its own explicit permission.** If the user gave permission to commit earlier in the conversation, that permission applies ONLY to those specific changes - NOT to any subsequent changes.

**Example scenario:**
1. User: "Fix bug X, then commit and push" → Permission granted for bug X fix only
2. User: "Now fix bug Y" → Make the fix, show diff, **STOP AND WAIT** - no permission to commit yet
3. User: "Looks good, commit it" → NOW permission is granted for bug Y fix

**Common mistake to avoid:** After completing a task like "address review comments" or "fix these issues", do NOT automatically commit. The user needs to test the changes first. Always pause after showing the diff and wait for explicit commit instruction.

#### Testing Before Commit

This is especially important for DashSync because:
- Changes affect downstream projects (dashwallet-ios, other consumers)
- Logging and behavioral changes need runtime verification
- The user must run the code to confirm changes work as expected

Always wait for the user to confirm they have tested and verified the changes before committing.

### Related Repositories
- **DashJ** (Android equivalent): https://github.com/dashpay/dashj
- **Dash Wallet Android**: https://github.com/dashpay/dash-wallet

## External Resources

- [Dash Core Specs](https://dashcore.readme.io/docs)
- [Dash Improvement Proposals](https://github.com/dashpay/dips)
- [Developer Discord](https://discord.com/channels/484546513507188745/614505310593351735)
