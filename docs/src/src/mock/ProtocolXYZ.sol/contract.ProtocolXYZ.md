# ProtocolXYZ

[Git Source](https://github.com/llama-community/vertex-v1/blob/28b1b0e095ba3c46d62387b2c29c8768bc213a6c/src/mock/ProtocolXYZ.sol)

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
