# Instance Deployment

To start using Llama to manage on-chain privileged access functions, you must first deploy your own instance.
To deploy we can call the `deploy` method on [the Llama Factory contract](../src/LlamaFactory.sol).
Deploying Llama instances requires a non-trivial amount of configuration and set up, since we have to initialize the system with the base set of permissions and rules describing who can do what.
A list of all official deployed Llama Factory contracts can be found [here](../README.md#Deployments)

## Configuration

In this section we will dive into configuring your Llama instance

The deploy method accepts a configuration struct called `LlamaInstanceConfig`.
Lets look into this struct to see what data it holds.

```solidity
struct LlamaInstanceConfig {
  string name;
  ILlamaStrategy strategyLogic;
  ILlamaAccount accountLogic;
  bytes[] initialStrategies; // Array of initial strategy configurations.
  bytes[] initialAccounts; // Array of initial account configurations.
  LlamaPolicyConfig policyConfig; // Configuration of the instance's policy.
}
```

Lets look at each field one by one:

- Name: The name of the Llama instance.
- Strategy Logic: The initial strategy implementation (logic) contract. See [here]((../README.md#Deployments)) for a list of deployed strategy logic contracts, and [here](./strategy-comparison.md) learn about their differences.
- Account Logic: The initial account implementation (logic) contract. You can find the account logic contract [here]((../README.md#Deployments)), there is currently only one account implementation contract but there may be more in the future.
