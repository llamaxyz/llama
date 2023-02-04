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

    /// @notice The VertexCore implementation contract.
    VertexCore public immutable vertexCore;

    /// @notice The initially deployed Vertex system.
    VertexCore public immutable initialVertex;

    /// @notice The current number of vertex systems created.
    uint256 public vertexCount;

    constructor(
        VertexCore _vertexCore,
        string memory name,
        string memory symbol,
        Strategy[] memory initialStrategies,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions
    ) {
        vertexCore = _vertexCore;

        unchecked {
            ++vertexCount;
        }

        bytes32 salt = bytes32(keccak256(abi.encode(name, symbol)));
        VertexPolicyNFT policy = VertexPolicyNFT(new VertexPolicyNFT{salt: salt}(name, symbol, address(this), initialPolicyholders, initialPermissions));

        initialVertex = VertexCore(Clones.clone(address(vertexCore)));
        initialVertex.initialize(name, policy, initialStrategies);

        policy.setVertex(address(initialVertex));

        emit VertexCreated(0, name);
    }

    modifier onlyInitialVertex() {
        if (msg.sender != address(initialVertex)) revert OnlyVertex();
        _;
    }

    function deploy(
        string memory name,
        string memory symbol,
        Strategy[] memory initialStrategies,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions
    ) public onlyInitialVertex returns (VertexCore) {
        uint256 previousVertexCount = vertexCount;
        unchecked {
            ++vertexCount;
        }

        bytes32 salt = bytes32(keccak256(abi.encode(name, symbol)));
        VertexPolicyNFT policy = VertexPolicyNFT(new VertexPolicyNFT{salt: salt}(name, symbol, address(this), initialPolicyholders, initialPermissions));

        VertexCore vertex = VertexCore(Clones.clone(address(vertexCore)));
        vertex.initialize(name, policy, initialStrategies);

        policy.setVertex(address(vertex));
        emit VertexCreated(previousVertexCount, name);

        return vertex;
    }
}
