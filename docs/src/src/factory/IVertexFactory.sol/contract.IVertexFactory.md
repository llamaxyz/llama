# IVertexFactory
[Git Source](https://github.com/llama-community/vertex-v1/blob/27980926cf0c0e8a1878ad1969b27067a6a9bef5/src/factory/IVertexFactory.sol)


## Functions
### deploy

Deploys a new Vertex system. This function can only be called by the initial Vertex system.


```solidity
function deploy(
    string memory name,
    string memory policySymbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    address[] memory initialPolicyholders,
    bytes8[][] memory initialPermissions,
    uint256[][] memory initialExpirationTimestamps
) external returns (VertexCore);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The name of this Vertex system.|
|`policySymbol`|`string`|The token symbol for the policy NFT.|
|`initialStrategies`|`Strategy[]`|The list of initial strategies.|
|`initialAccounts`|`string[]`|The list of initial accounts.|
|`initialPolicyholders`|`address[]`|The list of initial policyholders.|
|`initialPermissions`|`bytes8[][]`|The list of permissions granted to each initial policyholder.|
|`initialExpirationTimestamps`|`uint256[][]`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`VertexCore`|the address of the VertexCore contract of the newly created system.|


## Events
### VertexCreated

```solidity
event VertexCreated(uint256 indexed id, string indexed name, address vertexCore);
```

