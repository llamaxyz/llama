# Policy Management

Policies are the building blocks of the Llama permissioning system.
They allow users to create actions, assign roles, authorize strategies, and more.
Without policies, a Llama instance will be unusable.
Policies, roles, and permission IDs can be granted on instance deployment, but this section focuses on policy management for active Llama instances in this section.

## Key Concepts

- **Policies**: Non-transferable NFTs encoded with roles and permission IDs for an individual Llama instance.
- **Token IDs**: The `tokenId` of a Llama policy NFT is always equal to `uint256(uint160(policyholderAddress))`.
- **Roles**: A signifier given to one or more policyholders. Roles can be used to permission action creation, action approvals, and action disapprovals.
- **Permission IDs**: A unique identifier that can be assigned to roles to permission action creation. Permission IDs are represented as a hash of the target contract, function selector, and strategy contract. Actions cannot be created unless a policyholder holds a role with the correct permission ID.
- **Checkpoints**: Llama stores checkpointed role balances over time to enable querying historical role quantities during the action approval and disapproval process.

## Managing Policies

Users can perform two actions to manage the policy supply: minting and burning policies.
Since policies cannot be transferred, users can only hold a policy if it has been explicitly granted to them during deployment or through governance.
Similarly, policyholders cannot burn their own policy; policies can only be revoked through governance.

### Granting Policies

Llama policies can be granted to EOAs as well as other smart contracts, allowing a great deal of flexibility.
To grant a new policy, an existing policyholder must create an action that calls the `setRoleHolder` method on the `LlamaPolicy` contract.
When invoking the `setRoleHolder` the caller must pass in the following arguments: `(uint8 role, address policyholder, uint128 quantity, uint64 expiration)`.

`setRoleHolder` takes four arguments:

- **role**: The role being granted to the policyholder.
- **policyholder**: The policyholder's address.
- **quantity**: The quantity of approval/disapproval power the policyholder has for the given role.
- **expiration**: The expiration date of the role (not the policy).

`setRoleHolder` also has the following properties:

- The `setRoleHolder` function is used in multiple scenarios and is not exclusive to granting policies.
- When `setRoleHolder` is called and `balanceOf(policyholder) == 0`, a new policy NFT is minted to the policyholder address.
- Every policyholder is automatically assigned the `ALL_HOLDERS_ROLE` when their policy is minted.

### Revoking Policies

The `revokePolicy` method on the `LlamaPolicy` contract is used to revoke a policy.
This method burns the policy NFT and revokes all roles from the former policyholder.

## Managing Roles

Role management involves creating, editing, granting, and revoking roles from Llama policy NFTs.
Roles are of type `uint8`, meaning roles are denominated as unsigned integers and the maximum number of roles a Llama instance can have is 255.
Every Llama instance reserves the 0 role for the `ALL_HOLDERS_ROLE`, which is given to every policyholder at mint, and cannot be revoked until the policy is revoked.
Every role has two supplies that are stored in the `RoleSupply` struct and are always available in storage:

1. Number of holders: The number of unique policy NFTs that hold the given role.
2. Total quantity: The sum of all the quantities that each role holding the policy possesses.

### Creating New Roles

When roles are created, a description is provided.
This description serves as the plaintext mapping from description to role ID, and provides semantic meaning to an otherwise meaningless unsigned integer.
The `initializeRole` method on the `LlamaPolicy` contract is used to instantiate a new role, and it takes an argument called description that is a UDVT `RoleDescription` which under the hood is just a `bytes32` value.

### Editing Existing Roles

Once roles are created, they can't be deleted.
Since Llama instances only have space for 255 roles total, the need to repurpose old and unused roles may surface over time.
It is for this reason that the `updateRoleDescription` method exists.
`updateRoleDescription` takes two arguments: role and description.
Note that this method only changes the semantic meaning of a role, not the actual power that role holds within the Llama instance; be sure that the updated role has the correct permission IDs and approval/disapproval powers when updating a role.

