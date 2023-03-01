# Vertex v1

Vertex v1 is a smart contract access control and administration framework.

## Prerequisites

It requires [Foundry](https://github.com/gakonst/foundry) installed to run. You can find instructions here [Foundry installation](https://github.com/gakonst/foundry#installation).

### VS Code

You can get Solidity support for Visual Studio Code by installing the [VSCode Solidity extension](https://github.com/juanfranblanco/vscode-solidity).

## Installation

```sh
$ git clone https://github.com/llama-community/vertex-v1.git
$ cd vertex-v1
$ forge install
```

## Setup

Duplicate `.env.example` and rename to `.env`:

- Add a valid mainnet URL for an Ethereum JSON-RPC client for the `MAINNET_RPC_URL` variable.
- Add a valid Private Key for the `PRIVATE_KEY` variable.
- Add a valid Etherscan API Key for the `ETHERSCAN_API_KEY` variable.

### Commands

- `forge build` - build the project
- `forge test`  - run tests

### Deploy and Verify

- `just deploy` - deploy and verify payload on mainnet

To confirm the deploy was successful, re-run your test suite but use the newly created contract address.

## Documentation

The generate documentation for the project and serve those static files locally, run the following commands:

```sh
$ forge doc -b
$ forge doc -s
```
