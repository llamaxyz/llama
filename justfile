#!/usr/bin/env -S just --justfile

set dotenv-load

report:
  forge clean && forge test --gas-report | sed -e/\|/\{ -e:1 -en\;b1 -e\} -ed | cat > .gas-report

yul contractName:
  forge inspect {{contractName}} ir-optimized > yul.sol

dry-run:
  forge script script/Deploy.s.sol:Deploy --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY --verify -vvvv

deploy:
  forge script script/Deploy.s.sol:Deploy --rpc-url $MAINNET_RPC_URL --broadcast --private-key $PRIVATE_KEY --verify -vvvv

verify:
  forge script script/Deploy.s.sol:Deploy --rpc-url $MAINNET_RPC_URL --verify -vvvv
