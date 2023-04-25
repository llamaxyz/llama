# Llama

Llama is a governance system for onchain organizations. It uses non-transferable NFTs to encode access control, features programmatic fund management, and includes a modular framework to define action execution rules.

## Prerequisites

It requires [Foundry](https://github.com/foundry-rs/foundry) installed to run. You can find instructions here: [Foundry installation](https://book.getfoundry.sh/getting-started/installation).

We use [just](https://github.com/casey/just) to save and run commands. You can find instructions here: [just installation](https://github.com/casey/just#packages).

### VS Code

You can get Solidity support for Visual Studio Code by installing the [Hardhat Solidity extension](https://github.com/NomicFoundation/hardhat-vscode).

## Installation

```sh
$ git clone https://github.com/llamaxyz/llama.git
$ cd llama
$ forge install

# Configure git to ignore commits that aren't relevant to git blame. Read the
# comments in the `.git-blame-ignore-revs` file for more information.
$ git config blame.ignoreRevsFile .git-blame-ignore-revs
```

## Setup

Duplicate `.env.example` and rename to `.env`:

- Add a valid mainnet URL for an Ethereum JSON-RPC client for the `MAINNET_RPC_URL` variable.
- Add a valid Private Key for the `PRIVATE_KEY` variable.
- Add a valid Etherscan API Key for the `ETHERSCAN_API_KEY` variable.

### Commands

- `forge build` - build the project
- `forge test` - run tests

### Deploy and Verify

- `just deploy` - deploy and verify payload on mainnet

To confirm the deploy was successful, re-run your test suite but use the newly created contract address.

## Documentation

The generate documentation for the project and serve those static files locally, run the following commands:

```sh
$ forge doc -b
$ forge doc -s
```
