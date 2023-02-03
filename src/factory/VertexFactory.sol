// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {IVertexFactory} from "src/factory/IVertexFactory.sol";
import {Strategy} from "src/utils/Structs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory is Ownable, IVertexFactory {
    /// @notice The current number of vertex systems created.
    uint256 public vertexCount;

    /// @notice The vertex core implementation address.
    VertexCore public immutable vertexCore;

    constructor(
        VertexCore _vertexCore,
        string memory name,
        string memory policySymbol,
        Strategy[] memory initialStrategies,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions
    ) {
        vertexCore = _vertexCore;
        VertexCore initialVertex = deploy(name, policySymbol, initialStrategies, initialPolicyholders, initialPermissions);
        transferOwnership(address(initialVertex));
    }

    function deploy(
        string memory name,
        string memory policySymbol,
        Strategy[] memory initialStrategies,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions
    ) public onlyOwner returns (VertexCore vertex) {
        uint256 previousVertexCount = vertexCount;
        unchecked {
            ++vertexCount;
        }

        vertex = VertexCore(Clones.clone(address(vertexCore)));
        vertex.initialize(name, policySymbol, initialStrategies, initialPolicyholders, initialPermissions);

        emit VertexCreated(previousVertexCount, name);
    }
}
