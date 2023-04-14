// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error OnlyVertex();

  modifier onlyRootVertex() {
    if (msg.sender != address(ROOT_VERTEX)) revert OnlyVertex();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT);
  event StrategyLogicAuthorized(VertexStrategy indexed strategyLogic);
  event AccountLogicAuthorized(VertexAccount indexed accountLogic);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice The VertexCore implementation (logic) contract.
  VertexCore public immutable VERTEX_CORE_LOGIC;

  /// @notice The Vertex Policy implementation (logic) contract.
  VertexPolicy public immutable VERTEX_POLICY_LOGIC;

  /// @notice Mapping of all authorized Vertex Strategy implementation (logic) contracts.
  mapping(VertexStrategy => bool) public authorizedStrategyLogics;

  /// @notice Mapping of all authorized Vertex Account implementation (logic) contracts.
  mapping(VertexAccount => bool) public authorizedAccountLogics;

  /// @notice The Vertex instance responsible for deploying new Vertex instances.
  VertexCore public immutable ROOT_VERTEX;

  /// @notice The Vertex Policy Metadata contract.
  VertexPolicyTokenURI public vertexPolicyTokenUri;

  /// @notice The current number of vertex systems created.
  uint256 public vertexCount;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor(
    VertexCore vertexCoreLogic,
    VertexStrategy initialVertexStrategyLogic,
    VertexAccount initialVertexAccountLogic,
    VertexPolicy vertexPolicyLogic,
    VertexPolicyTokenURI _vertexPolicyTokenUri,
    string memory name,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) {
    VERTEX_CORE_LOGIC = vertexCoreLogic;
    VERTEX_POLICY_LOGIC = vertexPolicyLogic;
    vertexPolicyTokenUri = _vertexPolicyTokenUri;

    _authorizeStrategyLogic(initialVertexStrategyLogic);
    _authorizeAccountLogic(initialVertexAccountLogic);

    ROOT_VERTEX = _deploy(
      name,
      initialVertexStrategyLogic,
      initialVertexAccountLogic,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
    );
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Deploys a new Vertex system. This function can only be called by the initial Vertex system.
  /// @param name The name of this Vertex system.
  /// @param strategyLogic The VertexStrategy implementation (logic) contract to use for this Vertex system.
  /// @param accountLogic The VertexAccount implementation (logic) contract to use for this Vertex system.
  /// @param initialStrategies The list of initial strategies.
  /// @param initialAccounts The list of initial accounts.
  /// @param initialRoleDescriptions The list of initial role descriptions.
  /// @param initialRoleHolders The list of initial role holders and their role expirations.
  /// @param initialRolePermissions The list initial permissions given to roles.
  /// @return the address of the VertexCore contract of the newly created system.
  function deploy(
    string memory name,
    VertexStrategy strategyLogic,
    VertexAccount accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) external onlyRootVertex returns (VertexCore) {
    return _deploy(
      name,
      strategyLogic,
      accountLogic,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
    );
  }

  /// @notice Authorizes a strategy logic contract.
  /// @param strategyLogic The strategy logic contract to authorize.
  function authorizeStrategyLogic(VertexStrategy strategyLogic) external onlyRootVertex {
    _authorizeStrategyLogic(strategyLogic);
  }

  /// @notice Authorizes an account logic contract.
  /// @param accountLogic The account logic contract to authorize.
  function authorizeAccountLogic(VertexAccount accountLogic) external onlyRootVertex {
    _authorizeAccountLogic(accountLogic);
  }

  /// @notice Sets the Vertex Policy Metadata contract.
  /// @param _vertexPolicyTokenUri The Vertex Policy Metadata contract.
  function setPolicyMetadata(VertexPolicyTokenURI _vertexPolicyTokenUri) external onlyRootVertex {
    vertexPolicyTokenUri = _vertexPolicyTokenUri;
  }

  /// @notice Returns the token URI for a given Vertex Policy Holder.
  /// @param name The name of the Vertex system.
  /// @param symbol The symbol of the Vertex system.
  /// @param tokenId The token ID of the Vertex Policy Holder.
  function tokenURI(string memory name, string memory symbol, uint256 tokenId) external view returns (string memory) {
    string memory color = "#FF0000";
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    return vertexPolicyTokenUri.tokenURI(name, symbol, tokenId, color, logo);
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  function _deploy(
    string memory name,
    VertexStrategy strategyLogic,
    VertexAccount accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) internal returns (VertexCore vertex) {
    // Deploy the system.
    VertexPolicy policy =
      VertexPolicy(Clones.cloneDeterministic(address(VERTEX_POLICY_LOGIC), keccak256(abi.encode(name))));
    policy.initialize(name, initialRoleDescriptions, initialRoleHolders, initialRolePermissions);

    vertex = VertexCore(Clones.cloneDeterministic(address(VERTEX_CORE_LOGIC), keccak256(abi.encode(name))));
    vertex.initialize(name, policy, strategyLogic, accountLogic, initialStrategies, initialAccounts);

    policy.setVertex(address(vertex));

    unchecked {
      emit VertexCreated(vertexCount++, name, address(vertex), address(policy));
    }
  }

  function _authorizeStrategyLogic(VertexStrategy strategyLogic) internal {
    authorizedStrategyLogics[strategyLogic] = true;
    emit StrategyLogicAuthorized(strategyLogic);
  }

  function _authorizeAccountLogic(VertexAccount accountLogic) internal {
    authorizedAccountLogics[accountLogic] = true;
    emit AccountLogicAuthorized(accountLogic);
  }
}
