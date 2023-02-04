# ProtocolXYZ
<<<<<<< HEAD
<<<<<<< HEAD
[Git Source](https://github.com/llama-community/vertex-v1/blob/61ef774889dd82e8f91f589d8c7893861f840536/src/mock/ProtocolXYZ.sol)
=======
[Git Source](https://github.com/llama-community/vertex-v1/blob/273c5d72ad31cc2754f7da37333566f14375808b/src/mock/ProtocolXYZ.sol)
>>>>>>> a2cac96 (Generate updated docs)
=======
[Git Source](https://github.com/llama-community/vertex-v1/blob/273c5d72ad31cc2754f7da37333566f14375808b/src/mock/ProtocolXYZ.sol)
>>>>>>> b75ab96f95c20c97992964be967cc575cc176f07


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

