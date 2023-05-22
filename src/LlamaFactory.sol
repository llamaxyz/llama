// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaPolicyMetadata} from "src/LlamaPolicyMetadata.sol";
import {LlamaPolicyMetadataParamRegistry} from "src/LlamaPolicyMetadataParamRegistry.sol";

/// @title Llama Factory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Factory for deploying new Llama instances.
contract LlamaFactory {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  /// @notice The initial set of role holders has to have at least one role holder with role ID 1.
  error InvalidDeployConfiguration();

  /// @notice A protected external function in the factory can only be called by the root instance's `LlamaExecutor`.
  error OnlyRootLlama();

  /// @notice Checks that the caller is the Root Llama Executor and reverts if not.
  modifier onlyRootLlama() {
    if (msg.sender != address(ROOT_LLAMA_EXECUTOR)) revert OnlyRootLlama();
    _;
  }

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

  /// @dev Emitted when a new Strategy implementation (logic) contract is authorized to be used by Llama instances.
  event StrategyLogicAuthorized(ILlamaStrategy indexed strategyLogic);

  /// @dev Emitted when a new Llama Policy Token Metadata is set.
  event PolicyTokenMetadataSet(LlamaPolicyMetadata indexed llamaPolicyMetadata);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice At deployment, this role is given permission to call the `setRolePermission` function.
  /// However, this may change depending on how the Llama instance is configured.
  /// @dev This is done to mitigate the chances of deploying a misconfigured Llama instance that is
  /// unusable. See the documentation for more info.
  uint8 public constant BOOTSTRAP_ROLE = 1;

  /// @notice The Llama Core implementation (logic) contract.
  LlamaCore public immutable LLAMA_CORE_LOGIC;

  /// @notice The Llama Policy implementation (logic) contract.
  LlamaPolicy public immutable LLAMA_POLICY_LOGIC;

  /// @notice The Llama Account implementation (logic) contract.
  LlamaAccount public immutable LLAMA_ACCOUNT_LOGIC;

  /// @notice The Llama Policy Token Metadata Parameter Registry contract for onchain image formats.
  LlamaPolicyMetadataParamRegistry public immutable LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY;

  /// @notice The executor of the Llama instance's executor responsible for deploying new Llama instances.
  LlamaExecutor public immutable ROOT_LLAMA_EXECUTOR;

  /// @notice The core of the Llama instance responsible for deploying new Llama instances.
  LlamaCore public immutable ROOT_LLAMA_CORE;

  /// @notice Mapping of all authorized Llama Strategy implementation (logic) contracts.
  mapping(ILlamaStrategy => bool) public authorizedStrategyLogics;

  /// @notice The Llama Policy Token Metadata contract.
  LlamaPolicyMetadata public llamaPolicyMetadata;

  /// @notice The current number of Llama instances created.
  uint256 public llamaCount;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  /// @dev Constructs the Llama Factory and deploys the root Llama instance.
  constructor(
    LlamaCore llamaCoreLogic,
    ILlamaStrategy initialLlamaStrategyLogic,
    LlamaAccount llamaAccountLogic,
    LlamaPolicy llamaPolicyLogic,
    LlamaPolicyMetadata _llamaPolicyMetadata,
    string memory name,
    bytes[] memory initialStrategies,
    string[] memory initialAccountNames,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) {
    LLAMA_CORE_LOGIC = llamaCoreLogic;
    LLAMA_POLICY_LOGIC = llamaPolicyLogic;
    LLAMA_ACCOUNT_LOGIC = llamaAccountLogic;

    _setPolicyTokenMetadata(_llamaPolicyMetadata);
    _authorizeStrategyLogic(initialLlamaStrategyLogic);

    (ROOT_LLAMA_EXECUTOR, ROOT_LLAMA_CORE) = _deploy(
      name,
      initialLlamaStrategyLogic,
      initialStrategies,
      initialAccountNames,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
    );

    LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY = new LlamaPolicyMetadataParamRegistry(ROOT_LLAMA_EXECUTOR);
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Deploys a new Llama instance.
  /// @dev This function can only be called by the root Llama instance.
  /// @param name The name of this Llama instance.
  /// @param strategyLogic The ILlamaStrategy implementation (logic) contract to use for this Llama instance.
  /// @param initialStrategies The list of initial strategies.
  /// @param initialAccountNames The list of initial accounts.
  /// @param initialRoleDescriptions The list of initial role descriptions.
  /// @param initialRoleHolders The list of initial role holders, their quantities and their role expirations.
  /// @param initialRolePermissions The list of initial permissions given to roles.
  /// @return The address of the Llama Core of the newly created instances.
  function deploy(
    string memory name,
    ILlamaStrategy strategyLogic,
    bytes[] memory initialStrategies,
    string[] memory initialAccountNames,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) external onlyRootLlama returns (LlamaExecutor, LlamaCore) {
    return _deploy(
      name,
      strategyLogic,
      initialStrategies,
      initialAccountNames,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
    );
  }

  /// @notice Authorizes a strategy implementation (logic) contract.
  /// @dev This function can only be called by the root Llama instance.
  /// @param strategyLogic The strategy logic contract to authorize.
  function authorizeStrategyLogic(ILlamaStrategy strategyLogic) external onlyRootLlama {
    _authorizeStrategyLogic(strategyLogic);
  }

  /// @notice Sets the Llama Policy Token Metadata contract.
  /// @dev This function can only be called by the root Llama instance.
  /// @param _llamaPolicyMetadata The Llama Policy Token Metadata contract.
  function setPolicyTokenMetadata(LlamaPolicyMetadata _llamaPolicyMetadata) external onlyRootLlama {
    _setPolicyTokenMetadata(_llamaPolicyMetadata);
  }

  /// @notice Returns the token URI for a given Llama policyholder.
  /// @param llamaExecutor The instance's LlamaExecutor.
  /// @param name The name of the Llama system.
  /// @param tokenId The token ID of the Llama policyholder.
  /// @return The token URI for the given Llama policyholder.
  function tokenURI(LlamaExecutor llamaExecutor, string memory name, uint256 tokenId)
    external
    view
    returns (string memory)
  {
    (string memory color, string memory logo) = LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY.getMetadata(llamaExecutor);
    return llamaPolicyMetadata.tokenURI(name, tokenId, color, logo);
  }

  /// @notice Returns the token URI for a given Llama policyholder.
  /// @param name The name of the Llama system.
  /// @return The contract URI for the given Llama instance.
  function contractURI(string memory name) external view returns (string memory) {
    return llamaPolicyMetadata.contractURI(name);
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Deploys a new Llama instance.
  function _deploy(
    string memory name,
    ILlamaStrategy strategyLogic,
    bytes[] memory initialStrategies,
    string[] memory initialAccountNames,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) internal returns (LlamaExecutor llamaExecutor, LlamaCore llamaCore) {
    // There must be at least one role holder with role ID of 1, since that role ID is initially
    // given permission to call `setRolePermission`. This is required to reduce the chance that an
    // instance is deployed with an invalid configuration that results in the instance being unusable.
    // Role ID 1 is referred to as the bootstrap role. We require that the bootstrap role is the
    // first role in the `initialRoleHolders` array, and that it never expires.
    if (initialRoleHolders.length == 0) revert InvalidDeployConfiguration();
    if (initialRoleHolders[0].role != BOOTSTRAP_ROLE) revert InvalidDeployConfiguration();
    if (initialRoleHolders[0].expiration != type(uint64).max) revert InvalidDeployConfiguration();

    // Now the configuration is likely valid (it's possible the configuration of the first strategy
    // will not actually be able to execute, but we leave that check off-chain / to the deploy
    // scripts), so we continue with deployment of this instance.
    LlamaPolicy policy =
      LlamaPolicy(Clones.cloneDeterministic(address(LLAMA_POLICY_LOGIC), keccak256(abi.encodePacked(name))));
    policy.initialize(name, initialRoleDescriptions, initialRoleHolders, initialRolePermissions);

    llamaCore = LlamaCore(Clones.cloneDeterministic(address(LLAMA_CORE_LOGIC), keccak256(abi.encodePacked(name))));
    bytes32 bootstrapPermissionId =
      llamaCore.initialize(name, policy, strategyLogic, LLAMA_ACCOUNT_LOGIC, initialStrategies, initialAccountNames);
    llamaExecutor = llamaCore.executor();

    policy.finalizeInitialization(address(llamaExecutor), bootstrapPermissionId);

    emit LlamaInstanceCreated(
      llamaCount, name, address(llamaCore), address(llamaExecutor), address(policy), block.chainid
    );
    llamaCount = LlamaUtils.uncheckedIncrement(llamaCount);
  }

  /// @dev Authorizes a strategy implementation (logic) contract.
  function _authorizeStrategyLogic(ILlamaStrategy strategyLogic) internal {
    authorizedStrategyLogics[strategyLogic] = true;
    emit StrategyLogicAuthorized(strategyLogic);
  }

  /// @dev Sets the Llama Policy Token Metadata contract.
  function _setPolicyTokenMetadata(LlamaPolicyMetadata _llamaPolicyMetadata) internal {
    llamaPolicyMetadata = _llamaPolicyMetadata;
    emit PolicyTokenMetadataSet(_llamaPolicyMetadata);
  }
}
