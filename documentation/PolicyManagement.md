# Policy Management

Policies are the building blocks of the Llama permissioning system. 
They allow users to create actions, assign roles, authorize strategies, and more. 
Without policies, a Llama instance will be unusable.
Policies, roles, and permissions can be granted on instance deployment, but we are going to focus on policy management for active Llama instances in this section.  

Let's dive into the best practices surrounding policy management.

## Key Concepts

- **Policies**: Non-transferable NFTs encoded with roles and permissions for an individual Llama instance.
- **Token Ids**: The `tokenId` of a Llama policy NFT is always equal to `uint256(uint160(policyHolderAddress))`
- **Roles**: A signifier given to one or more policyholders. Roles can be used to permission action approvals/disapprovals.
- **Permissions**: A unique identifier that can be assigned to roles to permission action creation. Permissions are represented as a hash of the target contract, function selector, and strategy contract. Actions cannot be created unless a policyholder holds a role with the correct permission.
- **Checkpoints**: Llama stores checkpointed policy data to storage over time so that we can search historical policy data .

## Managing Policies

Users can perform two actions to manage the policy supply: minting and burning policies. 
Since policies cannot be transferred, users can only hold a policy if it has been explicitly granted to them during deployment or through governance. 
Similarly, policyholders cannot burn their own policy; policies can only be revoked through governance.

### Granting Policies

Llama policies can be granted to EOAs as well as other smart contracts, allowing a great deal of flexibility.
To grant a policy to a new policyholder, a policyholder with the correct permission must create an action that calls the `setRoleHolder` method on the `LlamaPolicy contract.
When invoking the `setRoleHolder` the caller must pass in the following arguments: `(uint8 role, address policyholder, uint128 quantity, uint64 expiration)`.

Lets look at each argument individually:
- **role**: The role being granted to the policyholder
- **policyholder**: The policyholder's address
- **quantity**: The quantity of approval/disapproval power the policyholder has for the given role.
- **expiration**: The expiration date of the role (not the policy)

There are a few additional concepts to keep in mind to understand granting policies:
- The `setRoleHolder` function is used in multiple scenarios and is not exclusive to granting policies
- When `setRoleHolder` is called and `balanceOf(policyholder) == 0` a new policy nft is minted to the policyholder address.
- A role MUST be assigned when granting a policy (in addition to the `ALL_HOLDERS_ROLE`).
- Every policyholder is automatically assigned the `ALL_HOLDERS_ROLE` when their policy is minted.

### Revoking Policies

The `revokePolicy` method on the `LlamaPolicy` contract is used to revoke a policy.
This method burns the policy NFT and revokes all roles from the former policyholder.

## Managing Roles

Role management involves creating, editing, granting, and revoking roles from Llama policy NFTs.
Roles are of type `uint8`, meaning roles are denominated as unsigned integers and the maximum number of roles a Llama instance can have is 255.
Every Llama instance reserves the 0 role for the `ALL_HOLDERS_ROLE`, which is given to every policyholder at mint, and cannot be revoked until the policy is revoked.
Every role has two supplies that are checkpointed in storage: 
1. Number of holders: The number of unique policy NFTs that hold the given role
2. Total quantity: The sum of all the quantities that each role holding policy possesses. 

### Creating New Roles

When roles are created, a description is provided.
This description serves as the plaintext mapping from description => role id, and provides semantic meaning to an otherwise meaningless unsigned integer.
The `initializeRole` method on the `LlamaPolicy` contract is used to instantiate a new role, and it takes an argument called description that is a UDVT `RoleDescription` which under the hood is just a bytes32 value. 

### Editing Existing Roles

Once roles are created, they can't be deleted.
Since Llama instances only have space for 255 roles total, the need to repurpose old and unused roles may surface over time.
It is for this reason that the `updateRoleDescription` method exists.
`updateRoleDescription` takes two arguments: role and description.
Note that this method only changes the semantic meaning of a role, not the actual power that role holds within the Llama instance; be sure that the updated role has the correct permissions and approval/disapproval powers when updating a role.

### Granting Roles

To grant a role to a policyholder, we use the `setRoleHolder` method.
In order to grant a role, this method requires us to pass in a role that the policyholder does not hold, the policyholder's address, the quantity of this role they should hold, and expiration timestamp.
After granting the role, the total supply of the role will increment by one, and the total quantity of the role will increase by the quantity passed in.

### Revoking Roles

To revoke a role, we use the `setRoleHolder` method again.
Simply pass in the role, the policyholder to revoke it from, and set the quantity and expiration to 0.
Revoking a role will decrement the total supply of the role by one, and decrement the total quantity of the role by the quantity the policyholder previously held.

### Updating Role Quantity / Expiration

### Role Expiration

## Managing Permissions

### Granting Permissions

### Revoking Permissions

## Batching Policy Management Methods Using the Governance Script

## Checkpoints


