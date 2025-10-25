# Rebase Token with Cross-Chain Support

A sophisticated rebasing ERC20 token implementation with automatic interest accrual and cross-chain transfer capabilities using Chainlink CCIP. The token features a linear interest model where balances grow over time, and interest rates are preserved during cross-chain transfers.

## 🌟 Features

- **Automatic Interest Accrual**: Token balances automatically increase over time based on a linear interest model
- **Per-User Interest Rates**: Each user can have a custom interest rate that persists across transfers
- **Cross-Chain Transfers**: Bridge tokens between chains while preserving user interest rates via Chainlink CCIP
- **ETH-Backed Vault**: Deposit ETH to mint rebase tokens, redeem tokens for ETH with accrued interest
- **Access Control**: Role-based permissions for minting and burning operations
- **Principal vs Balance**: Separate tracking of principal balance and total balance (including interest)

## 📋 Table of Contents

- [Architecture](#architecture)
- [Contracts](#contracts)
- [How It Works](#how-it-works)
- [Installation](#installation)
- [Testing](#testing)
- [Deployment](#deployment)
- [Usage](#usage)
- [Security](#security)

## 🏗 Architecture

```
┌─────────────────┐
│   User (ETH)    │
└────────┬────────┘
         │ deposit
         ▼
┌─────────────────┐      ┌──────────────────┐
│     Vault       │◄────►│  RebaseToken     │
└─────────────────┘      └──────────┬───────┘
         │                          │
         │ redeem                   │ balanceOf (with interest)
         ▼                          │
┌─────────────────┐                 │
│   User (ETH +   │                 │
│    interest)    │                 │
└─────────────────┘                 │
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
           ┌──────────────┐  ┌──────────────┐  Cross-Chain
           │   Chain A    │  │   Chain B    │   via CCIP
           │ TokenPool    │  │ TokenPool    │   (preserves
           └──────────────┘  └──────────────┘   interest rate)
```

## 📝 Contracts

### RebaseToken.sol

The core ERC20 token with automatic interest accrual.

**Key Features:**
- Linear interest model (default: 5e10 per second)
- Per-user interest rates
- Interest accrues on every transfer, mint, or burn
- Principal balance tracking separate from total balance
- Access control for minting/burning operations

**Key Functions:**
```solidity
function balanceOf(address account) public view returns (uint256)
function principalBalanceOf(address account) public view returns (uint256)
function mint(address to, uint256 amount) external
function mintWithInterestRate(address to, uint256 amount, uint256 interestRate) external
function burn(address from, uint256 amount) external
function setInterestRate(uint256 newInterestRate) external
```

### Vault.sol

ETH-backed vault for minting and redeeming rebase tokens.

**Key Features:**
- Deposit ETH to receive rebase tokens
- Redeem tokens for ETH with accrued interest
- 1:1 initial minting ratio

**Key Functions:**
```solidity
function deposit() external payable
function redeem(uint256 amount) external
```

### RebaseTokenPool.sol

Custom CCIP token pool for cross-chain transfers.

**Key Features:**
- Implements Chainlink CCIP TokenPool interface
- Preserves user interest rates during cross-chain transfers
- Burns tokens on source chain, mints on destination chain

**Key Functions:**
```solidity
function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external
function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external
```

## 🔧 How It Works

### Interest Accrual Model

The token uses a **linear interest model**:

```
Interest = Principal × InterestRate × TimeDelta
```

Where:
- `Principal`: The base token amount
- `InterestRate`: Per-second interest rate (default: 5e10 = 0.00000005 per second)
- `TimeDelta`: Time since last update in seconds

**Example:**
- Deposit: 1 ETH
- Interest Rate: 5e10 per second
- Time: 30 days (2,592,000 seconds)
- Interest: 1 ETH × 5e10 × 2,592,000 = 0.1296 ETH
- Total Balance: 1.1296 ETH

### Interest Rate Propagation

When tokens are transferred:
1. **Sender**: Interest is minted and added to principal balance
2. **Receiver** (if first time): Inherits sender's interest rate
3. **Receiver** (existing): Continues with existing interest rate

### Cross-Chain Transfers

1. User initiates CCIP transfer on source chain
2. Source `RebaseTokenPool`:
   - Captures user's interest rate
   - Burns tokens from the pool
   - Encodes interest rate in `destPoolData`
3. CCIP relayers deliver message to destination chain
4. Destination `RebaseTokenPool`:
   - Decodes interest rate from `sourcePoolData`
   - Mints tokens to receiver with preserved interest rate

## 🚀 Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd rebase-token

# Install dependencies
forge install

# Build contracts
forge build
```

### Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Chainlink Contracts](https://github.com/smartcontractkit/chainlink)
- [Chainlink Local](https://github.com/smartcontractkit/chainlink-local)
- [Forge Standard Library](https://github.com/foundry-rs/forge-std)

## 🧪 Testing

The project includes comprehensive test coverage:

### Run All Tests

```bash
forge test
```

### Run with Verbosity

```bash
forge test -vvv
```

### Test Coverage

```bash
forge coverage
```

### Key Test Files

- `test/RebaseTokenTest.t.sol`: Core token functionality tests
  - Linear interest accrual
  - Deposit and redeem flows
  - Transfer mechanics
  - Access control
  
- `test/CrossChain.t.sol`: Cross-chain transfer tests
  - CCIP integration
  - Interest rate preservation
  - Multi-chain deployment

### Fuzz Testing

The project uses Foundry's fuzz testing with 1024 runs:

```bash
# Configured in foundry.toml
[fuzz]
runs = 1024
fail_on_revert = true
```

## 📦 Deployment

### Configuration

Update `foundry.toml` with your RPC endpoints:

```toml
rpc_endpoints = {
    sepolia-eth = "YOUR_SEPOLIA_RPC_URL",
    arb-sepolia = "YOUR_ARBITRUM_SEPOLIA_RPC_URL"
}
```

### Deployment Scripts

The project includes deployment scripts in the `script/` directory:

#### 1. Deploy Token and Vault

```bash
forge script script/Deployer.s.sol:VaultDeployer --rpc-url <network> --broadcast
```

#### 2. Deploy Token Pool

```bash
forge script script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url <network> --broadcast
```

#### 3. Configure Cross-Chain Pools

```bash
forge script script/ConfigurePool.s.sol --rpc-url <network> --broadcast
```

### Deployment Checklist

1. ✅ Deploy RebaseToken on each chain
2. ✅ Deploy Vault (optional, for ETH backing)
3. ✅ Deploy RebaseTokenPool on each chain
4. ✅ Grant MINT_AND_BURN_ROLE to Vault and TokenPool
5. ✅ Register token with CCIP TokenAdminRegistry
6. ✅ Set token pool in TokenAdminRegistry
7. ✅ Configure cross-chain routes in each TokenPool
8. ✅ Set up rate limiters (optional)

## 💡 Usage

### For Users

#### Deposit ETH and Receive Rebase Tokens

```solidity
// Deposit 1 ETH
vault.deposit{value: 1 ether}();
```

#### Check Balance (with Interest)

```solidity
uint256 balance = rebaseToken.balanceOf(user);
uint256 principal = rebaseToken.principalBalanceOf(user);
// balance > principal (interest has accrued)
```

#### Redeem Tokens for ETH

```solidity
// Redeem all tokens
vault.redeem(type(uint256).max);

// Or redeem specific amount
vault.redeem(1 ether);
```

#### Transfer Tokens

```solidity
// Regular transfer
rebaseToken.transfer(recipient, amount);

// Transfer all (including interest)
rebaseToken.transfer(recipient, type(uint256).max);
```

#### Bridge Tokens Cross-Chain

```solidity
// Approve router
rebaseToken.approve(routerAddress, amount);

// Prepare CCIP message
Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
    receiver: abi.encode(recipient),
    data: "",
    tokenAmounts: tokenAmounts,
    extraArgs: "",
    feeToken: linkAddress
});

// Send via CCIP
IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
```

### For Contract Owners

#### Set Interest Rate (can only decrease)

```solidity
rebaseToken.setInterestRate(4e10); // Decrease from 5e10 to 4e10
```

#### Grant Minting Permissions

```solidity
rebaseToken.grantMintAndBurnRole(vaultAddress);
rebaseToken.grantMintAndBurnRole(tokenPoolAddress);
```

### For Developers

#### Query Interest Rate

```solidity
uint256 globalRate = rebaseToken.getInterestRate();
uint256 userRate = rebaseToken.getUserInterestRate(userAddress);
uint256 lastUpdate = rebaseToken.getUserLastUpdateTimestamp(userAddress);
```

#### Mint with Custom Interest Rate

```solidity
// Only callable by addresses with MINT_AND_BURN_ROLE
rebaseToken.mintWithInterestRate(recipient, amount, customRate);
```

## 🔒 Security

### Access Control

- **Owner**: Can set interest rates and grant roles
- **MINT_AND_BURN_ROLE**: Can mint and burn tokens (granted to Vault and TokenPool)

### Key Security Features

1. **Interest Rate Protection**: Can only decrease, never increase
2. **Role-Based Permissions**: Minting/burning restricted to authorized contracts
3. **Reentrancy Protection**: Inherited from OpenZeppelin's ERC20 implementation
4. **Integer Overflow Protection**: Solidity 0.8.20+ built-in checks

### Audit Status

⚠️ **This project has not been audited.** Use at your own risk.

### Known Considerations

1. **Interest Rate Precision**: Uses 18 decimals for interest rate calculations
2. **Maximum Amount Support**: Uses `type(uint256).max` to transfer/redeem all tokens
3. **Time-Dependent**: Interest calculation depends on `block.timestamp`
4. **Cross-Chain Synchronization**: Interest rates are preserved but not synchronized across chains

## 📊 Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `PRECISION_FACTOR` | 10^18 | Precision for interest calculations |
| Default Interest Rate | 5e10 | 0.00000005 per second (~13% APY) |
| `MINT_AND_BURN_ROLE` | keccak256("MINT_AND_BURN_ROLE") | Role for minting/burning |

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `forge test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Chainlink CCIP Documentation](https://docs.chain.link/ccip)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Foundry Book](https://book.getfoundry.sh/)

## ⚠️ Disclaimer

This code is provided as-is for educational and development purposes. It has not been audited and should not be used in production without proper security review and testing.
