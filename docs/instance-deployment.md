# Instance Deployment

To use Llama to manage onchain privileged access functions, you must first deploy your own instance.

## Key Concepts

- [Factory](../src/LlamaFactory.sol): The `LlamaFactory` contract is the canonical deployer for Llama instances, and there will be one factory per chain supported by Llama.
- [Instance]((https://github.com/llamaxyz/llama/blob/main/blob/main/diagrams/llama-overview.png)): A Llama instance is a self managed cluster of contracts that enables onchain access control over privileged functions. The main parts of an instance are the `Core`, `Policy`, and `Executor` contracts.

To deploy we can call the `deploy` method on [the Llama Factory contract](../src/LlamaFactory.sol).
Deploying Llama instances requires some configuration and set up, since we have to initialize the system with the base set of permissions and rules describing who can do what.
A list of all official deployed Llama Factory contracts can be found [here](../README.md#Deployments)

## Configuration

In this section we will dive into configuring your Llama instance

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

- **Name**: The name of the Llama instance.
- **Strategy** Logic: The initial strategy implementation (logic) contract. See [here]((../README.md#Deployments)) for a list of deployed strategy logic contracts, and [here](./strategy-comparison.md) learn about their differences.
- **Account Logic**: The initial account implementation (logic) contract. You can find the account logic contract [here]((../README.md#Deployments)), there is currently only one account implementation contract but there may be more in the future.
- **Initial Strategies**: An array of initial strategy configurations.
  - Each strategy has a `Config` struct that defines what data is required to initialize the strategy. Each config struct can be unique, but lets look at an example JSON blob which is intended to configure a [relative strategy](../src/strategies/relative/LlamaRelativeStrategyBase.sol):

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

  - You can read more about what each of these fields mean [here](./strategies.md)
  
- **Initial Accounts**: An array of initial account configurations.
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

- **Policy Config**: The configuration of the instance's policy. Since the policy config struct is fairly complex, we will give it it's own section.

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

- **Role Descriptions**: An array of the initial role descriptions.
  - `RoleDescription` is a UDVT, but functions like a `bytes` string under the hood.
  - Example JSON blob for role descriptions:

  ```JSON
  "initialRoleDescriptions": [
    "ActionCreator",
    "Approver",
    "Disapprover"
  ]
  ```

- **Role Holders**: The `role`, `policyholder`, `quantity` and `expiration` of the initial role holders.
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

  - In this example, we are assigning the policyholder `0xdeadbeef` role 1, with the max expiration (`type(uint64).max`), and a quantity of 1.

TODO: update the Role Permissions section after PR 450 merges

- **Role Permissions** The `role`, `permissionData` and whether the initial roles have the permission of the role permissions.
  - `role` is the role ID to be assigned
  - `permissionData` is the `(target, selector, strategy)` tuple that will be keccak256 hashed to generate the permission ID to assign the role.
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

- **Color**: The primary color of the SVG representation of the instance's policy (e.g. #00FF00).
- **Logo**: The SVG string representing the logo for the deployed Llama instance's NFT.

## Deployed Contracts

After the `deploy` function runs, the following contracts will have been deployed:

- `LlamaCore`
- `LlamaPolicy`
- `LlamaExecutor`
- `LlamaPolicyMetadata`
- At least one `strategy` contract, optionally more
- Optional `account` contract(s)
