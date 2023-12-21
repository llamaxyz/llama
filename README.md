![Llama](.github/assets/llama-banner.png)

![CI](https://github.com/llamaxyz/llama/actions/workflows/ci.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# Llama

Llama is an onchain governance and access control framework for smart contracts. It uses non-transferable NFTs to encode access control, features programmatic control of funds, and includes modular strategies to define action execution rules.

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

| Name                                  | Ethereum                                                                                                              | Optimism                                                                                                                         | Arbitrum                                                                                                             | Base                                                                                                                  | Polygon                                                                                                                  |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------  | -------------------------------------------------------------------------------------------------------------------  | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
|_Factory_|
| LlamaFactory                          | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://etherscan.io/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://optimistic.etherscan.io/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://arbiscan.io/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://basescan.org/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://polygonscan.com/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) |
|_Main instance contracts_|
| LlamaCore (logic contract)            | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://etherscan.io/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://optimistic.etherscan.io/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://arbiscan.io/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://basescan.org/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://polygonscan.com/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) |         
| LlamaPolicy (logic contract)          | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://etherscan.io/address/0x19640A82e696f67F0d25307e19c4307321761d4d) | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://optimistic.etherscan.io/address/0x19640A82e696f67F0d25307e19c4307321761d4d) | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://arbiscan.io/address/0x19640A82e696f67F0d25307e19c4307321761d4d) | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://basescan.org/address/0x19640A82e696f67F0d25307e19c4307321761d4d) | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://polygonscan.com/address/0x19640A82e696f67F0d25307e19c4307321761d4d) |
| LlamaPolicyMetadata (logic contract)  | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://etherscan.io/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://optimistic.etherscan.io/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://arbiscan.io/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://basescan.org/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://polygonscan.com/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) |
|_Strategy logic contracts_|
| LlamaRelativeQuantityQuorum           | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://etherscan.io/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://optimistic.etherscan.io/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://arbiscan.io/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://basescan.org/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://polygonscan.com/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) |
| LlamaRelativeHolderQuorum             | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://etherscan.io/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://optimistic.etherscan.io/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://arbiscan.io/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://basescan.org/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://polygonscan.com/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | 
| LlamaRelativeUniqueHolderQuorum       | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://etherscan.io/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://optimistic.etherscan.io/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://arbiscan.io/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://basescan.org/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://polygonscan.com/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) |
| LlamaAbsoluteQuorum                   | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://etherscan.io/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://optimistic.etherscan.io/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://arbiscan.io/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://basescan.org/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://polygonscan.com/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) |
| LlamaAbsolutePeerReview               | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://etherscan.io/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://optimistic.etherscan.io/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://arbiscan.io/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://basescan.org/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://polygonscan.com/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) |
|_Account logic contract_|
| LlamaAccount (logic contract)         | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://etherscan.io/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://optimistic.etherscan.io/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://arbiscan.io/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://basescan.org/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://polygonscan.com/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) |
|_Helper contract_|
| LlamaLens                             | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://etherscan.io/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://optimistic.etherscan.io/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://arbiscan.io/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://basescan.org/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://polygonscan.com/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) |
|_Script contracts_|
| LlamaGovernanceScript                 | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://etherscan.io/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://optimistic.etherscan.io/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://arbiscan.io/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://basescan.org/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://polygonscan.com/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) |

## Testnet deployments

| Name                                  | Sepolia                                                                                                                       | Goerli                                                                                                                       | Optimism Goerli                                                                                                                       | Base Goerli                                                                                                                  |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------  | ------------------------------------------------------------------------------------------------------------------------------------  | ---------------------------------------------------------------------------------------------------------------------------- |
|_Factory_|
| LlamaFactory                          | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://sepolia.etherscan.io/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://goerli.etherscan.io/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://goerli-optimism.etherscan.io/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) | [0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB](https://goerli.basescan.org/address/0xFf5d4E226D9A3496EECE31083a8F493edd79AbEB) |
|_Main instance contracts_|
| LlamaCore (logic contract)            | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://sepolia.etherscan.io/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://goerli.etherscan.io/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://goerli-optimism.etherscan.io/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) | [0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14](https://goerli.basescan.org/address/0x676ca05Fd577FCA8fddb4605d4992Bc7EfbCff14) |     
| LlamaPolicy (logic contract)          | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://sepolia.etherscan.io/address/0x19640A82e696f67F0d25307e19c4307321761d4d) | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://goerli.etherscan.io/address/0x19640A82e696f67F0d25307e19c4307321761d4d) | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://goerli-optimism.etherscan.io/address/0x19640A82e696f67F0d25307e19c4307321761d4d) | [0x19640A82e696f67F0d25307e19c4307321761d4d](https://goerli.basescan.org/address/0x19640A82e696f67F0d25307e19c4307321761d4d) |
| LlamaPolicyMetadata (logic contract)  | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://sepolia.etherscan.io/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://goerli.etherscan.io/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://goerli-optimism.etherscan.io/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) | [0xf2C61E275d48efA8a6556529F60cE1E376510e0F](https://goerli.basescan.org/address/0xf2C61E275d48efA8a6556529F60cE1E376510e0F) |
|_Strategy logic contracts_|
| LlamaRelativeQuantityQuorum           | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://sepolia.etherscan.io/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://goerli.etherscan.io/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://goerli-optimism.etherscan.io/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) | [0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc](https://goerli.basescan.org/address/0x81F7D26fD7d814bFcEF78239a32c0BA5282C98Dc) |
| LlamaRelativeHolderQuorum             | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://sepolia.etherscan.io/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://goerli.etherscan.io/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://goerli-optimism.etherscan.io/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | [0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE](https://goerli.basescan.org/address/0xE7EE15321bAD254dAC7495867Ea2C8C9c77Ee4eE) | 
| LlamaRelativeUniqueHolderQuorum       | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://sepolia.etherscan.io/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://goerli.etherscan.io/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://goerli-optimism.etherscan.io/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) | [0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb](https://goerli.basescan.org/address/0xa5B2B5Ae8F278530270f44D7CFC2440292583BEb) |
| LlamaAbsoluteQuorum                   | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://sepolia.etherscan.io/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://goerli.etherscan.io/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://goerli-optimism.etherscan.io/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) | [0x68f153D5F50e66CC0c6D9802362137BCF2aE5631](https://goerli.basescan.org/address/0x68f153D5F50e66CC0c6D9802362137BCF2aE5631) |
| LlamaAbsolutePeerReview               | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://sepolia.etherscan.io/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://goerli.etherscan.io/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://goerli-optimism.etherscan.io/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) | [0x0092CD4044E1672c9c513867eb75e6213AF9742f](https://goerli.basescan.org/address/0x0092CD4044E1672c9c513867eb75e6213AF9742f) |
|_Account logic contract_|
| LlamaAccount (logic contract)         | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://sepolia.etherscan.io/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://goerli.etherscan.io/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://goerli-optimism.etherscan.io/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) | [0x915Af6753f03D2687Fa923b2987625e21e2991aE](https://goerli.basescan.org/address/0x915Af6753f03D2687Fa923b2987625e21e2991aE) |
|_Helper contract_|
| LlamaLens                             | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://sepolia.etherscan.io/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://goerli.etherscan.io/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://goerli-optimism.etherscan.io/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) | [0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB](https://goerli.basescan.org/address/0x1D74803D4939aFa3CC9fF1B8667bE4d119d925cB) |
|_Script contracts_|
| LlamaGovernanceScript                 | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://sepolia.etherscan.io/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://goerli.etherscan.io/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://goerli-optimism.etherscan.io/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) | [0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335](https://goerli.basescan.org/address/0x21f45e61213a13Dc6B7Ba2eC157c4e95810cD335) |

## Documentation

To read all of our documentation, visit [https://docs.llama.xyz](https://docs.llama.xyz). To view Llama framework documentation only, visit the [docs directory](https://github.com/llamaxyz/llama/tree/main/docs).

### Smart contract reference

Run the following command to generate smart contract reference documentation from our NatSpec comments and serve those static files locally:

```sh
$ forge doc -o reference/ -b -s
```

## Security

### Audits

We received two audits from Spearbit and one from Code4rena. You can find links to the reports below:

- [Llama Spearbit Audit (June 2023)](https://github.com/llamaxyz/llama/blob/main/audits/Llama-Spearbit-Audit.pdf)
- [Llama Code4rena Audit](https://github.com/llamaxyz/llama/blob/main/audits/Llama-Code4rena-Audit.md)
- [Llama Spearbit Audit (August 2023)](https://github.com/llamaxyz/llama/blob/main/audits/Llama-Spearbit-Audit-2.pdf)

### Bug bounty program

All contracts in the `src/` directory except `src/LlamaLens.sol` are in scope for the bug bounty program. The root `lib/` directory (not the `src/lib/` directory) and acknowledged findings from our Spearbit and Code4rena audits are out of scope.

Llama policyholders are trusted participants of a Llama instance based on what their roles and permissions allow them to do. Any findings that require policyholders to take malicious action are out of scope for this program.

We adapted the [Immunefi Vulnerability Severity Classification System](https://immunefi.com/immunefi-vulnerability-severity-classification-system-v2-3/) to determine classification.

| **Level**   | **Example**                                                                                                                                                                                                                                                                            | **Maximum Bug Bounty** |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| 5. Critical | - Unauthorized action state transitions<br>- Major manipulation of approval or disapproval results<br>- Vulnerabilities in the roles and permissions system that result in unauthorized ability to create, approve, or disapprove actions<br>- Permanent freezing of funds in accounts | Up to 100,000 USDC     |
| 4. High     | - Minor manipulation of approval or disapproval results that are unlikely to affect outcomes<br>- Minor vulnerabilities in the roles and permissions system that are unlikely to affect outcomes<br>- Temporary freezing of funds in accounts                                           | Up to 20,000 USDC      |
| 3. Medium   | - Griefing that disrupts an instance's action flow                                                                                                                                                                                                                                     | Up to 5,000 USDC       |
| 2. Low      | - Contract fails to deliver promised returns, but doesn't lose value                                                                                                                                                                                                                   | Up to 1,000 USDC       |
| 1. None     | - Best practices                                                                                                                                                                                                                                                                       |                        |
| Not sure?   |                                                                                                                                                                                                                                                                                        | Email us               |

Email us at [security@llama.xyz](mailto:security@llama.xyz) to get in contact.

## Slither

Use our bash script to prevent slither from analyzing the test and script directories. Running `slither .` directly will result in an `AssertionError`.

```sh
$ chmod +x slither.sh
$ ./slither.sh
```
