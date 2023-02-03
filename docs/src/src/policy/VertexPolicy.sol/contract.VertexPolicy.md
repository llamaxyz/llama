# VertexPolicy

[Git Source](https://github.com/llama-community/vertex-v1/blob/28b1b0e095ba3c46d62387b2c29c8768bc213a6c/src/policy/VertexPolicy.sol)

**Inherits:**
ERC721

## Functions

### batchUpdatePermissions

burns and then mints tokens with the same policy IDs to the same addressed with a new set of permissions for each

```solidity
function batchUpdatePermissions(uint256[] calldata policyIds, bytes8[][] calldata permissions) public virtual;
```

**Parameters**

| Name          | Type         | Description                         |
| ------------- | ------------ | ----------------------------------- |
| `policyIds`   | `uint256[]`  | the policy token id being altered   |
| `permissions` | `bytes8[][]` | the new permissions array to be set |

### batchGrantPermissions

mints multiple policy token with the given permissions

```solidity
function batchGrantPermissions(address[] calldata to, bytes8[][] memory userPermissions) public virtual;
```

**Parameters**

| Name              | Type         | Description                                       |
| ----------------- | ------------ | ------------------------------------------------- |
| `to`              | `address[]`  | the addresses to mint the policy token to         |
| `userPermissions` | `bytes8[][]` | the permissions to be granted to the policy token |

### batchRevokePermissions

revokes all permissions from multiple policy tokens

```solidity
function batchRevokePermissions(uint256[] calldata policyIds) public virtual;
```

**Parameters**

| Name        | Type        | Description                                             |
| ----------- | ----------- | ------------------------------------------------------- |
| `policyIds` | `uint256[]` | the ids of the policy tokens to revoke permissions from |

### holderHasPermissionAt

Check if a holder has a permissionSignature at a specific block number

```solidity
function holderHasPermissionAt(address policyholder, bytes8 permissionSignature, uint256 blockNumber) external view virtual returns (bool);
```

**Parameters**

| Name                  | Type      | Description                      |
| --------------------- | --------- | -------------------------------- |
| `policyholder`        | `address` | the address of the policy holder |
| `permissionSignature` | `bytes8`  | the signature of the permission  |
| `blockNumber`         | `uint256` | the block number to query        |

### setBaseURI

sets the base URI for the contract

```solidity
function setBaseURI(string calldata _baseURI) public virtual;
```

**Parameters**

| Name       | Type     | Description                |
| ---------- | -------- | -------------------------- |
| `_baseURI` | `string` | the base URI string to set |

### getSupplyByPermissions

Total number of policy NFTs at that have at least 1 of these permissions at specific block number

```solidity
function getSupplyByPermissions(bytes8[] calldata permissions) external view virtual returns (uint256);
```

**Parameters**

| Name          | Type       | Description                         |
| ------------- | ---------- | ----------------------------------- |
| `permissions` | `bytes8[]` | the permissions we are querying for |

### totalSupply

_returns the total token supply of the contract_

```solidity
function totalSupply() public view virtual returns (uint256);
```

### getPermissionSignatures

_returns the permission signatures of a token_

```solidity
function getPermissionSignatures(uint256 policyId) public view virtual returns (bytes8[] memory);
```

**Parameters**

| Name       | Type      | Description         |
| ---------- | --------- | ------------------- |
| `policyId` | `uint256` | the id of the token |

### hasPermission

_checks if a token has a permission_

```solidity
function hasPermission(uint256 policyId, bytes8 permissionSignature) public view virtual returns (bool);
```

**Parameters**

| Name                  | Type      | Description                     |
| --------------------- | --------- | ------------------------------- |
| `policyId`            | `uint256` | the id of the token             |
| `permissionSignature` | `bytes8`  | the signature of the permission |

## Events

### PermissionsAdded

```solidity
event PermissionsAdded(uint256[] users, Permission[] permissions, bytes8[] permissionSignatures);
```

### PermissionsDeleted

```solidity
event PermissionsDeleted(uint256[] users, bytes8[] permissionSignatures);
```

## Errors

### SoulboundToken

```solidity
error SoulboundToken();
```

### InvalidInput

```solidity
error InvalidInput();
```

### OnlyVertex

```solidity
error OnlyVertex();
```

### OnlyOnePolicyPerHolder

```solidity
error OnlyOnePolicyPerHolder();
```
