# Scripts

By default [LlamaExecutor](https://github.com/llamaxyz/llama/blob/main/src/LlamaExecutor.sol) will call its targets using a low level `call` unless that target is a script.
Scripts are target contracts that are called using `delegatecall` instead of `call`.
To specify a target as a script, a policyholder must create an action that calls the `setScriptAuthorization` function on `LlamaCore` with the target address and `isAuthorized` set to `true`.
Targets can be removed as scripts by creating an action that calls the `setScriptAuthorization` function with the same target address and `isAuthorized` set to `false`.

Scripts allow Llama instances to execute arbitrary code in the context of `LlamaExecutor`.
This makes them useful for defining repeatable workflows that aren't included in the `LlamaCore`, `LlamaPolicy`, or in the instance's protocol contracts.

## Security

Any low level calls made by scripts will use the instance's executor as `msg.sender`.
Policyholders should review target contracts being authorized to ensure that this power isn't being abused.

Llama's architecture is designed to limit this attack surface area.
Since the `executeAction` on `LlamaCore` does not call targets directly and only interacts with external contracts through the `LlamaExecutor`, scripts can't access `LlamaCore`'s storage.

## Examples

All the scripts listed below have been audited and deployed to all networks supported by Llama unless otherwise stated.
The contract addresses can be found in the [deployments section](https://com/llamaxyz/llama/blob/main/README.md#deployments) of the README.

- **LlamaGovernanceScript:**: defines common governance workflows and batch functions for managing a Llama instance.
- **LlamaAccountTokenDelegationScript:** leverages the `LlamaAccount` arbitrary execute function to allow users to delegate governance tokens from their Llama accounts. This is useful if an instance is using a standard `LlamaAccount` and doesn't want to transfer assets.
- **LlamaInstanceConfigScriptTemplate:** can be used in conjunction with [ConfigureAdvancedLlamaInstance](https://github.com/llamaxyz/llama/blob/main/script/ConfigureAdvancedLlamaInstance.s.sol) to deploy and configure a new Llama instance by writing code. This is more expressive than the default JSON-based configurations. 
