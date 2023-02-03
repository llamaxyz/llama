# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update   :; forge update
install  :; forge install

# Build & test
build    :; forge clean && forge build --sizes --via-ir
test     :; forge test --fork-url ${RPC_MAINNET_URL} $(call compute_test_verbosity,${V}) # Usage: make test [optional](V=<{1,2,3,4,5}>)
match    :; forge test --fork-url ${RPC_MAINNET_URL} -m ${MATCH} $(call compute_test_verbosity,${V}) # Usage: make match MATCH=<TEST_FUNCTION_NAME> [optional](V=<{1,2,3,4,5}>)
watch    :; forge test --fork-url ${RPC_MAINNET_URL} --watch $(call compute_test_verbosity,${V}) # Usage: make test [optional](V=<{1,2,3,4,5}>)
report   :; forge clean && forge test --gas-report | sed -e/\|/\{ -e:1 -en\;b1 -e\} -ed | cat > .gas-report
doc      :; forge doc -b
yul      :; forge clean && forge build --via-ir --extra-output ir-optimized && cat ./out/${CONTRACT}.sol/${CONTRACT}.json | jq -r .irOptimized | perl -pe 's/\\n/\n/g' > ${CONTRACT}-yul.sol

# Deploy and Verify Payload
deploy   :; forge script script/Vertex.s.sol:VertexScript --fork-url ${RPC_MAINNET_URL} --broadcast --private-key ${PRIVATE_KEY} --verify -vvvv
verify   :; forge script script/Vertex.s.sol:VertexScript --fork-url ${RPC_MAINNET_URL} --verify -vvvv

# Clean & lint
clean    :; forge clean
lint     :; forge fmt

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
