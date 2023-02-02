# VertexPolicyNFT
[Git Source](https://github.com/llama-community/vertex-v1/blob/6785e46eecfd015916d80a3d297105345cc00c68/src/policy/VertexPolicyNFT.sol)

**Inherits:**
[VertexPolicy](/src/policy/VertexPolicy.sol/contract.VertexPolicy.md)

**Author:**
Llama (vertex@llama.xyz)

The permissions determine how the token can interact with the vertex administrator contract

*VertexPolicyNFT is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions*


## State Variables
### tokenToPermissionSignatures

```solidity
mapping(uint256 => bytes8[]) public tokenToPermissionSignatures;
```


### tokenToHasPermissionSignature

```solidity
mapping(uint256 => mapping(bytes8 => bool)) public tokenToHasPermissionSignature;
```


### checkpoints

```solidity
mapping(uint256 => Checkpoint[]) private checkpoints;
```


### policyIds

```solidity
uint256[] public policyIds;
```


### baseURI

```solidity
string public baseURI;
```


### _totalSupply

```solidity
uint256 private _totalSupply;
```


### vertex

```solidity
address public immutable vertex;
```


## Functions
### onlyVertex


```solidity
modifier onlyVertex();
```

### constructor


```solidity
constructor(string memory name, string memory symbol, address _vertex, address[] memory initialPolicyholders, bytes8[][] memory initialPermissions)
    ERC721(name, symbol);
```

### holderHasPermissionAt

Check if a holder has a permissionSignature at a specific block number


```solidity
function holderHasPermissionAt(address policyholder, bytes8 permissionSignature, uint256 blockNumber) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`policyholder`|`address`|the address of the policy holder|
|`permissionSignature`|`bytes8`|the signature of the permission|
|`blockNumber`|`uint256`|the block number to query|


### getSupplyByPermissions

Total number of policy NFTs at that have at least 1 of these permissions at specific block number


```solidity
function getSupplyByPermissions(bytes8[] calldata _permissions) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_permissions`|`bytes8[]`||


### batchGrantPermissions

mints multiple policy token with the given permissions


```solidity
function batchGrantPermissions(address[] calldata to, bytes8[][] memory userPermissions) public override onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address[]`|the addresses to mint the policy token to|
|`userPermissions`|`bytes8[][]`|the permissions to be granted to the policy token|


### batchUpdatePermissions

burns and then mints tokens with the same policy IDs to the same addressed with a new set of permissions for each


```solidity
function batchUpdatePermissions(uint256[] calldata _policyIds, bytes8[][] calldata permissions) public override onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_policyIds`|`uint256[]`||
|`permissions`|`bytes8[][]`|the new permissions array to be set|


### batchRevokePermissions

revokes all permissions from multiple policy tokens


```solidity
function batchRevokePermissions(uint256[] calldata _policyIds) public override onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_policyIds`|`uint256[]`||


### hashPermission

*hashes a permission*


```solidity
function hashPermission(Permission calldata permission) public pure returns (bytes8);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permission`|`Permission`|the permission to hash|


### hashPermissions

*hashes an array of permissions*


```solidity
function hashPermissions(Permission[] calldata _permissions) public pure returns (bytes8[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_permissions`|`Permission[]`|the permissions array to hash|


### hasPermission

*checks if a token has a permission*


```solidity
function hasPermission(uint256 policyId, bytes8 permissionSignature) public view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`policyId`|`uint256`|the id of the token|
|`permissionSignature`|`bytes8`|the signature of the permission|


### grantPermissions

mints a new policy token with the given permissions


```solidity
function grantPermissions(address to, bytes8[] memory permissionSignatures) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|the address to mint the policy token to|
|`permissionSignatures`|`bytes8[]`|the permission signature's to be granted to the policyholder|


### revokePermissions

revokes all permissions from a policy token


```solidity
function revokePermissions(uint256 policyId) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`policyId`|`uint256`|the id of the policy token to revoke permissions from|


### updatePermissions

burns and then mints a token with the same policy ID to the same address with a new set of permissions


```solidity
function updatePermissions(uint256 policyId, bytes8[] calldata permissions) private onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`policyId`|`uint256`|the policy token id being updated|
|`permissions`|`bytes8[]`|the new permissions array to be set|


### setBaseURI

sets the base URI for the contract


```solidity
function setBaseURI(string calldata _baseURI) public override onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_baseURI`|`string`|the base URI string to set|


### transferFrom

*overriding transferFrom to disable transfers for SBTs*

*this is a temporary solution, we will need to conform to a Souldbound standard*


```solidity
function transferFrom(address from, address to, uint256 policyId) public override;
```

### getPermissionSignatures

*returns the permission signatures of a token*


```solidity
function getPermissionSignatures(uint256 userId) public view override returns (bytes8[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userId`|`uint256`||


### permissionIsInPermissionsArray


```solidity
function permissionIsInPermissionsArray(bytes8[] storage policyPermissionSignatures, bytes8 permissionSignature) internal view returns (bool);
```

### totalSupply

*returns the total token supply of the contract*


```solidity
function totalSupply() public view override returns (uint256);
```

### tokenURI

returns the location of the policy metadata


```solidity
function tokenURI(uint256 id) public view override returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|the id of the policy token|