### Granting Roles

To grant a role to a policyholder, we use the `setRoleHolder` method.
In order to grant a role, this method requires us to pass in a role that the policyholder does not hold, the policyholder's address, the quantity of this role they should hold, and expiration timestamp.
After granting the role, the total supply of the role will increment by one, and the total quantity of the role will increase by the quantity passed in.
To grant a policy with the `ALL_HOLDERS_ROLE` and no other role, call `setRoleHolder` and pass an arbitrary role ID with a quantity and expiration of 0.

### Revoking Roles

To revoke a role, we use the `setRoleHolder` method again.
Simply pass in the role, the policyholder to revoke it from, and set the quantity and expiration to 0.
Revoking a role will decrement the total supply of the role by one, and decrement the total quantity of the role by the quantity the policyholder previously held.

### Updating Role Quantity / Expiration

Using the `setRoleHolder` method, the quantity or expiry of a role can be updated.
To update a role, pass in a role and a policyholder who currently has a non-zero quantity.
The quantity and expiration can be set to higher or lower values depending on the situation; if altering the quantity of a role, the total quantity will increment or decrement accordingly, but the total supply of the role will not change.

### Role Expiration

If a role has expired, it can be revoked by anyone using the `revokeExpiredRole` function.
The `revokeExpiredRole` does not have the `onlyLlama` modifier, and does not need to go through the normal action creation process as a result.
When an expired role is revoked, the quantity and total supply will be decremented accordingly.

**Note**: A policyholder can still utilize a role to approve/disapprove, and create actions after the expiry timestamp if it has not been revoked.
Once revoked, the role can no longer be used by the policyholder.

## Managing Permission IDs

Permission IDs are units of access control that can be assigned to roles to allow for action creation.
Policyholders are not allowed to create actions unless they have the corresponding permission.

## Permission IDs

Permission IDs are calculated by hashing the `PermissionData` struct, which is composed of three fields: the `target`, `selector` & `strategy`.
The `LlamaLens` contract provides an external view method called `computePermissionId` that allows users to compute permission IDs.
This is helpful because all of the functions required to manage permission IDs expect users to pass in pre-computed permission IDs.

### Granting Permission IDs

To grant a permission, the `setRolePermission` function is used.
This function accepts three parameters: The role being granted a permission, the permission id being granted, and a boolean `hasPermission`.
When granting permission IDs, `hasPermission` will always be set to true.

### Revoking Permission IDs

To revoke a permission, the `setRolePermission` function is used.
This function accepts three parameters: The role being revoked from, the permission id being revoked, and a boolean `hasPermission`.
When revoking permission IDs, `hasPermission` will always be set to false.

## Batching Policy Management Methods Using the Governance Script

All of the base methods to manage Llama policies are singular, meaning new actions must be created for every singular policy, role, and permission users might want to adjust.
Batching these methods together is an expected usecase, for example granting policies to a group of new users, or removing all permission IDs related to a specific strategy that is being deprecated.
This is the problem that the `GovernanceScript` aims to solve, by providing an interface that allows users to batch common policy management calls together to provide a substantially better UX.
The `GovernanceScript` must be permissioned separately from the base policy management functions, as it has an inherently different target address, and various function selectors that can be individually permissioned.

### Aggregate Method

Mirrors of the base policy management functions exist as batch methods on the `GovernanceScript` contract, and even some common combinations of these methods.
Not all possible combinations can be predicted and therefore do not exist on the script's interface.
This is where the `aggregate` method becomes useful.
`aggregate` allows users to propose any arbitrary calls to the `LlamaCore` and `LlamaPolicy` contracts.
Since `aggregate` is a very powerful method, we recommend permissioning other methods on the `GovernanceScript` contract unless the use of `aggregate` is deemed necessary, and even then, an `ActionGuard` is recommended.
