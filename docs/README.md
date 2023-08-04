# Overview

## Securing onchain governance

Llama is an onchain governance and access control framework for smart contract protocols.

Using Llama, teams can deploy fully independent instances that define granular roles and permissions for executing actions. 

Instances can adapt to a changing environment by incrementally adding new participants and expanding the set of available actions. Actions can be any operation that is represented by invoking a smart contract function. This includes transferring funds, updating a registry, changing protocol parameters, or activating an emergency pause.

## How does Llama work?

![Llama Overview](https://github.com/llamaxyz/llama/blob/main/diagrams/llama-overview.png)

A Llama instance consists of a modular system of contracts with an immutable core and interchangeable periphery. `LlamaCore`, `LlamaPolicy`, and the strategy contracts work together to establish and enforce the rules for how actions progress from creation to execution. A successful action execution results in the `LlamaExecutor` calling the specified target contract with the agreed upon transaction calldata. Since the executor is the single exit point of an instance, ownership of external functions needs to only be set once.

## Why Llama?



## Next steps

To learn more about how the Llama framework works, read our documentation and use the [forge doc](https://github.com/llamaxyz/llama#documentation) command to generate and view the Llama smart contract reference.

- [Instance deployment](https://github.com/llamaxyz/llama/blob/main/docs/instance-deployment.md)
- [Actions](https://github.com/llamaxyz/llama/blob/main/docs/actions.md)
- [Policies](https://github.com/llamaxyz/llama/blob/main/docs/policies.md)
- [Strategies](https://github.com/llamaxyz/llama/blob/main/docs/strategies.md)
