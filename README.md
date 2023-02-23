# Vertex v1

Vertex v1 is a smart contract access control and administration framework.

## Prerequisites

It requires [Foundry](https://github.com/gakonst/foundry) installed to run. You can find instructions here [Foundry installation](https://github.com/gakonst/foundry#installation).

MacOS users can follow [this guide](https://tecadmin.net/install-nvm-macos-with-homebrew/) to install Node.js and NPM. Once installed, ensure you're running the correct versions:

```sh
$ node -v # v16.15.1 or higher
$ npm -v # v8.12.2 or higher
```

### VS Code

You can get Solidity support for Visual Studio Code by installing the [VSCode Solidity extension](https://github.com/juanfranblanco/vscode-solidity).

## Installation

```sh
$ git clone https://github.com/llama-community/vertex-v1.git
$ cd vertex-v1
$ npm install
$ make install
$ git submodule update --init --recursive
```

## Setup

Duplicate `.env.example` and rename to `.env`:

- Add a valid mainnet URL for an Ethereum JSON-RPC client for the `MAINNET_RPC_URL` variable.
- Add a valid Private Key for the `PRIVATE_KEY` variable.
- Add a valid Etherscan API Key for the `ETHERSCAN_API_KEY` variable.

### Commands

- `make build` - build the project
- `make test [optional](V={1,2,3,4,5})` - run tests (with different debug levels if provided)
- `make match MATCH=<TEST_FUNCTION_NAME> [optional](V=<{1,2,3,4,5}>)` - run matched tests (with different debug levels if provided)

### Deploy and Verify

- `make deploy` - deploy and verify payload on mainnet

To confirm the deploy was successful, re-run your test suite but use the newly created contract address.

## Documentation

The generate documentation for the project and serve those static files locally, run the following commands:

```sh
$ make doc
$ forge doc -s
```
