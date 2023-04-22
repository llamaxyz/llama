// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {PermissionData} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
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
    address _computedAddress = Clones.predictDeterministicAddress(
      llamaCoreLogic,
      keccak256(abi.encode(name)), // salt
      factory // deployer
    );
    return LlamaCore(_computedAddress);
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
      keccak256(abi.encode(name)), // salt
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
      keccak256(abi.encode(account)), // salt
      llamaCore // deployer
    );
    return LlamaAccount(payable(_computedAddress));
  }
}
