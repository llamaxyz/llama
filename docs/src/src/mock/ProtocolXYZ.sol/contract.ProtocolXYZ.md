# ProtocolXYZ
[Git Source](https://github.com/llama-community/vertex-v1/blob/7b69542e87e2655dea74dab5779f3939de9641f7/src/mock/ProtocolXYZ.sol)



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

