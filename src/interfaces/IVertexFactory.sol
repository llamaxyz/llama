// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {VertexCore} from "src/VertexCore.sol";
import {Strategy, PolicyGrantData} from "src/lib/Structs.sol";

interface IVertexFactory {
  error OnlyVertex();

  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT);
  event StrategyLogicAuthorized(address indexed strategyLogic);
  event StrategyLogicUnauthorized(address indexed strategyLogic);
  event AccountLogicAuthorized(address indexed accountLogic);
  event AccountLogicUnauthorized(address indexed accountLogic);

  /// @notice Deploys a new Vertex system. This function can only be called by the initial Vertex system.
  /// @param name The name of this Vertex system.
  /// @param initialStrategies The list of initial strategies.
  /// @param initialAccounts The list of initial accounts.
  /// @param initialPolicies The list of initial policies.
  /// @return the address of the VertexCore contract of the newly created system.
  function deploy(
    string memory name,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) external returns (VertexCore);

  /// @notice Authorizes a strategy logic contract.
  /// @param strategyLogic The strategy logic contract to authorize.
  function authorizeStrategyLogic(address strategyLogic) external;

  /// @notice Unauthorizes a strategy logic contract.
  /// @param strategyLogic The strategy logic contract to unauthorize.
  function unauthorizeStrategyLogic(address strategyLogic) external;

  /// @notice Authorizes an account logic contract.
  /// @param accountLogic The account logic contract to authorize.
  function authorizeAccountLogic(address accountLogic) external;

  /// @notice Unauthorizes an account logic contract.
  /// @param accountLogic The account logic contract to unauthorize.
  function unauthorizeAccountLogic(address accountLogic) external;
}
