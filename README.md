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

## Testnet deployments

| Name                                  | Sepolia                                                                                                                       | Goerli                                                                                                                       | Optimism Goerli                                                                                                                       | Base Goerli                                                                                                                  | Arbitrum Goerli                                                                                                             |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------  | ------------------------------------------------------------------------------------------------------------------------------------  | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
|_Factory_|
| LlamaFactory                          | [0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6](https://sepolia.etherscan.io/address/0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6) | [0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6](https://goerli.etherscan.io/address/0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6) | [0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6](https://goerli-optimism.etherscan.io/address/0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6) | [0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6](https://goerli.basescan.org/address/0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6) | [0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6](https://goerli.arbiscan.io/address/0x1711567DC0dd5667fb0AA1Cc8A400E5D724fe6c6) |
|_Main instance contracts_|
| LlamaCore (logic contract)            | [0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601](https://sepolia.etherscan.io/address/0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601) | [0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601](https://goerli.etherscan.io/address/0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601) | [0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601](https://goerli-optimism.etherscan.io/address/0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601) | [0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601](https://goerli.basescan.org/address/0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601) | [0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601](https://goerli.arbiscan.io/address/0x5387Ba4E0DEeA1EBb85315eAc24EF5974BC54601) |         
| LlamaPolicy (logic contract)          | [0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F](https://sepolia.etherscan.io/address/0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F) | [0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F](https://goerli.etherscan.io/address/0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F) | [0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F](https://goerli-optimism.etherscan.io/address/0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F) | [0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F](https://goerli.basescan.org/address/0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F) | [0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F](https://goerli.arbiscan.io/address/0xfF21Eeb8766E99de2ebDd2F171004e10020A6C9F) |
| LlamaPolicyMetadata  (logic contract) | [0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25](https://sepolia.etherscan.io/address/0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25) | [0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25](https://goerli.etherscan.io/address/0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25) | [0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25](https://goerli-optimism.etherscan.io/address/0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25) | [0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25](https://goerli.basescan.org/address/0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25) | [0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25](https://goerli.arbiscan.io/address/0x3c2Ab7959b49e83FDF55C1E8A44c0D9Ba77b4F25) |
|_Strategy logic contracts_|
| LlamaRelativeQuantityQuorum           | [0x6ed0741e8BCE77455aa956F91823D70EC10c4838](https://sepolia.etherscan.io/address/0x6ed0741e8BCE77455aa956F91823D70EC10c4838) | [0x6ed0741e8BCE77455aa956F91823D70EC10c4838](https://goerli.etherscan.io/address/0x6ed0741e8BCE77455aa956F91823D70EC10c4838) | [0x6ed0741e8BCE77455aa956F91823D70EC10c4838](https://goerli-optimism.etherscan.io/address/0x6ed0741e8BCE77455aa956F91823D70EC10c4838) | [0x6ed0741e8BCE77455aa956F91823D70EC10c4838](https://goerli.basescan.org/address/0x6ed0741e8BCE77455aa956F91823D70EC10c4838) | [0x6ed0741e8BCE77455aa956F91823D70EC10c4838](https://goerli.arbiscan.io/address/0x6ed0741e8BCE77455aa956F91823D70EC10c4838) |
| LlamaRelativeHolderQuorum             | [0x2d117f60a15bB816E0868B1DF323D13e46D74fdB](https://sepolia.etherscan.io/address/0x2d117f60a15bB816E0868B1DF323D13e46D74fdB) | [0x2d117f60a15bB816E0868B1DF323D13e46D74fdB](https://goerli.etherscan.io/address/0x2d117f60a15bB816E0868B1DF323D13e46D74fdB) | [0x2d117f60a15bB816E0868B1DF323D13e46D74fdB](https://goerli-optimism.etherscan.io/address/0x2d117f60a15bB816E0868B1DF323D13e46D74fdB) | [0x2d117f60a15bB816E0868B1DF323D13e46D74fdB](https://goerli.basescan.org/address/0x2d117f60a15bB816E0868B1DF323D13e46D74fdB) | [0x2d117f60a15bB816E0868B1DF323D13e46D74fdB](https://goerli.arbiscan.io/address/0x2d117f60a15bB816E0868B1DF323D13e46D74fdB) | 
| LlamaRelativeUniqueHolderQuorum       | [0x0479A850a6Ce2eF13F623e0F5637487B7F81E947](https://sepolia.etherscan.io/address/0x0479A850a6Ce2eF13F623e0F5637487B7F81E947) | [0x0479A850a6Ce2eF13F623e0F5637487B7F81E947](https://goerli.etherscan.io/address/0x0479A850a6Ce2eF13F623e0F5637487B7F81E947) | [0x0479A850a6Ce2eF13F623e0F5637487B7F81E947](https://goerli-optimism.etherscan.io/address/0x0479A850a6Ce2eF13F623e0F5637487B7F81E947) | [0x0479A850a6Ce2eF13F623e0F5637487B7F81E947](https://goerli.basescan.org/address/0x0479A850a6Ce2eF13F623e0F5637487B7F81E947) | [0x0479A850a6Ce2eF13F623e0F5637487B7F81E947](https://goerli.arbiscan.io/address/0x0479A850a6Ce2eF13F623e0F5637487B7F81E947) |
| LlamaAbsoluteQuorum                   | [0x9aD3D59516123E584084363592D49a045c717665](https://sepolia.etherscan.io/address/0x9aD3D59516123E584084363592D49a045c717665) | [0x9aD3D59516123E584084363592D49a045c717665](https://goerli.etherscan.io/address/0x9aD3D59516123E584084363592D49a045c717665) | [0x9aD3D59516123E584084363592D49a045c717665](https://goerli-optimism.etherscan.io/address/0x9aD3D59516123E584084363592D49a045c717665) | [0x9aD3D59516123E584084363592D49a045c717665](https://goerli.basescan.org/address/0x9aD3D59516123E584084363592D49a045c717665) | [0x9aD3D59516123E584084363592D49a045c717665](https://goerli.arbiscan.io/address/0x9aD3D59516123E584084363592D49a045c717665) |
| LlamaAbsolutePeerReview               | [0x334D3C1479011b874DCC235EdE8b39064212D8cb](https://sepolia.etherscan.io/address/0x334D3C1479011b874DCC235EdE8b39064212D8cb) | [0x334D3C1479011b874DCC235EdE8b39064212D8cb](https://goerli.etherscan.io/address/0x334D3C1479011b874DCC235EdE8b39064212D8cb) | [0x334D3C1479011b874DCC235EdE8b39064212D8cb](https://goerli-optimism.etherscan.io/address/0x334D3C1479011b874DCC235EdE8b39064212D8cb) | [0x334D3C1479011b874DCC235EdE8b39064212D8cb](https://goerli.basescan.org/address/0x334D3C1479011b874DCC235EdE8b39064212D8cb) | [0x334D3C1479011b874DCC235EdE8b39064212D8cb](https://goerli.arbiscan.io/address/0x334D3C1479011b874DCC235EdE8b39064212D8cb) |
|_Account logic contract_|
| LlamaAccount (logic contract)         | [0xf9CdC99a3BaA178BD499653B01D0db794738fb8F](https://sepolia.etherscan.io/address/0xf9CdC99a3BaA178BD499653B01D0db794738fb8F) | [0xf9CdC99a3BaA178BD499653B01D0db794738fb8F](https://goerli.etherscan.io/address/0xf9CdC99a3BaA178BD499653B01D0db794738fb8F) | [0xf9CdC99a3BaA178BD499653B01D0db794738fb8F](https://goerli-optimism.etherscan.io/address/0xf9CdC99a3BaA178BD499653B01D0db794738fb8F) | [0xf9CdC99a3BaA178BD499653B01D0db794738fb8F](https://goerli.basescan.org/address/0xf9CdC99a3BaA178BD499653B01D0db794738fb8F) | [0xf9CdC99a3BaA178BD499653B01D0db794738fb8F](https://goerli.arbiscan.io/address/0xf9CdC99a3BaA178BD499653B01D0db794738fb8F) |
|_Helper contract_|
| LlamaLens                             | [0x09641350941CbAE35981A65C5ff2CE7F481184CF](https://sepolia.etherscan.io/address/0x09641350941CbAE35981A65C5ff2CE7F481184CF) | [0x09641350941CbAE35981A65C5ff2CE7F481184CF](https://goerli.etherscan.io/address/0x09641350941CbAE35981A65C5ff2CE7F481184CF) | [0x09641350941CbAE35981A65C5ff2CE7F481184CF](https://goerli-optimism.etherscan.io/address/0x09641350941CbAE35981A65C5ff2CE7F481184CF) | [0x09641350941CbAE35981A65C5ff2CE7F481184CF](https://goerli.basescan.org/address/0x09641350941CbAE35981A65C5ff2CE7F481184CF) | [0x09641350941CbAE35981A65C5ff2CE7F481184CF](https://goerli.arbiscan.io/address/0x09641350941CbAE35981A65C5ff2CE7F481184CF) |

## Documentation

To read all of our documentation, visit [https://docs.llama.xyz](https://docs.llama.xyz). To view Llama framework documentation only, visit the [docs directory](https://github.com/llamaxyz/llama/tree/main/docs).

### Smart contract reference

Run the following command to generate smart contract reference documentation from our NatSpec comments and serve those static files locally:

```sh
$ forge doc -o reference/ -b -s
```

## Security

### Audits

We received audits from Spearbit and Code4rena. You can find links to the reports below:

- [Llama Spearbit Audit](https://github.com/llamaxyz/llama/blob/main/audits/Llama-Spearbit-Audit.pdf)
- [Llama Code4rena Audit](https://github.com/llamaxyz/llama/blob/main/audits/Llama-Code4rena-Audit.md)

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
