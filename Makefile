# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update   :; forge update
install  :; forge install

# Build & test
build    :; forge clean && forge build --sizes
test     :; forge clean && forge test --rpc-url ${RPC_MAINNET_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} $(call compute_test_verbosity,${V}) # Usage: make test [optional](V=<{1,2,3,4,5}>)
match    :; forge clean && forge test --rpc-url ${RPC_MAINNET_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} -m ${MATCH} $(call compute_test_verbosity,${V}) # Usage: make match MATCH=<TEST_FUNCTION_NAME> [optional](V=<{1,2,3,4,5}>)
report   :; forge clean && forge test --gas-report | sed -e/╭/\{ -e:1 -en\;b1 -e\} -ed | cat > .gas-report

# Deploy and Verify Payload
deploy   :; forge script script/Counter.s.sol:CounterScript --rpc-url ${RPC_MAINNET_URL} --broadcast --private-key ${PRIVATE_KEY} --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv
verify   :; forge script script/Counter.s.sol:CounterScript --rpc-url ${RPC_MAINNET_URL} --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

# Clean & lint
clean    :; forge clean
lint     :; npx prettier --write src/**/*.sol script/**/*.sol tests/**/*.sol

# Defaults to -v if no V=<{1,2,3,4,5} specified
define compute_test_verbosity
$(strip \
$(if $(filter 1,$(1)),-v,\
$(if $(filter 2,$(1)),-vv,\
$(if $(filter 3,$(1)),-vvv,\
$(if $(filter 4,$(1)),-vvvv,\
$(if $(filter 5,$(1)),-vvvvv,\
-v
))))))
endef
