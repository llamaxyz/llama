// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {ActionInfo} from "src/lib/Structs.sol";

/// @title Llama Account Execute Guard
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A guard that only allows authorized targets to be called from a Llama Account.
/// @dev This guard should be used to protect the `execute` function in the `LlamaAccount` contract
contract LlamaAccountExecuteGuard is ILlamaActionGuard, Initializable {
  // =========================
  // ======== Structs ========
  // =========================

  /// @dev Llama account execute guard initialization configuration.
  struct Config {
    address executor; // The address of the `LlamaExecutor` contract.
    AuthorizedTargetConfig[] authorizedTargets; // The authorized targets and their call type.
  }

  /// @dev Authorized target configuration.
  struct AuthorizedTargetConfig {
    address target; // The target contract.
    bool withDelegatecall; // Call type.
    bool isAuthorized; // Is the target authorized.
  }

  // =========================
  // ======== Errors  ========
  // =========================

  /// @dev Only callable by a Llama instance's executor.
  error OnlyLlama();

  /// @dev Thrown if the target with call type is not authorized.
  error UnauthorizedTarget(address target, bool withDelegatecall);

  // =========================
  // ======== Events  ========
  // =========================

  /// @notice Emitted when a target with call type is authorized.
  event TargetAuthorized(address indexed target, bool indexed withDelegatecall, bool isAuthorized);

  // ===================================
  // ======== Storage Variables ========
  // ===================================

  /// @notice The Llama instance's executor.
  address public llamaExecutor;

  /// @notice A mapping of authorized targets and their call type.
  mapping(address target => mapping(bool withDelegatecall => bool isAuthorized)) public authorizedTargets;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  /// @dev This contract is deployed as a minimal proxy from the guard factory's `deploy` function. The
  /// `_disableInitializers` locks the implementation (logic) contract, preventing any future initialization of it.
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes a new `LlamaAccountExecuteGuard` clone.
  /// @dev This function is called by the `deploy` function in the `LlamaGuardFactory` contract. The `initializer`
  /// modifier ensures that this function can be invoked at most once.
  /// @param config The guard configuration, encoded as bytes to support differing constructor arguments in
  /// different guard logic contracts.
  function initialize(bytes memory config) external initializer {
    Config memory guardConfig = abi.decode(config, (Config));
    llamaExecutor = guardConfig.executor;
    _setAuthorizedTargets(guardConfig.authorizedTargets);
  }

  // ================================
  // ======== External Logic ========
  // ================================

  /// @inheritdoc ILlamaActionGuard
  function validateActionCreation(ActionInfo calldata actionInfo) external view {}

  /// @notice Allows the llama executor to set the authorized targets and their call type.
  /// @param data The data to set the authorized targets and their call type.
  function setAuthorizedTargets(AuthorizedTargetConfig[] memory data) external {
    if (msg.sender != llamaExecutor) revert OnlyLlama();
    _setAuthorizedTargets(data);
  }

  /// @inheritdoc ILlamaActionGuard
  function validatePreActionExecution(ActionInfo calldata actionInfo) external pure {}

  /// @inheritdoc ILlamaActionGuard
  function validatePostActionExecution(ActionInfo calldata actionInfo) external pure {}

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Sets the authorized targets and their call type.
  function _setAuthorizedTargets(AuthorizedTargetConfig[] memory data) internal {
    uint256 length = data.length;
    for (uint256 i = 0; i < length; LlamaUtils.uncheckedIncrement(i)) {
      authorizedTargets[data[i].target][data[i].withDelegatecall] = data[i].isAuthorized;
      emit TargetAuthorized(data[i].target, data[i].withDelegatecall, data[i].isAuthorized);
    }
  }
}
