# VertexStrategy

[Git Source](https://github.com/llama-community/vertex-v1/blob/693b03f6823cb240f992102042b3702c0c97cf44/src/strategy/VertexStrategy.sol)

**Inherits:**
[IVertexStrategy](/src/strategy/IVertexStrategy.sol/contract.IVertexStrategy.md)

**Author:**
Llama (vertex@llama.xyz)

This is the template for Vertex strategies which determine the rules of an action's process.

## State Variables

### ONE_HUNDRED_IN_BPS

Equivalent to 100%, but in basis points.

```solidity
uint256 public constant ONE_HUNDRED_IN_BPS = 100_00;
```

### DEFAULT_OPERATOR

Permission signature value that determines weight of all unspecified policyholders.

```solidity
bytes8 public constant DEFAULT_OPERATOR = 0xffffffffffffffff;
```

### queuingDuration

Minimum time between queueing and execution of action.

```solidity
uint256 public immutable queuingDuration;
```

### expirationDelay

Time after executionTime that action can be executed before permanently expiring.

```solidity
uint256 public immutable expirationDelay;
```

### isFixedLengthApprovalPeriod

Can action be queued before approvalEndTime.

```solidity
bool public immutable isFixedLengthApprovalPeriod;
```

### vertex

The strategy's Vertex system.

```solidity
IVertexCore public immutable vertex;
```

### approvalPeriod

Length of approval period in blocks.

```solidity
uint256 public immutable approvalPeriod;
```

### policy

Policy NFT for this Vertex system.

```solidity
VertexPolicyNFT public immutable policy;
```

### minApprovalPct

Minimum percentage of total approval weight / total approval supply at createdBlockNumber of the action for it to be queued. In bps, where
100_00 == 100%.

```solidity
uint256 public immutable minApprovalPct;
```

### minDisapprovalPct

Minimum percentage of total disapproval weight / total disapproval supply at createdBlockNumber of the action for it to be canceled. In bps,
where 100_00
== 100%.

```solidity
uint256 public immutable minDisapprovalPct;
```

### approvalWeightByPermission

Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.

```solidity
mapping(bytes8 => uint248) public approvalWeightByPermission;
```

### disapprovalWeightByPermission

Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.

```solidity
mapping(bytes8 => uint248) public disapprovalWeightByPermission;
```

### approvalPermissions

List of all permission signatures that are eligible for approvals.

```solidity
bytes8[] public approvalPermissions;
```

### disapprovalPermissions

List of all permission signatures that are eligible for disapprovals.

```solidity
bytes8[] public disapprovalPermissions;
```

## Functions

### constructor

Order is of WeightByPermissions is critical. Weight is determined by the first specific permission match.

```solidity
constructor(Strategy memory strategyConfig, VertexPolicyNFT _policy, IVertexCore _vertex);
```

### isActionPassed

Get whether an action has passed the approval process.

```solidity
function isActionPassed(uint256 actionId) external view override returns (bool);
```

**Parameters**

| Name       | Type      | Description       |
| ---------- | --------- | ----------------- |
| `actionId` | `uint256` | id of the action. |

**Returns**

| Name     | Type   | Description                                                               |
| -------- | ------ | ------------------------------------------------------------------------- |
| `<none>` | `bool` | Boolean value that is true if the action has passed the approval process. |

### isActionCanceletionValid

Get whether an action has eligible to be canceled.

```solidity
function isActionCanceletionValid(uint256 actionId) external view override returns (bool);
```

**Parameters**

| Name       | Type      | Description       |
| ---------- | --------- | ----------------- |
| `actionId` | `uint256` | id of the action. |

**Returns**

| Name     | Type   | Description                                               |
| -------- | ------ | --------------------------------------------------------- |
| `<none>` | `bool` | Boolean value that is true if the action can be canceled. |

### getApprovalWeightAt

Get the weight of an approval of a policyholder at a specific block number.

```solidity
function getApprovalWeightAt(address policyholder, uint256 blockNumber) external view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                           |
| -------------- | --------- | ----------------------------------------------------- |
| `policyholder` | `address` | Address of the policyholder.                          |
| `blockNumber`  | `uint256` | The block number at which to get the approval weight. |

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `uint256` | The weight of the policyholder's approval. |

### getDisapprovalWeightAt

Get the weight of a disapproval of a policyholder at a specific block number.

```solidity
function getDisapprovalWeightAt(address policyholder, uint256 blockNumber) external view returns (uint256);
```

**Parameters**

| Name           | Type      | Description                                              |
| -------------- | --------- | -------------------------------------------------------- |
| `policyholder` | `address` | Address of the policyholder.                             |
| `blockNumber`  | `uint256` | The block number at which to get the disapproval weight. |

**Returns**

| Name     | Type      | Description                                   |
| -------- | --------- | --------------------------------------------- |
| `<none>` | `uint256` | The weight of the policyholder's disapproval. |

### isApprovalQuorumValid

Determine if the total weight of policyholders in support of an approval has reached quorum.

```solidity
function isApprovalQuorumValid(uint256 actionId, uint256 approvals) public view override returns (bool);
```

**Parameters**

| Name        | Type      | Description               |
| ----------- | --------- | ------------------------- |
| `actionId`  | `uint256` |                           |
| `approvals` | `uint256` | total weight of approvals |

**Returns**

| Name     | Type   | Description                                                                 |
| -------- | ------ | --------------------------------------------------------------------------- |
| `<none>` | `bool` | Boolean value that is true if the approval of an action has reached quorum. |

### isDisapprovalQuorumValid

Determine if the total weight of policyholders in support of a disapproval has reached quorum.

```solidity
function isDisapprovalQuorumValid(uint256 actionId, uint256 disapprovals) public view override returns (bool);
```

**Parameters**

| Name           | Type      | Description                  |
| -------------- | --------- | ---------------------------- |
| `actionId`     | `uint256` |                              |
| `disapprovals` | `uint256` | total weight of disapprovals |

**Returns**

| Name     | Type   | Description                                                                    |
| -------- | ------ | ------------------------------------------------------------------------------ |
| `<none>` | `bool` | Boolean value that is true if the disapproval of an action has reached quorum. |

### getMinimumAmountNeeded

Determine the minimum weight needed for an action to reach quorum.

```solidity
function getMinimumAmountNeeded(uint256 supply, uint256 minPct) public pure override returns (uint256);
```

**Parameters**

| Name     | Type      | Description                                               |
| -------- | --------- | --------------------------------------------------------- |
| `supply` | `uint256` | Total number of policyholders eligible for participation. |
| `minPct` | `uint256` |                                                           |

**Returns**

| Name     | Type      | Description                              |
| -------- | --------- | ---------------------------------------- |
| `<none>` | `uint256` | The total weight needed to reach quorum. |

### getApprovalPermissions

Get the list of all permission signatures that are eligible for approvals.

```solidity
function getApprovalPermissions() public view override returns (bytes8[] memory);
```

**Returns**

| Name     | Type       | Description                                                            |
| -------- | ---------- | ---------------------------------------------------------------------- |
| `<none>` | `bytes8[]` | The list of all permission signatures that are eligible for approvals. |

### getDisapprovalPermissions

Get the list of all permission signatures that are eligible for disapprovals.

```solidity
function getDisapprovalPermissions() public view override returns (bytes8[] memory);
```

**Returns**

| Name     | Type       | Description                                                               |
| -------- | ---------- | ------------------------------------------------------------------------- |
| `<none>` | `bytes8[]` | The list of all permission signatures that are eligible for disapprovals. |

## Errors

### InvalidPermissionSignature

```solidity
error InvalidPermissionSignature();
```
