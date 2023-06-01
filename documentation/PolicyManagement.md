# Policy Management

Policies are the core building block of the Llama permissioning system.
Without policies, there is no way to create actions, assign new roles, etc.
Essentially, without policies a Llama instance will be bricked.
This why policy management is so important, as new policyholders are granted policies and old policies are removed we must be able to assign and revoke policies, roles, and permissions accordingly.
Policies, roles, and permissions can be granted on instance deployment, but we are going to focus on policy management for active Llama instances in this section.  

Let's dive into the best practices surrounding policy management.

## Key Concepts

- **Policies**: Non-transferable NFTs encoded with roles and permissions for an individual Llama instance.
- **Roles**: A signifier given to one or more policyholders. Roles can be used to permission action approvals/disapprovals.
- **Permissions**: A unique identifier that can be assigned to roles to permission action creation. Permissions are represented as a hash of the target contract, function selector, and strategy contract. Actions cannot be created unless a policyholder holds a role with the correct permission.
- **Checkpoints**: Llama stores checkpointed policy data to storage over time so that we can search historical policy data .

## Managing Policies

Narrowing in on the Llama policy NFT itself, there are two actions we can take to manage the policy supply: minting and burning policies.
Since policies are non-transferable, there is no way someone can hold a policy unless one has been explicitly granted to them at deployment or through governance.
Conversely, there is no way for someone to burn their own policy, they may only be revoked through governance.

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

## Managing Roles

### Granting Roles

### Revoking Roles

### Role Expiration

## Managing Permissions

### Granting Permissions

### Revoking Permissions

## Checkpoints


