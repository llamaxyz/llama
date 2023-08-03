![Llama](.github/assets/llama-banner.png)

![CI](https://github.com/llamaxyz/llama/actions/workflows/ci.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# Llama

Llama is an onchain governance framework. It uses non-transferable NFTs to encode access control, features programmatic control of funds, and includes modular strategies to define action execution rules.

## Prerequisites

[Foundry](https://github.com/foundry-rs/foundry) must be installed.
You can find installation instructions in the [Foundry docs](https://book.getfoundry.sh/getting-started/installation).

We use [just](https://github.com/casey/just) to save and run a few larger, more complex commands.
You can find installation instructions in the [just docs](https://just.systems/man/en/).
All commands can be listed by running `just -l` from the repo root, or by viewing the [`justfile`](https://github.com/llamaxyz/llama/blob/main/justfile).

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

Copy `.env.example` and rename it to `.env`.
The comments in that file explain what each variable is for and when they're needed:

- The `MAINNET_RPC_URL` variable is the only one that is required for running tests.
- You may also want a mainnet `ETHERSCAN_API_KEY` for better traces when running fork tests.
- The rest are only needed for deployment verification with forge scripts. An anvil default private key is provided in the `.env.example` file to facilitate testing.

### Commands

- `forge build` - build the project
- `forge test` - run tests

### Deploy and Verify

- `just deploy` - deploy and verify payload on mainnet
- Run `just -l` or see the [`justfile`](https://github.com/llamaxyz/llama/blob/main/justfile) for other commands such as dry runs.

## Documentation

Run the following command to generate smart contract reference documentation from this project's NatSpec comments and serve those static files locally:

```sh
$ forge doc -o reference/ -b -s
```

## Slither

Use our bash script to prevent slither from analyzing the test and script directories. Running `slither .` directly will result in an `AssertionError`.

```sh
$ chmod +x slither.sh
$ ./slither.sh
```
