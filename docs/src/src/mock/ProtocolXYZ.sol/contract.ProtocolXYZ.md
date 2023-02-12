# ProtocolXYZ
[Git Source](https://github.com/llama-community/vertex-v1/blob/033c40b70aa1582a65b241654f3eda785898e17e/src/mock/ProtocolXYZ.sol)


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

