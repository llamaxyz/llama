# VertexCollector
[Git Source](https://github.com/llama-community/vertex-v1/blob/8146b0e9a9ffa7cd971f2eedb0f6b4018cc535f8/src/collector/VertexCollector.sol)

**Inherits:**
[IVertexCollector](/src/collector/IVertexCollector.sol/contract.IVertexCollector.md)

**Author:**
Llama (vertex@llama.xyz)

The contract that holds the Vertex system's assets.


## State Variables
### ETH_MOCK_ADDRESS
Mock address for ETH


```solidity
address public constant ETH_MOCK_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
```


### name
Name of this Vertex Collector.


```solidity
string public name;
```


### vertex
Vertex system


```solidity
address public immutable vertex;
```


## Functions
### constructor


```solidity
constructor(string memory _name, address _vertex);
```

### onlyVertex


```solidity
modifier onlyVertex();
```

### receive

Function for Vertex Collector to receive ETH


```solidity
receive() external payable;
```

### approve

Function for Vertex to give ERC20 allowance to other parties


```solidity
function approve(IERC20 token, address recipient, uint256 amount) external onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the token to give allowance from|
|`recipient`|`address`|Allowance's recipient|
|`amount`|`uint256`|Allowance to approve|


### transfer

Function for Vertex to transfer ERC20 tokens to other parties


```solidity
function transfer(IERC20 token, address recipient, uint256 amount) external onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the token to transfer|
|`recipient`|`address`|Transfer's recipient|
|`amount`|`uint256`|Amount to transfer|


## Errors
### OnlyVertex

```solidity
error OnlyVertex();
```

### Invalid0xRecipient

```solidity
error Invalid0xRecipient();
```

