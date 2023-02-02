# ProtocolXYZ
[Git Source](https://github.com/llama-community/vertex-v1/blob/bebc34645ed954bf693ee3ddf5ddd21359ce35fc/src/mock/ProtocolXYZ.sol)


## State Variables
### vertex

```solidity
address public immutable vertex;
```


### paused

```solidity
bool public paused;
```


## Functions
### constructor


```solidity
constructor(address _vertex);
```

### onlyVertex


```solidity
modifier onlyVertex();
```

### pause


```solidity
function pause(bool isPaused) external onlyVertex;
```

### fail


```solidity
function fail() external view onlyVertex;
```

## Errors
### OnlyVertex

```solidity
error OnlyVertex();
```

### Failed

```solidity
error Failed();
```

