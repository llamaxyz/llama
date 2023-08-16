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

## Deployments

| Name                                  | Goerli Address                                                                                                               | Sepolia Address                                                                                                               | 
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------  | 
|_Factory_|
| LlamaFactory                          | [0x9f79a7d30e9ed7fc35bd23f389766c18d6f54ea6](https://goerli.etherscan.io/address/0x9f79a7d30e9ed7fc35bd23f389766c18d6f54ea6) | [0x9f79a7d30e9ed7fc35bd23f389766c18d6f54ea6](https://sepolia.etherscan.io/address/0x9f79a7d30e9ed7fc35bd23f389766c18d6f54ea6) |
|_Main instance contracts_|
| LlamaCore (logic contract)            | [0x678af27e1b003dc53303709ef9415d63d87aeaae](https://goerli.etherscan.io/address/0x678af27e1b003dc53303709ef9415d63d87aeaae) | [0x678af27e1b003dc53303709ef9415d63d87aeaae](https://sepolia.etherscan.io/address/0x678af27e1b003dc53303709ef9415d63d87aeaae) |  
| LlamaPolicy (logic contract)          | [0x9948d8bb62bdbc69ef6c719661ad1e25e14283df](https://goerli.etherscan.io/address/0x9948d8bb62bdbc69ef6c719661ad1e25e14283df) | [0x9948d8bb62bdbc69ef6c719661ad1e25e14283df](https://sepolia.etherscan.io/address/0x9948d8bb62bdbc69ef6c719661ad1e25e14283df) |
| LlamaPolicyMetadata  (logic contract) | [0xd7D2137ee8df4F948D4E4Db64125F99f9550bAc1](https://goerli.etherscan.io/address/0xd7D2137ee8df4F948D4E4Db64125F99f9550bAc1) | [0xd7D2137ee8df4F948D4E4Db64125F99f9550bAc1](https://sepolia.etherscan.io/address/0xd7D2137ee8df4F948D4E4Db64125F99f9550bAc1) |
|_Strategy logic contracts_|
| LlamaRelativeQuantityQuorum           | [0x4Ac1f27666431ecB522DE4a28125fB94A7e66C33](https://goerli.etherscan.io/address/0x4Ac1f27666431ecB522DE4a28125fB94A7e66C33) | [0x4Ac1f27666431ecB522DE4a28125fB94A7e66C33](https://sepolia.etherscan.io/address/0x4Ac1f27666431ecB522DE4a28125fB94A7e66C33) |
| LlamaRelativeHolderQuorum             | [0x73d1f8fc00eb4115640fa270071fd6498c6e2877](https://goerli.etherscan.io/address/0x73d1f8fc00eb4115640fa270071fd6498c6e2877) | [0x73d1f8fc00eb4115640fa270071fd6498c6e2877](https://sepolia.etherscan.io/address/0x73d1f8fc00eb4115640fa270071fd6498c6e2877) |
| LlamaRelativeUniqueHolderQuorum       | [0x829a49179C4Ffa99C6e5115e2dDE183f0E9b1E72](https://goerli.etherscan.io/address/0x829a49179C4Ffa99C6e5115e2dDE183f0E9b1E72) | [0x829a49179C4Ffa99C6e5115e2dDE183f0E9b1E72](https://sepolia.etherscan.io/address/0x829a49179C4Ffa99C6e5115e2dDE183f0E9b1E72) |
| LlamaAbsoluteQuorum                   | [0xfa9cFDE292078908C4BF3C894d7cC22e2C34c3DD](https://goerli.etherscan.io/address/0xfa9cFDE292078908C4BF3C894d7cC22e2C34c3DD) | [0xfa9cFDE292078908C4BF3C894d7cC22e2C34c3DD](https://sepolia.etherscan.io/address/0xfa9cFDE292078908C4BF3C894d7cC22e2C34c3DD) |
| LlamaAbsolutePeerReview               | [0x5e09dde1b306dea40b9944632c87dca680888b17](https://goerli.etherscan.io/address/0x5e09dde1b306dea40b9944632c87dca680888b17) | [0x5e09dde1b306dea40b9944632c87dca680888b17](https://sepolia.etherscan.io/address/0x5e09dde1b306dea40b9944632c87dca680888b17) |
|_Account logic contract_|
| LlamaAccount (logic contract)         | [0x4515869e25d0a31c1f7cb4ea8b1ec21d108bbbae](https://goerli.etherscan.io/address/0x4515869e25d0a31c1f7cb4ea8b1ec21d108bbbae) | [0x4515869e25d0a31c1f7cb4ea8b1ec21d108bbbae](https://sepolia.etherscan.io/address/0x4515869e25d0a31c1f7cb4ea8b1ec21d108bbbae) |
|_Helper contract_|
| LlamaLens                             | [0xa3f43FF2B0f8718356d5B7df1B5154d71524e571](https://goerli.etherscan.io/address/0xa3f43FF2B0f8718356d5B7df1B5154d71524e571) | [0xa3f43FF2B0f8718356d5B7df1B5154d71524e571](https://sepolia.etherscan.io/address/0xa3f43FF2B0f8718356d5B7df1B5154d71524e571) |

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
