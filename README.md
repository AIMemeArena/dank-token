# Multichain Token Contracts

This repository contains smart contracts for implementing multichain token deployments using two different models: Hub and Spoke, and Burn and Mint.

## Contracts

### HubToken

`HubToken` is designed for the Hub and Spoke model. It represents the central token on the hub chain where the total supply is maintained.

### PeerToken

`PeerToken` is a flexible contract that can be deployed as either a spoke token in the Hub and Spoke model or as a token in the Burn and Mint model.

## Read more about deployment models

[Deployment Models](https://docs.wormhole.com/wormhole/native-token-transfers/overview/deployment-models) 

## Usage

### Hub and Spoke Model

1. Deploy `HubToken` on the main chain (Hub chain).
2. Deploy `PeerToken` on each spoke chain.
3. Configure the minter address in each `PeerToken` to control minting permissions.

### Burn and Mint Model

1. Deploy `PeerToken` contracts on all participating chains.
2. Configure the minter address in each `PeerToken` to control minting permissions.

## Deployment

To deploy these contracts, you can use Forge with a Ledger hardware wallet for enhanced security. Here's an example of how to deploy the HubToken contract:

[Install Foundry](https://book.getfoundry.sh/getting-started/installation)

```bash
forge create \
    --rpc-url $RPC_URL \
    --ledger \
    --mnemonic-derivation-path "$MNEMONIC_PATH" \
    --verify \
    --constructor-args "$TOKEN_NAME" "$TOKEN_SYMBOL" "$INITIAL_HOLDER" "$MAX_SUPPLY" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    src/DankToken.sol:DankToken
```

Key parameters:
- `--ledger`: Uses Ledger hardware wallet for signing
- `--mnemonic-derivation-path`: Specifies which address to use (default Ethereum path is "m/44'/60'/0'/0/0")
- `--verify`: Automatically verifies contract on Etherscan
- `--etherscan-api-key`: Required for contract verification

For PeerToken deployment, use the same pattern but replace the contract path:

```bash
forge create \
    --rpc-url <RPC_URL> \
    --ledger \
    --mnemonic-derivation-path "m/44'/60'/0'/0/0" \
    --verify \
    --constructor-args "TokenName" "SYMBOL" <MINTER_ADDRESS> <OWNER_ADDRESS> \
    --etherscan-api-key <YOUR_ETHERSCAN_API_KEY> \
    src/PeerToken.sol:PeerToken
```

## Deploy Fair Launch Pool to Base Sepolia

```bash
forge create \
    --rpc-url $BASESEPOLIA_RPC_URL \
    --ledger \
    --mnemonic-derivation-path "$MNEMONIC_PATH" \
    --verify \
    --constructor-args $DANK_TOKEN_ADDRESS $FEE_COLLECTOR_ADDRESS \
    --etherscan-api-key $BASESCAN_API_KEY \
    src/DANKFairLaunch.sol:DANKFairLaunch
```

## Initialize Fair Launch Pool

```bash
cast send $FAIR_LAUNCH_ADDRESS "initializePool()" \
    --ledger \
    --mnemonic-derivation-path "$MNEMONIC_PATH" \
    --rpc-url $BASESEPOLIA_RPC_URL
```
