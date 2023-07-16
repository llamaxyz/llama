# Llama Scripts

The current Llama scripts are:
* `DeployLlamaFactory.s.sol`, which deploys the LlamaFactory, logic/implementation contracts, and LlamaLens to new chains
* `CreateAction.s.sol`, which creates actions on the root LlamaCore to deploy
  new LlamaCore instances

Additionally, both `DeployLlamaFactory` and `CreateAction` are called during the test bootstrap process to establish the state against which most of the test suite runs.

## Deployment Configurations

Before running any script that deploys a new Llama instance, it is important to understand the one special-cased role ID and permission ID in the system.

A newly deployed Llama instance may be unusable if not properly configured. In particular, the core requirements are:
- Someone can call the policy's `setRolePermission` method.
- The strategy used when calling that method can be executed.

With those two requirements satisfied, new permissions can be assigned to reconfigure the instance with any desired permissions.
Therefore, we help enforce this at the protocol level with the following behavior:

- We refer to the very first strategy in the `initialStrategies` array as the `bootstrapStrategy` because this strategy can be used (in tandem with the below) to bootstrap the instance to any configuration.
- Role ID 1 is special-cased to be the corresponding `bootstrapRole` because this role can be used (in tandem with the above) to bootstrap the instance to any configuration.
- The `LlamaFactory` internal `_deploy` method, will verify that at least 1 role holder in the `initialRoleHolders` array has the `bootstrapRole` role ID of 1. If this is not the case, deployment reverts.
- The `_deploy` method will then deploy and initialize the `LlamaPolicy` contract, then it will deploy and initialize the `LlamaCore` contract.
- Initialization of the `LlamaCore` contract is where the `bootstrapStrategy` is deployed, so this call computes and returns the `bootstrapPermissionId`, which is the permission ID (the `(target, selector, strategy)` tuple) that can be used to call the `setRolePermission` method.
- Because the policy and core need to know about each other, we now finalize initialization of the `LlamaPolicy` contract by calling the `finalizeInitialization` method on it. This takes the address of the `LlamaCore` contract, along with the `bootstrapPermissionId` computed above.

A key part of ensuring the instance is not misconfigured is ensuring that the `bootstrapStrategy` is a valid strategy that can actually be executed. This is checked in deploy scripts, because the strategy can have any logic, so it's not necessarily possible to check this at the protocol level.

## DeployLlamaFactory

To perform a dry-run of the `DeployLlamaFactory` script on a network, first set the
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

The `CreateAction` script presupposes that the `DeployLlamaFactory` script has already
been run for a given chain. So follow the instructions above before continuing
here.

Once `DeployLlamaFactory` has been run, set a `SCRIPT_DEPLOYER_ADDRESS` in your `.env` that corresponds to the `SCRIPT_PRIVATE_KEY` that you want to sign the action-creation transactions.
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
