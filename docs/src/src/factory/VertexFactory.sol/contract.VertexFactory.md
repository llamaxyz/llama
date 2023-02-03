# VertexFactory
[Git Source](https://github.com/llama-community/vertex-v1/blob/273c5d72ad31cc2754f7da37333566f14375808b/src/factory/VertexFactory.sol)

**Inherits:**
Ownable, [IVertexFactory](/src/factory/IVertexFactory.sol/contract.IVertexFactory.md)

**Author:**
Llama (vertex@llama.xyz)

Factory for deploying new Vertex systems.


## State Variables
### vertexCount
The current number of vertex systems created.


```solidity
uint256 public vertexCount;
```


### vertexCore
The vertex core implementation address.


```solidity
VertexCore public immutable vertexCore;
```


## Functions
### constructor


```solidity
constructor(
    VertexCore _vertexCore,
    string memory name,
    string memory policySymbol,
    Strategy[] memory initialStrategies,
    address[] memory initialPolicyholders,
    bytes8[][] memory initialPermissions
);
```

### deploy


```solidity
function deploy(
    string memory name,
    string memory policySymbol,
    Strategy[] memory initialStrategies,
    address[] memory initialPolicyholders,
    bytes8[][] memory initialPermissions
) public onlyOwner returns (VertexCore vertex);
```

