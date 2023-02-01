# ProtocolXYZ

[Git Source](https://github.com/llama-community/vertex-v1/blob/693b03f6823cb240f992102042b3702c0c97cf44/src/mock/ProtocolXYZ.sol)

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
