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
| LlamaFactory                          | [0x801e873ee77bD09b3FEb7A855304bBb88F1C0f02](https://goerli.etherscan.io/address/0x801e873ee77bD09b3FEb7A855304bBb88F1C0f02) | [0x801e873ee77bD09b3FEb7A855304bBb88F1C0f02](https://sepolia.etherscan.io/address/0x801e873ee77bD09b3FEb7A855304bBb88F1C0f02) |
|_Main instance contracts_|
| LlamaCore (logic contract)            | [0x38aE1c0dbb6e08D248fd36EC40E5740226FcdcAb](https://goerli.etherscan.io/address/0x38aE1c0dbb6e08D248fd36EC40E5740226FcdcAb) | [0x38aE1c0dbb6e08D248fd36EC40E5740226FcdcAb](https://sepolia.etherscan.io/address/0x38aE1c0dbb6e08D248fd36EC40E5740226FcdcAb) |  
| LlamaPolicy (logic contract)          | [0x56e1F6E02d58a50359E23e5a5aA7d6F82eBC71E4](https://goerli.etherscan.io/address/0x56e1F6E02d58a50359E23e5a5aA7d6F82eBC71E4) | [0x56e1F6E02d58a50359E23e5a5aA7d6F82eBC71E4](https://sepolia.etherscan.io/address/0x56e1F6E02d58a50359E23e5a5aA7d6F82eBC71E4) |
| LlamaPolicyMetadata  (logic contract) | [0x85551FaEB57c29E4D9F25894a316644884855d36](https://goerli.etherscan.io/address/0x85551FaEB57c29E4D9F25894a316644884855d36) | [0x85551FaEB57c29E4D9F25894a316644884855d36](https://sepolia.etherscan.io/address/0x85551FaEB57c29E4D9F25894a316644884855d36) |
|_Strategy logic contracts_|
| LlamaRelativeQuantityQuorum           | [0x3B49a370d74D98C3E0e8700CBE29f708d7bca771](https://goerli.etherscan.io/address/0x3B49a370d74D98C3E0e8700CBE29f708d7bca771) | [0x3B49a370d74D98C3E0e8700CBE29f708d7bca771](https://sepolia.etherscan.io/address/0x3B49a370d74D98C3E0e8700CBE29f708d7bca771) |
| LlamaRelativeHolderQuorum             | [0x2a1FDC2EbbD58a3EcA3f299B90E5b0Ea9213fDCa](https://goerli.etherscan.io/address/0x2a1FDC2EbbD58a3EcA3f299B90E5b0Ea9213fDCa) | [0x2a1FDC2EbbD58a3EcA3f299B90E5b0Ea9213fDCa](https://sepolia.etherscan.io/address/0x2a1FDC2EbbD58a3EcA3f299B90E5b0Ea9213fDCa) |
| LlamaRelativeUniqueHolderQuorum       | [0x5DFFe703750fce80Deaca9C044269d3204EE0aE5](https://goerli.etherscan.io/address/0x5DFFe703750fce80Deaca9C044269d3204EE0aE5) | [0x5DFFe703750fce80Deaca9C044269d3204EE0aE5](https://sepolia.etherscan.io/address/0x5DFFe703750fce80Deaca9C044269d3204EE0aE5) |
| LlamaAbsoluteQuorum                   | [0xAC17527be33Af7C1ccC3563D5C81ef0195bF19b5](https://goerli.etherscan.io/address/0xAC17527be33Af7C1ccC3563D5C81ef0195bF19b5) | [0xAC17527be33Af7C1ccC3563D5C81ef0195bF19b5](https://sepolia.etherscan.io/address/0xAC17527be33Af7C1ccC3563D5C81ef0195bF19b5) |
| LlamaAbsolutePeerReview               | [0x3B233650294aC86EfDdea889Ad9f03aAb7347120](https://goerli.etherscan.io/address/0x3B233650294aC86EfDdea889Ad9f03aAb7347120) | [0x3B233650294aC86EfDdea889Ad9f03aAb7347120](https://sepolia.etherscan.io/address/0x3B233650294aC86EfDdea889Ad9f03aAb7347120) |
|_Account logic contract_|
| LlamaAccount (logic contract)         | [0x4DfD012A47bB62d92b38eAA1444EC475B19F3b56](https://goerli.etherscan.io/address/0x4DfD012A47bB62d92b38eAA1444EC475B19F3b56) | [0x4DfD012A47bB62d92b38eAA1444EC475B19F3b56](https://sepolia.etherscan.io/address/0x4DfD012A47bB62d92b38eAA1444EC475B19F3b56) |
|_Helper contract_|
| LlamaLens                             | [0xE605EebB4fe477ADf36cC49F529BBa4900D5eE8B](https://goerli.etherscan.io/address/0xE605EebB4fe477ADf36cC49F529BBa4900D5eE8B) | [0xE605EebB4fe477ADf36cC49F529BBa4900D5eE8B](https://sepolia.etherscan.io/address/0xE605EebB4fe477ADf36cC49F529BBa4900D5eE8B) |

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
