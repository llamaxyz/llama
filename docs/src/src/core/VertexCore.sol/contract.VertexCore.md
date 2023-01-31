# VertexCore
[Git Source](https://github.com/llama-community/vertex-v1/blob/1f84b899cb64edff9bc5bc06a6870e26d69dd1a0/src/core/VertexCore.sol)

**Inherits:**
[IVertexCore](/src/core/IVertexCore.sol/contract.IVertexCore.md)

**Author:**
Llama (vertex@llama.xyz)

Main point of interaction with a Vertex system.


## State Variables
### DOMAIN_TYPEHASH
EIP-712 base typehash.


```solidity
bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
```


### APPROVAL_EMITTED_TYPEHASH
EIP-712 approval typehash.


```solidity
bytes32 public constant APPROVAL_EMITTED_TYPEHASH = keccak256("PolicyholderApproved(uint256 id,bool support)");
```


### DISAPPROVAL_EMITTED_TYPEHASH
EIP-712 disapproval typehash.


```solidity
bytes32 public constant DISAPPROVAL_EMITTED_TYPEHASH = keccak256("PolicyholderDisapproved(uint256 id,bool support)");
```


### ONE_HUNDRED_IN_BPS
Equivalent to 100%, but scaled for precision


```solidity
uint256 public constant ONE_HUNDRED_IN_BPS = 100_00;
```


### policy
The NFT contract that defines the policies for this Vertex system.


```solidity
VertexPolicyNFT public immutable policy;
```


### name
Name of this Vertex system.


```solidity
string public name;
```


### actionsCount
The current number of actions created.


```solidity
uint256 public actionsCount;
```


### actions
Mapping of actionIds to Actions.


```solidity
mapping(uint256 => Action) public actions;
```


### approvals
Mapping of actionIds to polcyholders to approvals.


```solidity
mapping(uint256 => mapping(address => Approval)) public approvals;
```


### disapprovals
Mapping of action ids to polcyholders to disapprovals.


```solidity
mapping(uint256 => mapping(address => Disapproval)) public disapprovals;
```


### authorizedStrategies
Mapping of all authorized strategies.


```solidity
mapping(VertexStrategy => bool) public authorizedStrategies;
```


### queuedActions
Mapping of actionId's and bool that indicates if action is queued.


```solidity
mapping(uint256 => bool) public queuedActions;
```


## Functions
### constructor


```solidity
constructor(
    string memory _name,
    string memory _symbol,
    Strategy[] memory initialStrategies,
    address[] memory initialPolicyholders,
    bytes8[][] memory initialPermissions
);
```

### onlyVertex


```solidity
modifier onlyVertex();
```

### createAction

Creates an action. The creator needs to hold a policy with the permissionSignature of the provided strategy, target, selector.


```solidity
function createAction(VertexStrategy strategy, address target, uint256 value, bytes4 selector, bytes calldata data) external override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`VertexStrategy`|The VertexStrategy contract that will determine how the action is executed.|
|`target`|`address`|The contract called when the action is executed.|
|`value`|`uint256`|The value in wei to be sent when the action is executed.|
|`selector`|`bytes4`|The function selector that will be called when the action is executed.|
|`data`|`bytes`|The encoded arguments to be passed to the function that is called when the action is executed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|actionId of the newly created action.|


### queueAction

Queue an action by actionId if it's in Approved state.


```solidity
function queueAction(uint256 actionId) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|Id of the action to queue.|


### executeAction

Execute an action by actionId if it's in Queued state and executionTime has passed.


```solidity
function executeAction(uint256 actionId) external payable override returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|Id of the action to execute.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The result returned from the call to the target contract.|


### cancelAction

Cancels an action. Can be called anytime by the creator or if action is disapproved.


```solidity
function cancelAction(uint256 actionId) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|Id of the action to cancel.|


### submitApproval

How policyholders add or remove their support of the approval of an action.


```solidity
function submitApproval(uint256 actionId, bool support) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|The id of the action.|
|`support`|`bool`|A boolean value that indicates whether the policyholder is adding or removing their support of the approval.|


### submitApprovalBySignature

How policyholders add or remove their support of the approval of an action via an offchain selector.


```solidity
function submitApprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|The id of the action.|
|`support`|`bool`|A boolean value that indicates whether the policyholder is adding or removing their support of the approval.|
|`v`|`uint8`|v part of the policyholder selector|
|`r`|`bytes32`|r part of the policyholder selector|
|`s`|`bytes32`|s part of the policyholder selector|


### submitDisapproval

How policyholders add or remove their support of the disapproval of an action.


```solidity
function submitDisapproval(uint256 actionId, bool support) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|The id of the action.|
|`support`|`bool`|A boolean value that indicates whether the policyholder is adding or removing their support of the disapproval.|


### submitDisapprovalBySignature

How policyholders add or remove their support of the disapproval of an action via an offchain selector.


```solidity
function submitDisapprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|The id of the action.|
|`support`|`bool`|A boolean value that indicates whether the policyholder is adding or removing their support of the disapproval.|
|`v`|`uint8`|v part of the policyholder selector|
|`r`|`bytes32`|r part of the policyholder selector|
|`s`|`bytes32`|s part of the policyholder selector|


### createAndAuthorizeStrategies

Deploy new strategies and add them to the mapping of authorized strategies.


```solidity
function createAndAuthorizeStrategies(Strategy[] memory strategies) public override onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategies`|`Strategy[]`|list of new Strategys to be authorized.|


### unauthorizeStrategies

Remove strategies from the mapping of authorized strategies.


```solidity
function unauthorizeStrategies(VertexStrategy[] memory strategies) public override onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategies`|`VertexStrategy[]`|list of Strategys to be removed from the mapping of authorized strategies.|


### isActionExpired

Get whether an action has expired and can no longer be executed.


```solidity
function isActionExpired(uint256 actionId) public view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|id of the action.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Boolean value that is true if the action has expired.|


### getAction

Get an Action struct by actionId.


```solidity
function getAction(uint256 actionId) external view override returns (Action memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|id of the action.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Action`|The Action struct.|


### getActionState

Get the current ActionState of an action by its actionId.


```solidity
function getActionState(uint256 actionId) public view override returns (ActionState);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|id of the action.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionState`|The current ActionState of the action.|


### _submitApproval


```solidity
function _submitApproval(address policyholder, uint256 actionId, bool support) internal;
```

### _submitDisapproval


```solidity
function _submitDisapproval(address policyholder, uint256 actionId, bool support) internal;
```

## Errors
### InvalidStrategy

```solidity
error InvalidStrategy();
```

### InvalidCancelation

```solidity
error InvalidCancelation();
```

### InvalidActionId

```solidity
error InvalidActionId();
```

### OnlyQueuedActions

```solidity
error OnlyQueuedActions();
```

### InvalidStateForQueue

```solidity
error InvalidStateForQueue();
```

### ActionCannotBeCanceled

```solidity
error ActionCannotBeCanceled();
```

### OnlyVertex

```solidity
error OnlyVertex();
```

### ActionNotActive

```solidity
error ActionNotActive();
```

### ActionNotQueued

```solidity
error ActionNotQueued();
```

### InvalidSignature

```solidity
error InvalidSignature();
```

### TimelockNotFinished

```solidity
error TimelockNotFinished();
```

### FailedActionExecution

```solidity
error FailedActionExecution();
```

### DuplicateApproval

```solidity
error DuplicateApproval();
```

### DuplicateDisapproval

```solidity
error DuplicateDisapproval();
```

### DisapproveDisabled

```solidity
error DisapproveDisabled();
```

### PolicyholderDoesNotHavePermission

```solidity
error PolicyholderDoesNotHavePermission();
```

