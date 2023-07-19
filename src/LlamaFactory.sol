// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaPolicyMetadata} from "src/interfaces/ILlamaPolicyMetadata.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {LlamaCoreInitializationConfig, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Llama Factory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Factory for deploying new Llama instances.
contract LlamaFactory {
  // ========================
  // ======== Errors ========
  // ========================

  /// @dev The initial set of role holders has to have at least one role holder with role ID 1.
  error InvalidDeployConfiguration();

  // ========================
  // ======== Events ========
  // ========================

  /// @dev Emitted when a new Llama instance is created.
  event LlamaInstanceCreated(
    uint256 indexed id,
    string indexed name,
    address llamaCore,
    address llamaExecutor,
    address llamaPolicy,
    uint256 chainId
  );

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice At deployment, this role is given permission to call the `setRolePermission` function.
  /// However, this may change depending on how the Llama instance is configured.
  /// @dev This is done to mitigate the chances of deploying a misconfigured Llama instance that is
  /// unusable. See the documentation for more info.
  uint8 public constant BOOTSTRAP_ROLE = 1;

  /// @notice The Llama core implementation (logic) contract.
  LlamaCore public immutable LLAMA_CORE_LOGIC;

  /// @notice The Llama policy implementation (logic) contract.
  LlamaPolicy public immutable LLAMA_POLICY_LOGIC;

  /// @notice The Llama policy implementation (logic) contract.
  ILlamaPolicyMetadata public immutable LLAMA_POLICY_METADATA_LOGIC;

  /// @notice The current number of Llama instances created.
  uint256 public llamaCount;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  /// @dev Constructs the Llama Factory.
  constructor(LlamaCore llamaCoreLogic, LlamaPolicy llamaPolicyLogic, ILlamaPolicyMetadata llamaPolicyMetadataLogic) {
    LLAMA_CORE_LOGIC = llamaCoreLogic;
    LLAMA_POLICY_LOGIC = llamaPolicyLogic;
    LLAMA_POLICY_METADATA_LOGIC = llamaPolicyMetadataLogic;
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Deploys a new Llama instance.
  /// @dev This function can only be called by the root Llama instance.
  /// @param name The name of this Llama instance.
  /// @param strategyLogic The strategy implementation (logic) contract to use for this Llama instance.
  /// @param accountLogic The account implementation (logic) contract to use for this Llama instance.
  /// @param initialStrategies Array of initial strategy configurations.
  /// @param initialAccounts Array of initial account configurations.
  /// @param initialRoleDescriptions Array of initial role descriptions.
  /// @param initialRoleHolders Array of initial role holders, their quantities and their role expirations.
  /// @param initialRolePermissions Array of initial permissions given to roles.
  /// @param color The background color as any valid SVG color (e.g. #00FF00) for the deployed Llama instance's NFT.
  /// @param logo The SVG string representing the logo for the deployed Llama instance's NFT.
  /// @return core The address of the `LlamaCore` of the newly created instance.
  function deploy(
    string memory name,
    ILlamaStrategy strategyLogic,
    ILlamaAccount accountLogic,
    bytes[] memory initialStrategies,
    bytes[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions,
    string memory color,
    string memory logo
  ) external returns (LlamaCore core) {
    // There must be at least one role holder with role ID of 1, since that role ID is initially
    // given permission to call `setRolePermission`. This is required to reduce the chance that an
    // instance is deployed with an invalid configuration that results in the instance being unusable.
    // Role ID 1 is referred to as the bootstrap role. We require that the bootstrap role is the
    // first role in the `initialRoleHolders` array, and that it never expires.
    if (initialRoleHolders.length == 0) revert InvalidDeployConfiguration();
    if (initialRoleHolders[0].role != BOOTSTRAP_ROLE) revert InvalidDeployConfiguration();
    if (initialRoleHolders[0].expiration != type(uint64).max) revert InvalidDeployConfiguration();

    // Deploy and initialize `LlamaCore`.
    core =
      LlamaCore(Clones.cloneDeterministic(address(LLAMA_CORE_LOGIC), keccak256(abi.encodePacked(name, msg.sender))));
    LlamaCoreInitializationConfig memory coreConfig = LlamaCoreInitializationConfig(
      name,
      LLAMA_POLICY_LOGIC,
      strategyLogic,
      accountLogic,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions,
      LLAMA_POLICY_METADATA_LOGIC,
      color,
      logo,
      msg.sender
    );
    core.initialize(coreConfig);

    LlamaExecutor executor = core.executor();
    LlamaPolicy policy = core.policy();
    emit LlamaInstanceCreated(llamaCount, name, address(core), address(executor), address(policy), block.chainid);

    llamaCount = LlamaUtils.uncheckedIncrement(llamaCount);
  }
}
