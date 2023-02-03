# IVertexFactory
[Git Source](https://github.com/llama-community/vertex-v1/blob/273c5d72ad31cc2754f7da37333566f14375808b/src/factory/IVertexFactory.sol)


## Functions
### deploy

Deploys a new Vertex system. This function can only be called by the initial Vertex system.


```solidity
function deploy(
    string memory name,
    string memory policySymbol,
    Strategy[] memory initialStrategies,
    address[] memory initialPolicyholders,
    bytes8[][] memory initialPermissions
) external returns (VertexCore);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The name of this Vertex system.|
|`policySymbol`|`string`|The token symbol for the policy NFT.|
|`initialStrategies`|`Strategy[]`|The list of initial strategies.|
|`initialPolicyholders`|`address[]`|The list of initial policyholders.|
|`initialPermissions`|`bytes8[][]`|The list of permissions granted to each initial policyholder.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`VertexCore`|the address of the VertexCore contract of the newly created system.|


## Events
### VertexCreated

```solidity
event VertexCreated(uint256 indexed id, string indexed name);
```

