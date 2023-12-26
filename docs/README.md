# Overview

## Securing onchain governance

Llama is an onchain governance and access control framework for smart contracts.

Using Llama, teams can deploy fully independent instances that define granular roles and permissions for executing transactions, known as "actions". 

Llama instances can adapt to a changing environment by incrementally adding new participants and expanding the set of available actions. Actions can be any operation that is represented by invoking a smart contract function. This includes transferring funds, updating a registry, changing protocol parameters, or activating an emergency pause.

## How does Llama work?

![Llama Overview](https://github.com/llamaxyz/llama/blob/main/diagrams/llama-overview.png)

A Llama instance consists of a modular system of smart contracts with an immutable core and interchangeable periphery. `LlamaCore` and `LlamaPolicy` work together with strategy and guard contracts to establish and enforce the rules for how actions progress from creation to execution. A successful action execution results in the `LlamaExecutor` calling the specified target contract with the agreed upon transaction calldata. Since the executor is the single exit point of an instance, ownership of external functions only needs to be set once.

Instances can also deploy an arbitrary amount of strategies, accounts, scripts, and guards. Strategies are configured with time period lengths and quorum thresholds that determine how [actions transition between states](https://github.com/llamaxyz/llama/blob/main/diagrams/llama-action-state-machine.png). Accounts are onchain wallets that can receive, transfer, and approve tokens. Scripts are contracts that can be delegatecalled from the executor. This is useful for creating custom instance governance functions that batch multiple operations. Guards are for adding additional safety checks that run at action creation, pre-execution, and post-execution time.

## Why Llama?

Before building Llama, we contributed to many leading protocols and communities. What we built is a response to our experience with the limitations of existing onchain governance solutions. We’re building the framework we wish we had.

Legacy governance systems helped develop many foundational standards, but either trend towards high operational overhead or centralization. Llama is designed for protocols to start simple, but progressively decentralize decision-making. Decentralization is achieved through fine-grained access control, so each governance participant is granted the minimum power needed to perform its function. This precision is meant to help instances manage operational complexity, while preserving strong user guarantees.

By leveraging the transparency of onchain execution and the safety guarantees of timelocks and vetoes, Llama provides a flexible governance toolkit for protocols. Features like expressive function-specific safeguards, customizable strategies, and the ability to programmatically control funds, allow any onchain organization with the need for privileged access to use Llama to secure their operations.

## Next steps

To learn more about how the Llama framework works, read our documentation and use the [forge doc](https://github.com/llamaxyz/llama#documentation) command to generate and view the Llama smart contract reference.

- [Actions](https://github.com/llamaxyz/llama/blob/main/docs/actions.md)
- [Policies](https://github.com/llamaxyz/llama/blob/main/docs/policies.md)
- [Strategies](https://github.com/llamaxyz/llama/blob/main/docs/strategies.md)
- [Accounts](https://github.com/llamaxyz/llama/blob/main/docs/accounts.md)
- [Instance deployment](https://github.com/llamaxyz/llama/blob/main/docs/instance-deployment.md)
- [Scripts](https://github.com/llamaxyz/llama/blob/main/docs/scripts.md)
