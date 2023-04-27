# Llama Scripts

The current Llama scripts are:
* `DeployLlama.s.sol`, which deploys the LlamaFactory, logic/implementation contracts, and LlamaLens to new chains
* `CreateAction.s.sol`, which creates actions on the root LlamaCore to deploy
  new LlamaCore instances

Additionally, both `DeployLlama` and `CreateAction` are called during the test bootstrap process to establish the state against which most of the test suite runs.

## DeployLlama

To perform a dry-run of the `DeployLlama` script on a network, first set the
`SCRIPT_RPC_URL` variable in your `.env` file to a local node, e.g. anvil.

To start anvil:

```shell
# Start anvil, forking from the desired network.
anvil --fork-url $OPTIMISM_RPC_URL
```
Next, set `SCRIPT_PRIVATE_KEY` in your `.env` file. For a dry run, you can just
use one of the pre-provisioned private keys that anvil provides on startup.

Then, to execute the call:

```shell
just dry-run-deploy
```

If that looked good, try broadcasting the script transactions to the local node.
With the local node URL still set as `SCRIPT_RPC_URL` in your `.env` file:

```shell
just deploy
```

When you are ready to deploy to a live network, simply follow the steps above
but with `SCRIPT_RPC_URL` pointing to the appropriate node and
`SCRIPT_PRIVATE_KEY` set to the deployer private key.

## CreateAction

The `CreateAction` script presupposes that the `DeployLlama` script has already
been run for a given chain. So follow the instructions above before continuing
here.

Once `DeployLlama` has been run, set a `SCRIPT_DEPLOYER_ADDRESS` in your `.env` that corresponds to the `SCRIPT_PRIVATE_KEY` that you want to sign the action-creation transactions.
It does *not* have to be the same address that did the initial deploy, but it could be.

Once your `.env` file is configured and anvil is running, you can perform a dry
run like this:

```shell
just dry-run-create-new-llama
```

If all goes well, broadcast as follows:

```shell
just create-new-llama
```
