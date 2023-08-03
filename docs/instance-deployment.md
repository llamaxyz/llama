# Instance Deployment

To use Llama to govern your smart contract system's privileged functions, you must first deploy your own Llama instance.

## Key Concepts

- [Llama Factory](https://github.com/llamaxyz/llama/blob/main/src/LlamaFactory.sol): The `LlamaFactory` contract is the canonical deployer for Llama instances and there will be one factory per chain supported by Llama.
- [Llama Instance](https://github.com/llamaxyz/llama/blob/main/diagrams/llama-overview.png): A Llama instance is a self managed cluster of contracts that enables onchain access control over privileged functions. The main parts of an instance are the `Core`, `Policy`, and `Executor` contracts.

To deploy, call the `deploy` method on [the Llama Factory contract](https://github.com/llamaxyz/llama/blob/main/src/LlamaFactory.sol).
Deploying Llama instances requires some configuration and set up, since we have to initialize the system with a set of policyholders, roles, and permissions.

## Configuration

In this section we will dive into configuring your Llama instance.

### Instance Config

The deploy method accepts a configuration struct called `LlamaInstanceConfig`.
Lets look into this struct to see what data it holds.

```solidity
struct LlamaInstanceConfig {
  string name;
  ILlamaStrategy strategyLogic;
  ILlamaAccount accountLogic;
  bytes[] initialStrategies;
  bytes[] initialAccounts;
  LlamaPolicyConfig policyConfig;
}
```

Lets look at each field one by one:

- **Name:** The name of the Llama instance.
- **Strategy Logic:** The initial strategy implementation (logic) contract. Look at the [strategy comparison table](https://github.com/llamaxyz/llama/blob/main/docs/strategies.md#comparison-table) to learn about their differences.
- **Account Logic:** The initial account implementation (logic) contract. There is currently only one account implementation contract but there may be more in the future.
- **Initial Strategies:** An array of initial strategy configurations. All configurations are for the `strategyLogic` defined above. If you'd like to configure other strategies with different logic contracts, that must be done in an action after deployment
  - Each strategy has a `Config` struct that defines what data is required to initialize the strategy. Each config struct can be unique, but lets look at an example JSON blob which is intended to configure a [relative strategy](https://github.com/llamaxyz/llama/blob/main/src/strategies/relative/LlamaRelativeStrategyBase.sol):

    ```JSON
    "initialStrategies": [
        {
            "approvalPeriod": 172800,
            "approvalRole": 1,
            "disapprovalRole": 3,
            "expirationPeriod": 691200,
            "forceApprovalRoles": [],
            "forceDisapprovalRoles": [],
            "isFixedLengthApprovalPeriod": true,
            "minApprovalPct": 4000,
            "minDisapprovalPct": 5100,
            "queuingPeriod": 345600
        }
    ]
    ```

  - You can read more about what each of these fields mean [here](https://github.com/llamaxyz/llama/blob/main/docs/strategies.md)
  
- **Initial Accounts:** An array of initial account configurations.
  - All that is needed to configure an account is to give it a name; here is an example JSON blob that configures two accounts:

  ```JSON
    "initialAccounts": [
      {
        "name": "Mock Protocol Treasury"
      },
      {
        "name": "Mock Protocol Grants"
      }
    ]
  ```

- **Policy Config:** The configuration of the instance's policy. Since the policy config struct is fairly complex, we will give it it's own section.

### Policy Config

The policy config takes the form of the following struct:

```solidity
  struct LlamaPolicyConfig {
    RoleDescription[] roleDescriptions; // The initial role descriptions.
    RoleHolderData[] roleHolders; // The `role`, `policyholder`, `quantity` and `expiration` of the initial role holders.
    RolePermissionData[] rolePermissions; // The `role`, `permissionData`, and  the `hasPermission` boolean.
    string color; // The primary color of the SVG representation of the instance's policy (e.g. #00FF00).
    string logo; // The SVG string representing the logo for the deployed Llama instance's NFT.
  } 
```

- **Role Descriptions:** An array of the initial role descriptions.
  - `RoleDescription` is a [user-defined value type](https://docs.soliditylang.org/en/v0.8.19/types.html#user-defined-value-types) for `bytes32`, meaning descriptions are limited to strings with a length of 32 bytes.
  - Example JSON blob for role descriptions:

  ```JSON
  "initialRoleDescriptions": [
    "ActionCreator",
    "Approver",
    "Disapprover"
  ]
  ```

- **Role Holders:** The `role`, `policyholder`, `quantity` and `expiration` of the initial role holders.
  - Example JSON blob for `RoleHolderData`:
  
  ```JSON
  "initialRoleHolders": [
    {
      "policyholder": "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
      "expiration": 18446744073709551615,
      "quantity": 1,
      "role": 1
    }
  ]
  ```

  - In this example, we are assigning the policyholder `0xdeadbeef` role 1 with the max expiration (`type(uint64).max`) and a quantity of 1.

- **Role Permissions** The `role`, `permissionData` and whether the initial roles have the permission of the role permissions.
  - `role` is the role ID to be assigned
  - `permissionData` is the `(target, selector, strategy)` tuple that will be hashed to generate the permission ID to assign the role.
    - `selector`: The function selector being permissioned.
    - `strategy`: The strategy address to be used for this kind of action.
    - `target`: The target contract address.
  - `hasPermission` will always be set to true during deployments.
  - Example JSON blob for `RolePermissionData`:
  
  ```JSON
  "initialRolePermissions": [
    {
      "role": 1,
      "permissionData": {
        "selector": "0x51288356",
        "strategy": "0x9c7e3be11cB2f4D9A7fA0643D7b76569AF838782",
        "target": "0x6aDaEfec2bC0ee7003e48320d4a346a6Be882950"
      },
      "hasPermission": true
    }
  ]
  ```

- **Color:** The primary color of the SVG representation of the instance's policy specified as a hex rgb value (e.g. #00FF00).
- **Logo:** The SVG string representing the logo for the deployed Llama instance's NFT.

## Deployed Contracts

After the `deploy` function runs, the following contracts will have been deployed:

- `LlamaCore`
- `LlamaPolicy`
- `LlamaExecutor`
- `LlamaPolicyMetadata`
- At least one `strategy` contract, optionally more
- Optional `account` contract(s)
