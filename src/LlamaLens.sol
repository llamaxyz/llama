// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {PermissionData} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Llama Lens
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Utility contract to compute Llama contract addresses and permission IDs.
contract LlamaLens {
  /// @notice The factory contract on this chain.
  address public immutable LLAMA_FACTORY;

  /// @notice The Llama Core implementation (logic) contract.
  address public immutable LLAMA_CORE_LOGIC;

  /// @notice The Llama Policy implementation (logic) contract.
  address public immutable LLAMA_POLICY_LOGIC;

  /// @notice The Llama Account implementation (logic) contract.
  address public immutable LLAMA_ACCOUNT_LOGIC;

  /// @notice Sets the factory address.
  /// @param _llamaFactory the llama factory contract on this chain.
  constructor(address _llamaFactory) {
    LLAMA_FACTORY = _llamaFactory;
    LLAMA_CORE_LOGIC = address(LlamaFactory(LLAMA_FACTORY).LLAMA_CORE_LOGIC());
    LLAMA_POLICY_LOGIC = address(LlamaFactory(LLAMA_FACTORY).LLAMA_POLICY_LOGIC());
    LLAMA_ACCOUNT_LOGIC = address(LlamaFactory(LLAMA_FACTORY).LLAMA_ACCOUNT_LOGIC());
  }

  /// @notice Hashes a permission.
  /// @param permission the permission to hash.
  /// @return the hash of the permission.
  function computePermissionId(PermissionData calldata permission) external pure returns (bytes32) {
    return keccak256(abi.encode(permission));
  }

  /// @notice Computes the address of a llama core from the name of the llama instance.
  /// @param name The name of this llama instance.
  /// @return the computed address of the LlamaCore contract.
  function computeLlamaCoreAddress(string memory name) external view returns (LlamaCore) {
    return _computeLlamaCoreAddress(name);
  }

  /// @notice Computes the address of a llama executor from its core address.
  /// @param llamaCore The address of the LlamaCore contract.
  /// @return the computed address of the LlamaExecutor contract.
  function computeLlamaExecutorAddress(address llamaCore) external pure returns (LlamaExecutor) {
    return LlamaExecutor(_computeCreateAddress(llamaCore, 1));
  }

  /// @notice Computes the address of a llama executor from the name of the llama instance.
  /// @param name The name of this llama instance.
  /// @return the computed address of the LlamaExecutor contract.
  function computeLlamaExecutorAddress(string memory name) external view returns (LlamaExecutor) {
    LlamaCore llamaCore = _computeLlamaCoreAddress(name);
    return LlamaExecutor(_computeCreateAddress(address(llamaCore), 1));
  }

  /// @notice Computes the address of a llama policy with a name value.
  /// @param name The name of this llama instance.
  /// @return the computed address of the LlamaPolicy contract.
  function computeLlamaPolicyAddress(string memory name) external view returns (LlamaPolicy) {
    address _computedAddress = Clones.predictDeterministicAddress(
      LLAMA_POLICY_LOGIC,
      keccak256(abi.encodePacked(name)), // salt
      LLAMA_FACTORY // deployer
    );
    return LlamaPolicy(_computedAddress);
  }

  /// @notice Computes the address of a llama strategy with a strategy value.
  /// @param llamaStrategyLogic The Llama Strategy logic contract.
  /// @param strategy The strategy to be set.
  /// @param llamaCore The llama core to be set.
  /// @return the computed address of the strategy contract.
  function computeLlamaStrategyAddress(address llamaStrategyLogic, bytes memory strategy, address llamaCore)
    external
    pure
    returns (ILlamaStrategy)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      llamaStrategyLogic,
      keccak256(strategy), // salt
      llamaCore // deployer
    );
    return ILlamaStrategy(_computedAddress);
  }

  /// @notice Computes the address of a llama account with a name (account) value.
  /// @param account The account to be set.
  /// @param llamaCore The llama core to be set.
  /// @return the computed address of the LlamaAccount contract.
  function computeLlamaAccountAddress(string calldata account, address llamaCore) external view returns (LlamaAccount) {
    address _computedAddress = Clones.predictDeterministicAddress(
      LLAMA_ACCOUNT_LOGIC,
      keccak256(abi.encodePacked(account)), // salt
      llamaCore // deployer
    );
    return LlamaAccount(payable(_computedAddress));
  }

  function _computeLlamaCoreAddress(string memory name) internal view returns (LlamaCore) {
    address _computedAddress = Clones.predictDeterministicAddress(
      LLAMA_CORE_LOGIC,
      keccak256(abi.encodePacked(name)), // salt
      LLAMA_FACTORY // deployer
    );
    return LlamaCore(_computedAddress);
  }

  /// @dev Adapted from the Forge Standard Library
  /// (https://github.com/foundry-rs/forge-std/blob/9b49a72cfdb36bcf195eb863f868f01a6d6d3186/src/StdUtils.sol#L177)
  function _addressFromLast20Bytes(bytes32 bytesValue) internal pure returns (address) {
    return address(uint160(uint256(bytesValue)));
  }

  /// @dev Compute the address a contract will be deployed at for a given deployer address and nonce.
  /// Adapted from the Forge Standard Library
  /// (https://github.com/foundry-rs/forge-std/blob/9b49a72cfdb36bcf195eb863f868f01a6d6d3186/src/StdUtils.sol#L93)
  function _computeCreateAddress(address deployer, uint256 nonce) internal pure virtual returns (address) {
    // forgefmt: disable-start
    // The integer zero is treated as an empty byte string, and as a result it only has a length prefix, 0x80, computed via 0x80 + 0.
    // A one byte integer uses its own value as its length prefix, there is no additional "0x80 + length" prefix that comes before it.
    if (nonce == 0x00)      return _addressFromLast20Bytes(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80))));
    if (nonce <= 0x7f)      return _addressFromLast20Bytes(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce))));

    // Nonces greater than 1 byte all follow a consistent encoding scheme, where each value is preceded by a prefix of 0x80 + length.
    if (nonce <= 2**8 - 1)  return _addressFromLast20Bytes(keccak256(abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce))));
    if (nonce <= 2**16 - 1) return _addressFromLast20Bytes(keccak256(abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce))));
    if (nonce <= 2**24 - 1) return _addressFromLast20Bytes(keccak256(abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce))));
    // forgefmt: disable-end

    // More details about RLP encoding can be found here: https://eth.wiki/fundamentals/rlp
    // 0xda = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x84 ++ nonce)
    // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex)
    // 0x84 = 0x80 + 0x04 (0x04 = the bytes length of the nonce, 4 bytes, in hex)
    // We assume nobody can have a nonce large enough to require more than 32 bytes.
    return _addressFromLast20Bytes(
      keccak256(abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), uint32(nonce)))
    );
  }
}
