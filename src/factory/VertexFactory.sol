// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {VertexAccount} from "src/account/VertexAccount.sol";
import {IVertexFactory} from "src/factory/IVertexFactory.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Strategy} from "src/utils/Structs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory is IVertexFactory {
    error OnlyVertex();

    /// @notice The VertexCore implementation contract.
    VertexCore public immutable vertexCoreImplementation;

    /// @notice The Vertex Account implementation contract.
    VertexAccount public immutable vertexAccountImplementation;

    /// @notice The initially deployed Vertex system.
    VertexCore public immutable initialVertex;

    /// @notice The current number of vertex systems created.
    uint256 public vertexCount;

    constructor(
        VertexCore _vertexCoreImplementation,
        VertexAccount _vertexAccountImplementation,
        string memory name,
        string memory symbol,
        Strategy[] memory initialStrategies,
        string[] memory initialAccounts,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions,
        uint256[][] memory initialExpirationTimestamps
    ) {
        vertexCoreImplementation = _vertexCoreImplementation;
        vertexAccountImplementation = _vertexAccountImplementation;

        unchecked {
            ++vertexCount;
        }

        bytes32 salt = bytes32(keccak256(abi.encode(name, symbol)));
        VertexPolicyNFT policy =
            VertexPolicyNFT(new VertexPolicyNFT{salt: salt}(name, symbol, initialPolicyholders, initialPermissions, initialExpirationTimestamps));

        initialVertex = VertexCore(Clones.clone(address(vertexCoreImplementation)));
        initialVertex.initialize(name, policy, vertexAccountImplementation, initialStrategies, initialAccounts);

        policy.setVertex(address(initialVertex));

        emit VertexCreated(0, name, address(initialVertex), address(policy));
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
        uint256 previousVertexCount = vertexCount;
        unchecked {
            ++vertexCount;
        }

        bytes32 salt = bytes32(keccak256(abi.encode(name, symbol)));
        VertexPolicyNFT policy =
            VertexPolicyNFT(new VertexPolicyNFT{salt: salt}(name, symbol, initialPolicyholders, initialPermissions, initialExpirationTimestamps));

        VertexCore vertex = VertexCore(Clones.clone(address(vertexCoreImplementation)));
        vertex.initialize(name, policy, vertexAccountImplementation, initialStrategies, initialAccounts);

        policy.setVertex(address(vertex));
        emit VertexCreated(previousVertexCount, name, address(vertex), address(policy));

        return vertex;
    }
}
