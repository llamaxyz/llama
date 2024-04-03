// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaActionGuardMinimalProxy} from "src/interfaces/ILlamaActionGuardMinimalProxy.sol";

/// @title LlamaActionGuardFactory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This contract enables Llama instances to deploy action guards.
contract LlamaActionGuardFactory {
  /// @dev Configuration of new Llama action guard.
  struct LlamaActionGuardConfig {
    string name; // The name of the new action guard.
    address llamaExecutor; // The address of the Llama executor.
    uint256 nonce; // The nonce of the new action guard.
    ILlamaActionGuardMinimalProxy actionGuardLogic; // The logic contract of the new action guard.
    bytes initializationData; // The initialization data for the new action guard.
  }

  /// @dev Emitted when a new Llama action guard is created.
  event LlamaActionGuardCreated(
    address indexed deployer,
    string name,
    address indexed llamaExecutor,
    uint256 nonce,
    ILlamaActionGuardMinimalProxy actionGuard,
    ILlamaActionGuardMinimalProxy indexed actionGuardLogic,
    bytes initializationData
  );

  /// @notice Deploys a new Llama action guard.
  /// @param actionGuardConfig The configuration of the new Llama action guard.
  /// @return actionGuard The address of the new action guard.
  function deploy(LlamaActionGuardConfig memory actionGuardConfig)
    external
    returns (ILlamaActionGuardMinimalProxy actionGuard)
  {
    bytes32 salt = keccak256(
      abi.encodePacked(msg.sender, actionGuardConfig.name, actionGuardConfig.llamaExecutor, actionGuardConfig.nonce)
    );

    // Deploy and initialize Llama action guard
    actionGuard =
      ILlamaActionGuardMinimalProxy(Clones.cloneDeterministic(address(actionGuardConfig.actionGuardLogic), salt));
    actionGuard.initialize(
      actionGuardConfig.name, actionGuardConfig.llamaExecutor, actionGuardConfig.initializationData
    );

    emit LlamaActionGuardCreated(
      msg.sender,
      actionGuardConfig.name,
      actionGuardConfig.llamaExecutor,
      actionGuardConfig.nonce,
      actionGuard,
      actionGuardConfig.actionGuardLogic,
      actionGuardConfig.initializationData
    );
  }
}
