# VertexFactory
[Git Source](https://github.com/llama-community/vertex-v1/blob/416df8aad48508d953bede09eabbf60be08e551c/src/factory/VertexFactory.sol)

**Inherits:**
[IVertexFactory](/src/factory/IVertexFactory.sol/contract.IVertexFactory.md)

**Author:**
Llama (vertex@llama.xyz)

Factory for deploying new Vertex systems.


## State Variables
### vertexCore
The VertexCore implementation contract.


```solidity
VertexCore public immutable vertexCore;
```


### initialVertex
The initially deployed Vertex system.


```solidity
VertexCore public immutable initialVertex;
```


### vertexCount
The current number of vertex systems created.


```solidity
uint256 public vertexCount;
```


## Functions
### constructor


```solidity
constructor(
    VertexCore _vertexCore,
    string memory name,
    string memory symbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    address[] memory initialPolicyholders,
    bytes8[][] memory initialPermissions
);
```

### onlyInitialVertex


```solidity
modifier onlyInitialVertex();
```

### deploy


```solidity
function deploy(
    string memory name,
    string memory symbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    address[] memory initialPolicyholders,
    bytes8[][] memory initialPermissions
) public onlyInitialVertex returns (VertexCore);
```

## Errors
### OnlyVertex

```solidity
error OnlyVertex();
```

