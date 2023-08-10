# Accounts

Accounts are contracts that can be deployed directly by Llama instances to manage onchain assets. Instances can deploy many accounts and create new types by authorizing additional account logic contracts.
Llama’s recommended account logic contract includes functions to manage native assets (e.g. ETH), ERC-20 tokens, ERC-721 tokens, ERC-1155 tokens, and an arbitrary execute function that can be used to support non–standard token types and extend an account’s functionality.

## Managing Tokens

Instances can receive native assets such as ETH or tokens such as USDC through accounts and use [policies](https://github.com/llamaxyz/llama/blob/main/docs/policies.md) to set permissions on how these tokens can be approved and transferred.

There are separate functions for transfers and approvals, along with functions for ERC-721 and ERC-1155 operator approvals.
There are also additional functions to batch transfer tokens to multiple recipients in a single transaction.

Instances can deploy dedicated accounts for different organizational functions and permission each function independently.
For more granular fund management rules, instances can implement [guards](https://github.com/llamaxyz/llama/blob/main/docs/actions.md#guards) to set requirements based on token amount, frequency of transfer, market conditions, or any other rule(s) that can be expressed as code.

## Arbitrary execute

The account contract also includes an `execute` function that allows for arbitrary calls and code execution. Actions that call this function can be used to call or delegatecall a target contract with specified calldata. This ensures that non-standard tokens will not be stuck in the account and accounts can interact directly with external contracts when necessary.
Allowing delegatecalls means that accounts can expand their functionality over time. They can use periphery contracts that enable token streaming, vesting, swapping, and allow those contracts to execute code in the account’s context. Arbitrary execution is a powerful concept with important security considerations, so best practices should be followed when using this function.

Instances should stick to the [principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege) and limit which policyholders are granted permission to create actions for this function. Guards are recommended to define which targets can be called, whether it uses a call or delegatecall, and to limit acceptable parameters that can be used.
