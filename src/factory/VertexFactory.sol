// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {IVertexFactory} from "src/factory/IVertexFactory.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Strategy} from "src/utils/Structs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory is IVertexFactory {
    error OnlyVertex();

    /// @notice The VertexCore implementation (logic) contract.
    VertexCore public immutable vertexCoreLogic;

    /// @notice The initially deployed Vertex system.
    VertexCore public immutable initialVertex;

    /// @notice The current number of vertex systems created.
    uint256 public vertexCount;

    constructor(
        VertexCore _vertexCoreLogic,
        string memory name,
        string memory symbol,
        Strategy[] memory initialStrategies,
        string[] memory initialAccounts,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions,
        uint256[][] memory initialExpirationTimestamps
    ) {
        vertexCoreLogic = _vertexCoreLogic;
        initialVertex = _deploy(name, symbol, initialStrategies, initialAccounts, initialPolicyholders, initialPermissions, initialExpirationTimestamps);
    }

    modifier onlyInitialVertex() {
        if (msg.sender != address(initialVertex)) revert OnlyVertex();
        _;
    }

    function deploy(
        string memory name,
        string memory symbol,
        Strategy[] memory initialStrategies,
        string[] memory initialAccounts,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions,
        uint256[][] memory initialExpirationTimestamps
    ) public onlyInitialVertex returns (VertexCore) {
        return _deploy(name, symbol, initialStrategies, initialAccounts, initialPolicyholders, initialPermissions, initialExpirationTimestamps);
    }

    function _deploy(
        string memory name,
        string memory symbol,
        Strategy[] memory initialStrategies,
        string[] memory initialAccounts,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions,
        uint256[][] memory initialExpirationTimestamps
    ) internal returns (VertexCore vertex) {
        bytes32 salt = bytes32(keccak256(abi.encode(name, symbol)));
        VertexPolicyNFT policy = new VertexPolicyNFT{salt: salt}(name, symbol, initialPolicyholders, initialPermissions, initialExpirationTimestamps);

        vertex = VertexCore(Clones.clone(address(vertexCoreLogic)));
        vertex.initialize(name, policy, initialStrategies, initialAccounts);

        policy.setVertex(address(vertex));
        unchecked {
            emit VertexCreated(vertexCount++, name, address(vertex), address(policy));
        }
    }
}
