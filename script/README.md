# Vertex Scripts

There is currently only one script, `DeployVertex.s.sol`. It serves two purposes:
* to deploy the VertexFactory, logic/implementation contracts, and VertexLens to new chains
* to establish our base test setup against which most tests are run

## Running Scripts

To perform a dry-run of the `DeployVertex` script on a network:

```shell
# Start anvil, forking from the desired network.
anvil --fork-url $OPTIMISM_RPC_URL

# In a separate terminal, perform a dry run of the script.
# You can use one of the private keys anvil provides on startup.
forge script script/DeployVertex.s.sol
  --rpc-url "http://127.0.0.1:8545"
  --private-key $DEPLOYER_PRIVATE_KEY \
  -vvvv

# If the dry-run looked good, perform a deployment to the local fork on anvil.
# This WILL NOT broadcast the script transactions on the network.
forge script script/DeployVertex.s.sol \
  --rpc-url "http://127.0.0.1:8545" \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  -vvvv
```

When you are ready to deploy to a live network:

```shell
# First, perform a dry run of the script against the live network with the
# desired deployer as the sender.
forge script script/DeployVertex.s.sol
  --rpc-url $OPTIMISM_RPC_URL
  --sender $DEPLOYER_ADDRESS
  -vvvv

# If the dry-run looked good, we're ready to broadcast to the live network.
forge script script/DeployVertex.s.sol \
  --rpc-url $OPTIMISM_RPC_URL
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  -vvvv
```
