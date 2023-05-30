# Action Creation

After your Llama instance is deployed, it's time to start creating actions. Actions are onchain transactions that consist of the following elements:

    Action Elements:
    - Target Contract (the contract to be called by the Llama executor)
    - Strategy (the Llama strategy that determines the action state)
    - Calldata (function selector and parameters)
    - Role (role used to create the action)
    - Value (amount of ether sent with the call)
    - Description (plaintext explaining the purpose of the action)

~permissioned through Llama policies; policyholders with the corresponding permissions are able to create actions.