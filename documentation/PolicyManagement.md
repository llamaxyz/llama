# Policy Management

Policies are the core building block of the Llama permissioning system.
Without policies, there is no way to create actions or your Llama instance will be bricked.
This why policy management is so important, as new policyholders come into your system and old policies are removed we must be able to assign and revoke policies, roles, and permissions accordingly.
Let's dive into the best practices surrounding policy management.

## Key Concepts

- **Policies**: Non-transferable NFTs encoded with roles and permissions for an individual Llama instance.
- **Roles**: A signifier given to one or more policyholders. Roles can be used to permission action approvals/disapprovals.
- **Permissions**: A unique identifier that can be assigned to roles to permission action creation. Permissions are represented as a hash of the target contract, function selector, and strategy contract. Actions cannot be created unless a policyholder holds a role with the correct permission.

## Managing Policies

### Granting Policies

### Revoking Policies

## Managing Roles

### Granting Roles

### Revoking Roles

### Role Expiration

## Managing Permissions

### Granting Permissions

### Revoking Permissions


