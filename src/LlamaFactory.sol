// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
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

  /// @dev Thrown when a protected external function in the factory is not called by the Root Llama Core.
  error OnlyRootLlama();

  /// @dev Checks that the caller is the Root Llama Core and reverts if not.
  modifier onlyRootLlama() {
    if (msg.sender != address(ROOT_LLAMA)) revert OnlyRootLlama();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  /// @dev Emitted when a new Llama instance is created.
  event LlamaInstanceCreated(
    uint256 indexed id, string indexed name, address llamaCore, address llamaPolicy, uint256 chainId
  );

  /// @dev Emitted when a new Strategy implementation (logic) contract is authorized to be used by Llama instances.
  event StrategyLogicAuthorized(ILlamaStrategy indexed strategyLogic);

  /// @dev Emitted when a new Llama Policy Token URI is set.
  event PolicyTokenMetadataSet(LlamaPolicyMetadata indexed llamaPolicyMetadata);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice The Llama Core implementation (logic) contract.
  LlamaCore public immutable LLAMA_CORE_LOGIC;

  /// @notice The Llama Policy implementation (logic) contract.
  LlamaPolicy public immutable LLAMA_POLICY_LOGIC;

  /// @notice The Llama Account implementation (logic) contract.
  LlamaAccount public immutable LLAMA_ACCOUNT_LOGIC;

  /// @notice The Llama Policy Token URI Parameter Registry contract for onchain image formats.
  LlamaPolicyMetadataParamRegistry public immutable LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY;

  /// @notice The Llama instance responsible for deploying new Llama instances.
  LlamaCore public immutable ROOT_LLAMA;

  /// @notice Mapping of all authorized Llama Strategy implementation (logic) contracts.
  mapping(ILlamaStrategy => bool) public authorizedStrategyLogics;

  /// @notice The Llama Policy Token URI contract.
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
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) {
    LLAMA_CORE_LOGIC = llamaCoreLogic;
    LLAMA_POLICY_LOGIC = llamaPolicyLogic;
    LLAMA_ACCOUNT_LOGIC = llamaAccountLogic;

    _setPolicyTokenURI(_llamaPolicyMetadata);
    _authorizeStrategyLogic(initialLlamaStrategyLogic);

    ROOT_LLAMA = _deploy(
      name,
      initialLlamaStrategyLogic,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
    );

    LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY = new LlamaPolicyMetadataParamRegistry(ROOT_LLAMA);
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Deploys a new Llama instance.
  /// @dev This function can only be called by the root Llama instance.
  /// @param name The name of this Llama instance.
  /// @param strategyLogic The ILlamaStrategy implementation (logic) contract to use for this Llama instance.
  /// @param initialStrategies The list of initial strategies.
  /// @param initialAccounts The list of initial accounts.
  /// @param initialRoleDescriptions The list of initial role descriptions.
  /// @param initialRoleHolders The list of initial role holders, their quantities and their role expirations.
  /// @param initialRolePermissions The list of initial permissions given to roles.
  /// @return The address of the Llama Core of the newly created instances.
  function deploy(
    string memory name,
    ILlamaStrategy strategyLogic,
    bytes[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) external onlyRootLlama returns (LlamaCore) {
    return _deploy(
      name,
      strategyLogic,
      initialStrategies,
      initialAccounts,
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

  /// @notice Sets the Llama Policy Token URI contract.
  /// @dev This function can only be called by the root Llama instance.
  /// @param _llamaPolicyMetadata The Llama Policy Token URI contract.
  function setPolicyTokenURI(LlamaPolicyMetadata _llamaPolicyMetadata) external onlyRootLlama {
    _setPolicyTokenURI(_llamaPolicyMetadata);
  }

  /// @notice Returns the token URI for a given Llama policyholder.
  /// @param name The name of the Llama system.
  /// @param symbol The symbol of the Llama system.
  /// @param tokenId The token ID of the Llama policyholder.
  /// @return The token URI for the given Llama policyholder.
  function tokenURI(LlamaCore llamaCore, string memory name, string memory symbol, uint256 tokenId)
    external
    view
    returns (string memory)
  {
    (string memory color, string memory logo) = LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY.getMetadata(llamaCore);
    return llamaPolicyMetadata.tokenURI(name, symbol, tokenId, color, logo);
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
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) internal returns (LlamaCore llamaCore) {
    LlamaPolicy policy =
      LlamaPolicy(Clones.cloneDeterministic(address(LLAMA_POLICY_LOGIC), keccak256(abi.encodePacked(name))));
    policy.initialize(name, initialRoleDescriptions, initialRoleHolders, initialRolePermissions);

    llamaCore = LlamaCore(Clones.cloneDeterministic(address(LLAMA_CORE_LOGIC), keccak256(abi.encodePacked(name))));
    llamaCore.initialize(name, policy, strategyLogic, LLAMA_ACCOUNT_LOGIC, initialStrategies, initialAccounts);

    policy.setLlama(address(llamaCore));

    emit LlamaInstanceCreated(llamaCount, name, address(llamaCore), address(policy), block.chainid);

    unchecked {
      ++llamaCount;
    }
  }

  /// @dev Authorizes a strategy implementation (logic) contract.
  function _authorizeStrategyLogic(ILlamaStrategy strategyLogic) internal {
    authorizedStrategyLogics[strategyLogic] = true;
    emit StrategyLogicAuthorized(strategyLogic);
  }

  /// @dev Sets the Llama Policy Token URI contract.
  function _setPolicyTokenURI(LlamaPolicyMetadata _llamaPolicyMetadata) internal {
    llamaPolicyMetadata = _llamaPolicyMetadata;
    emit PolicyTokenMetadataSet(_llamaPolicyMetadata);
  }
}
