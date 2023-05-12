// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {PermissionData} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Llama Lens
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Utility contract to compute Llama contract addresses.
contract LlamaLens {
  /// @notice Hashes a permission.
  /// @param permission the permission to hash.
  /// @return the hash of the permission.
  function computePermissionId(PermissionData calldata permission) external pure returns (bytes32) {
    return keccak256(abi.encode(permission));
  }

  /// @notice Computes the address of a llama core with a name value.
  /// @param name The name of this llama instance.
  /// @param llamaCoreLogic The LlamaCore logic contract.
  /// @param factory The factory address.
  /// @return the computed address of the LlamaCore contract.
  function computeLlamaCoreAddress(string memory name, address llamaCoreLogic, address factory)
    external
    pure
    returns (LlamaCore)
  {
    return _computeLlamaCoreAddress(name, llamaCoreLogic, factory);
  }

  /// @notice Computes the address of a llama executor from its core address.
  /// @param llamaCore The address of the LlamaCore contract.
  /// @return the computed address of the LlamaExecutor contract.
  function computeLlamaExecutorAddress(address llamaCore) external pure returns (LlamaExecutor) {
    return LlamaExecutor(_computeCreateAddress(llamaCore, 0));
  }

  /// @notice Computes the address of a llama executor from its core configuration.
  /// @param name The name of this llama instance.
  /// @param llamaCoreLogic The LlamaCore logic contract.
  /// @param factory The factory address.
  /// @return the computed address of the LlamaExecutor contract.
  function computeLlamaExecutorAddress(string memory name, address llamaCoreLogic, address factory)
    external
    pure
    returns (LlamaExecutor)
  {
    LlamaCore llamaCore = _computeLlamaCoreAddress(name, llamaCoreLogic, factory);
    return LlamaExecutor(_computeCreateAddress(address(llamaCore), 0));
  }

  /// @notice Computes the address of a llama policy with a name value.
  /// @param name The name of this llama instance.
  /// @param llamaPolicyLogic The LlamaPolicy logic contract.
  /// @param factory The factory address.
  /// @return the computed address of the LlamaPolicy contract.
  function computeLlamaPolicyAddress(string memory name, address llamaPolicyLogic, address factory)
    external
    pure
    returns (LlamaPolicy)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      llamaPolicyLogic,
      keccak256(abi.encodePacked(name)), // salt
      factory // deployer
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
  /// @param llamaAccountLogic The Llama Account logic contract.
  /// @param account The account to be set.
  /// @param llamaCore The llama core to be set.
  /// @return the computed address of the LlamaAccount contract.
  function computeLlamaAccountAddress(address llamaAccountLogic, string calldata account, address llamaCore)
    external
    pure
    returns (LlamaAccount)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      llamaAccountLogic,
      keccak256(abi.encodePacked(account)), // salt
      llamaCore // deployer
    );
    return LlamaAccount(payable(_computedAddress));
  }

  function _computeLlamaCoreAddress(string memory name, address llamaCoreLogic, address factory)
    internal
    pure
    returns (LlamaCore)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      llamaCoreLogic,
      keccak256(abi.encodePacked(name)), // salt
      factory // deployer
    );
    return LlamaCore(_computedAddress);
  }

  /// @notice adapted from the Forge Standard Library
  /// (https://github.com/foundry-rs/forge-std)
  function _addressFromLast20Bytes(bytes32 bytesValue) private pure returns (address) {
    return address(uint160(uint256(bytesValue)));
  }

  /// @dev Compute the address a contract will be deployed at for a given deployer address and nonce
  /// @notice adapted from the Forge Standard Library
  /// (https://github.com/foundry-rs/forge-std)
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
