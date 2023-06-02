![Llama](.github/assets/llama-banner.png)

![CI](https://github.com/llamaxyz/llama/actions/workflows/ci.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# Llama

Llama is a governance system for onchain organizations. It uses non-transferable NFTs to encode access control, features programmatic control of funds, and includes a modular framework to define action execution rules.

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

## Deployments

| Name                             | Address                                    | Verified                                                                           |
| -------------------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------- |
| LlamaCoreLogic                   | [0xa897FCE700D9AFe42431E9b096c785f1bcE6aD06](https://goerli.etherscan.io/address/0xa897FCE700D9AFe42431E9b096c785f1bcE6aD06) |    ✅    |
| LlamaRelativeStrategyLogic       | [0x28b6E1Aac7a5c3eBfDD84e425b3e31be2fF714aD](https://goerli.etherscan.io/address/0x28b6E1Aac7a5c3eBfDD84e425b3e31be2fF714aD) |    ✅    |
| LlamaAbsoluteStrategyLogic       | [0x9839ea98F18fd06f2e9be19B6A2E00dc11654755](https://goerli.etherscan.io/address/0x9839ea98F18fd06f2e9be19B6A2E00dc11654755) |    ✅    |
| LlamaAccountLogic                | [0x6428F81B3c72449b6e4F94C6f40cAbC349B90b73](https://goerli.etherscan.io/address/0x6428F81B3c72449b6e4F94C6f40cAbC349B90b73) |    ✅    |
| LlamaPolicyLogic                 | [0x956b02429CB68FFa10B571D10A7cC8A92DbCefde](https://goerli.etherscan.io/address/0x956b02429CB68FFa10B571D10A7cC8A92DbCefde) |    ❌    |
| LlamaPolicyMetadata              | [0x760A113aca237bb7646B9Cc91A8223E522517344](https://goerli.etherscan.io/address/0x760A113aca237bb7646B9Cc91A8223E522517344) |    ❌    |
| LlamaFactory                     | [0x751eB347942429b783104f00B507b7774eA033Ea](https://goerli.etherscan.io/address/0x751eB347942429b783104f00B507b7774eA033Ea) |    ❌    |
| LlamaPolicyMetadataParamRegistry | [0x5eE8FCE7f2E3da5f618eF1b709b660DbF30A6951](https://goerli.etherscan.io/address/0x5eE8FCE7f2E3da5f618eF1b709b660DbF30A6951) |    ❌    |
| LlamaLens                        | [0xCEbd76456281441539200Baa575ba36A19BDf354](https://goerli.etherscan.io/address/0xCEbd76456281441539200Baa575ba36A19BDf354) |    ❌    |
| Root's Llama Policy              | [0x769daFACb25556B483264F57bD7647dE725F8FFe](https://goerli.etherscan.io/address/0x769daFACb25556B483264F57bD7647dE725F8FFe) |    ❌    |
| Root's LlamaCore                 | [0xD7941726eD07894c4b8E60B15e7973e0F0936bfa](https://goerli.etherscan.io/address/0xD7941726eD07894c4b8E60B15e7973e0F0936bfa) |    ✅    |
| Root's LlamaExecutor             | [0xaEe7e3b3eFd968fB93cb97ed0a61c155a17d8Fb9](https://goerli.etherscan.io/address/0xaEe7e3b3eFd968fB93cb97ed0a61c155a17d8Fb9) |    ❌    |
| Root's Strategy #1               | [0x0d7401D1CC655b64BA11C0AC4272C09528793a58](https://goerli.etherscan.io/address/0x0d7401D1CC655b64BA11C0AC4272C09528793a58) |    ✅    |
| Root's Llama Treasury Account    | [0xa68a6834485c3864bbf3311Fae178c85bF8852CE](https://goerli.etherscan.io/address/0xa68a6834485c3864bbf3311Fae178c85bF8852CE) |    ✅    |
| Root's Llama Grants Account      | [0xe57c7A46c71F864b1004e110dCB3e908496c1d55](https://goerli.etherscan.io/address/0xe57c7A46c71F864b1004e110dCB3e908496c1d55) |    ✅    |

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
