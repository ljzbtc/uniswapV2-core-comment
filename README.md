# Foundry Starter Kit 

This is my custom Foundry starter kit for daily use in smart contract development and deployment.

## Usage

### Deploying and Verifying a Contract

1. Source your environment variables:

source .env

2. Run the deployment script:

forge script --account dev --chain sepolia script/deployer.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --sender 0x2cf56496f155914d84e6eda6e2c0076aeae5b0f0

### Verifying an Already Deployed Contract

To verify a contract that has already been deployed:
forge verify-contract 0x50c56eb8e5c30992cba712246b72b94968263bb9 TradeDevil --chain sepolia

Replace the address and contract name with your specific values.



