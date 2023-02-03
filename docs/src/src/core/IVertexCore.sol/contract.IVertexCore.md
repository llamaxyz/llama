# IVertexCore
[Git Source](https://github.com/llama-community/vertex-v1/blob/5b218a8dd0bc635c09c9b3b94d2fdd2e8abeb7c2/src/core/IVertexCore.sol)


## Functions
### createAction

Creates an action. The creator needs to hold a policy with the permissionSignature of the provided strategy, target, selector.


```solidity
function createAction(VertexStrategy strategy, address target, uint256 value, bytes4 selector, bytes calldata data) external returns (uint256);
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


### cancelAction

Cancels an action. Can be called anytime by the creator or if action is disapproved.


```solidity
function cancelAction(uint256 actionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|Id of the action to cancel.|


### queueAction

Queue an action by actionId if it's in Approved state.


```solidity
function queueAction(uint256 actionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|Id of the action to queue.|


### executeAction

Execute an action by actionId if it's in Queued state and executionTime has passed.


```solidity
function executeAction(uint256 actionId) external payable returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|Id of the action to execute.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The result returned from the call to the target contract.|


### submitApproval

How policyholders add or remove their support of the approval of an action.


```solidity
function submitApproval(uint256 actionId, bool support) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|The id of the action.|
|`support`|`bool`|A boolean value that indicates whether the policyholder is adding or removing their support of the approval.|


### submitApprovalBySignature

How policyholders add or remove their support of the approval of an action via an offchain selector.


```solidity
function submitApprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external;
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
function submitDisapproval(uint256 actionId, bool support) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|The id of the action.|
|`support`|`bool`|A boolean value that indicates whether the policyholder is adding or removing their support of the disapproval.|


### submitDisapprovalBySignature

How policyholders add or remove their support of the disapproval of an action via an offchain selector.


```solidity
function submitDisapprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external;
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
function createAndAuthorizeStrategies(Strategy[] memory strategies) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategies`|`Strategy[]`|list of new Strategys to be authorized.|


### unauthorizeStrategies

Remove strategies from the mapping of authorized strategies.


```solidity
function unauthorizeStrategies(VertexStrategy[] memory strategies) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategies`|`VertexStrategy[]`|list of Strategys to be removed from the mapping of authorized strategies.|


### createAndAuthorizeCollectors

Deploy new collectors and add them to the mapping of authorized collectors.


```solidity
function createAndAuthorizeCollectors(string[] memory collectors) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collectors`|`string[]`|list of new collectors to be authorized.|


### getAction

Get an Action struct by actionId.


```solidity
function getAction(uint256 actionId) external view returns (Action memory);
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
function getActionState(uint256 actionId) external view returns (ActionState);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|id of the action.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionState`|The current ActionState of the action.|


### isActionExpired

Get whether an action has expired and can no longer be executed.


```solidity
function isActionExpired(uint256 actionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|id of the action.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Boolean value that is true if the action has expired.|


## Events
### ActionCreated

```solidity
event ActionCreated(uint256 id, address indexed creator, VertexStrategy indexed strategy, address target, uint256 value, bytes4 selector, bytes data);
```

### ActionCanceled

```solidity
event ActionCanceled(uint256 id);
```

### ActionQueued

```solidity
event ActionQueued(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime);
```

### ActionExecuted

```solidity
event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);
```

### PolicyholderApproved

```solidity
event PolicyholderApproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
```

### PolicyholderDisapproved

```solidity
event PolicyholderDisapproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
```

### StrategiesAuthorized

```solidity
event StrategiesAuthorized(Strategy[] strategies);
```

### StrategiesUnauthorized

```solidity
event StrategiesUnauthorized(VertexStrategy[] strategies);
```

### CollectorAuthorized

```solidity
event CollectorAuthorized(VertexCollector indexed collector, string name);
```

## Enums
### ActionState

```solidity
enum ActionState {
    Active,
    Canceled,
    Failed,
    Approved,
    Queued,
    Expired,
    Executed
}
```

