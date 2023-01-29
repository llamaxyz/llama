// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {IVertexFactory} from "src/factory/IVertexFactory.sol";
import {Strategy} from "src/utils/Structs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory is Ownable, IVertexFactory {
    /// @notice The current number of vertex systems created.
    uint256 public vertexCount;

    constructor(
        string memory name,
        string memory policySymbol,
        Strategy[] memory initialStrategies,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions
    ) {
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

        bytes32 salt = bytes32(keccak256(abi.encode(name, policySymbol)));
        vertex = VertexCore(new VertexCore{salt: salt}(name, policySymbol, initialStrategies, initialPolicyholders, initialPermissions));

        emit VertexCreated(previousVertexCount, name);
    }
}
