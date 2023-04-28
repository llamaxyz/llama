#!/usr/bin/env -S just --justfile

set dotenv-load

report:
  forge clean && FOUNDRY_PROFILE=ci forge test --gas-report --fuzz-seed 1 | sed -e/\|/\{ -e:1 -en\;b1 -e\} -ed | cat > .gas-report

yul contractName:
  forge inspect {{contractName}} ir-optimized > yul.sol

run-script script_name flags='' sig='' args='':
  # To speed up compilation we temporarily rename the test directory.
  mv test _test
  # We hyphenate so that we still cleanup the directory names even if the deploy fails.
  - FOUNDRY_PROFILE=ci forge script script/{{script_name}}.s.sol {{sig}} {{args}} \
    --rpc-url $SCRIPT_RPC_URL \
    --private-key $SCRIPT_PRIVATE_KEY \
    -vvvv {{flags}}
  mv _test test

run-create-action-script flags: (run-script 'CreateAction' flags '--sig "run(address)"' '$SCRIPT_DEPLOYER_ADDRESS')

dry-run-deploy: (run-script 'DeployLlama')

deploy: (run-script 'DeployLlama' '--broadcast --verify')

verify: (run-script 'DeployLlama' '--verify')

dry-run-create-new-llama: (run-create-action-script '')

# Verification is unnecessary for this script because it does not create any contracts.
create-new-llama: (run-create-action-script '--broadcast')
