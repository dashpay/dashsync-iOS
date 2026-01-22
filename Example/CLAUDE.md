# DashSync Example App & Tests

This directory contains the reference implementation and comprehensive test suite for DashSync.

## Quick Start

```bash
# Install dependencies
pod install

# Open workspace
open DashSync.xcworkspace

# Run tests from command line
xcodebuild test -workspace DashSync.xcworkspace \
  -scheme DashSync-Example \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Directory Structure

```
Example/
├── DashSync/              # Example app source code
├── Tests/                 # Unit and integration tests
├── NetworkInfo/           # Network configuration
├── DashSync.xcworkspace   # Xcode workspace (use this!)
├── DashSync.xcodeproj/    # Xcode project
├── Podfile                # CocoaPods configuration
└── Podfile.lock           # Locked dependency versions
```

## Test Categories

### Test Files

| Test File | Coverage |
|-----------|----------|
| `DSChainTests.m` | Chain operations, sync, blocks |
| `DSTransactionTests.m` | Transaction types, serialization |
| `DSDeterministicMasternodeListTests.m` | Masternode lists, diffs |
| `DSWalletTests.m` | Wallet operations |
| `DSBIP32Tests.m` | BIP32 key derivation |
| `DSBIP39Tests.m` | BIP39 mnemonic handling |
| `DSHashTests.m` | Hash functions |
| `DSKeyTests.m` | Key operations |
| `DSBloomFilterTests.m` | Bloom filter logic |
| `DSGovernanceTests.m` | Governance objects |
| `DSProviderTransactionsTests.m` | Provider transactions |
| `DSSparseMerkleTreeTests.m` | Sparse merkle trees |
| `DSCoinJoinSessionTest.m` | CoinJoin mixing |
| `DSDIP14Tests.m` | DIP14 compliance |
| `DSAttackTests.m` | Chain attack scenarios |
| `DSMainnetSyncTests.m` | Mainnet sync |
| `DSTestnetSyncTests.m` | Testnet sync |
| `DSTestnetE2ETests.m` | End-to-end testnet |

### Test Plans (`.xctestplan` files)

| Plan | Purpose |
|------|---------|
| `FullUnitTestPlan` | All unit tests |
| `CryptoTests` | Cryptographic functions |
| `DerivationTests` | Key derivation |
| `MasternodeListTests` | Masternode operations |
| `TransactionTests` | Transaction handling |
| `WalletTests` | Wallet operations |
| `PaymentTests` | Payment protocol |
| `GovernanceTests` | Governance system |
| `LockTests` | Chain/instant locks |
| `CoinJoinTests` | Privacy mixing |
| `PlatformTransitionTests` | Platform transitions |
| `MainnetSyncTests` | Mainnet sync tests |
| `TestnetSyncTests` | Testnet sync tests |
| `TestnetE2ETests` | End-to-end tests |
| `Metrics` | Performance metrics |

## Test Data Files

The `Tests/` directory contains data files for deterministic testing:

- `MasternodeList*.dat` - Masternode list snapshots
- `MNL_*.dat` - Masternode list diffs (from_to format)
- `DiffListTestnet*.dat` - Testnet diff data
- `BlocksForReorgTests/` - Block data for reorg tests

## Running Specific Test Plans

```bash
# Run crypto tests
xcodebuild test -workspace DashSync.xcworkspace \
  -scheme DashSync-Example \
  -testPlan CryptoTests \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run masternode tests
xcodebuild test -workspace DashSync.xcworkspace \
  -scheme DashSync-Example \
  -testPlan MasternodeListTests \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run network sync tests (requires network)
xcodebuild test -workspace DashSync.xcworkspace \
  -scheme DashSync-Example \
  -testPlan TestnetSyncTests \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Code Quality Tools

### Linting
```bash
# Run OCLint
./run_oclint.sh

# Check lint status
./check_lint.sh
```

### Configuration Files
- `.clang-format` - Clang formatting rules
- `.oclint` - OCLint rules
- `.bartycrouch.toml` - Localization tool config

## Example App Features

The example app in `DashSync/` demonstrates:
- Chain synchronization
- Wallet management
- Transaction creation
- Masternode operations
- Governance participation
- Identity management
- CoinJoin mixing

## Dependencies

See `Podfile` for current dependencies. Key pods:
- `DashSyncPod` (local development pod)
- Test dependencies as needed

## CI/CD Integration

Tests run automatically via GitHub Actions:
- Unit tests on every PR
- Sync tests on schedule
- Coverage reporting to Codecov
