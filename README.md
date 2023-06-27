![Llama](.github/assets/llama-banner.png)

![CI](https://github.com/llamaxyz/llama/actions/workflows/ci.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# Llama

Llama is a governance system for onchain organizations.
It uses non-transferable NFTs to encode access control, features programmatic control of funds, and includes a modular framework to define action execution rules.

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

## Deployments

| Name                             | Address                                                                                                                      | Verified |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------- |
| LlamaCoreLogic                   | [0x611e8bE39A7EDAd60fdEE5aDce3715674d9B807d](https://goerli.etherscan.io/address/0x611e8bE39A7EDAd60fdEE5aDce3715674d9B807d) |    ✅    |
| LlamaRelativeStrategyLogic       | [0xaB957338f5488EeF3A2F61Af4A5bC7F44b603E92](https://goerli.etherscan.io/address/0xaB957338f5488EeF3A2F61Af4A5bC7F44b603E92) |    ✅    |
| LlamaAbsoluteStrategyLogic       | [0xd5d8555bc5c038e09a9c8dF683C6BDC839C326Aa](https://goerli.etherscan.io/address/0xd5d8555bc5c038e09a9c8dF683C6BDC839C326Aa) |    ✅    |
| LlamaAccountLogic                | [0x89eF1E0dA1628Eb070937ef0EBBa01B5b291a33f](https://goerli.etherscan.io/address/0x89eF1E0dA1628Eb070937ef0EBBa01B5b291a33f) |    ✅    |
| LlamaPolicyLogic                 | [0x7F2B017FDA4A6C601Cc681367b25E886C504Af8a](https://goerli.etherscan.io/address/0x7F2B017FDA4A6C601Cc681367b25E886C504Af8a) |    ✅    |
| LlamaPolicyMetadata              | [0x1cBC643b86E83f9DE30Ac501Cc4952FAFBa3Ad3a](https://goerli.etherscan.io/address/0x1cBC643b86E83f9DE30Ac501Cc4952FAFBa3Ad3a) |    ✅    |
| LlamaFactory                     | [0xaC7c9eaf194d43d0f62E68472295eCbc403F13d0](https://goerli.etherscan.io/address/0xaC7c9eaf194d43d0f62E68472295eCbc403F13d0) |    ❌    |
| LlamaPolicyMetadataParamRegistry | [0x4524909FBA0E10C878b15CbFCb0f60BB02afB348](https://goerli.etherscan.io/address/0x4524909FBA0E10C878b15CbFCb0f60BB02afB348) |    ❌    |
| LlamaLens                        | [0x31165228dEe0F9c8C48c70d840FC5Ef6d5977920](https://goerli.etherscan.io/address/0x31165228dEe0F9c8C48c70d840FC5Ef6d5977920) |    ❌    |
| Root's Llama Policy              | [0xf2157E064bca23Cab5322DE675366975acC36F05](https://goerli.etherscan.io/address/0xf2157E064bca23Cab5322DE675366975acC36F05) |    ✅    |
| Root's LlamaCore                 | [0x4011EE728494Abe7BB5C20292BDc31420FF167d2](https://goerli.etherscan.io/address/0x4011EE728494Abe7BB5C20292BDc31420FF167d2) |    ✅    |
| Root's LlamaExecutor             | [0x7489a99EC16f6F9010481F171e9131eA89c97A9F](https://goerli.etherscan.io/address/0x7489a99EC16f6F9010481F171e9131eA89c97A9F) |    ❌    |
| Root's Strategy #1               | [0xDcD89690eD40Def836C6D264bAfC7B34A0C1e4f9](https://goerli.etherscan.io/address/0xDcD89690eD40Def836C6D264bAfC7B34A0C1e4f9) |    ✅    |
| Root's Llama Treasury Account    | [0x7a7BC7DEaB9e885DDF81929eB7F0D33798D2600D](https://goerli.etherscan.io/address/0x7a7BC7DEaB9e885DDF81929eB7F0D33798D2600D) |    ✅    |
| Root's Llama Grants Account      | [0xF76Ae203B988c5F12238c55E0d73047862DA4Ef6](https://goerli.etherscan.io/address/0xF76Ae203B988c5F12238c55E0d73047862DA4Ef6) |    ✅    |

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
