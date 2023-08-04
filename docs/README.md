# Overview

## Securing onchain governance

Llama is an onchain governance and access control framework for smart contract protocols.

Using Llama, teams can deploy fully independent instances that define granular roles and permissions for executing actions. 

Instances can adapt to a changing environment by incrementally adding new participants and expanding the the set of available actions. Actions can be any operation that is represented by invoking a smart contract function. This includes transferring funds, updating a registry, changing protocol parameters, or activating an emergency pause.



## How does Llama work?

![Llama Overview](https://github.com/llamaxyz/llama/blob/main/diagrams/llama-overview.png)

These instances contain a core contract for managing the action process from creation to execution, a non-transferable NFT contract that encodes roles and permissions for policyholders, and modular strategies to define action execution rules.

## Why Llama?

## Next steps

To learn more about how the Llama framework works, read our documentation and use the [forge doc](https://github.com/llamaxyz/llama#documentation) command to generate and serve the Llama smart contract reference.

- [Instance deployment](https://github.com/llamaxyz/llama/blob/main/docs/instance-deployment.md)
- [Actions](https://github.com/llamaxyz/llama/blob/main/docs/actions.md)
- [Policies](https://github.com/llamaxyz/llama/blob/main/docs/policies.md)
- [Strategies](https://github.com/llamaxyz/llama/blob/main/docs/strategies.md)
