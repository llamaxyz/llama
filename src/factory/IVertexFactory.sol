// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {VertexCore} from "src/core/VertexCore.sol";
import {Strategy} from "src/utils/Structs.sol";

interface IVertexFactory {
    event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT);

    /// @notice Deploys a new Vertex system. This function can only be called by the initial Vertex system.
    /// @param name The name of this Vertex system.
    /// @param policySymbol The token symbol for the policy NFT.
    /// @param initialStrategies The list of initial strategies.
    /// @param initialAccounts The list of initial accounts.
    /// @param initialPolicyholders The list of initial policyholders.
    /// @param initialPermissions The list of permissions granted to each initial policyholder.
    /// @return the address of the VertexCore contract of the newly created system.
    function deploy(
        string memory name,
        string memory policySymbol,
        Strategy[] memory initialStrategies,
        string[] memory initialAccounts,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions,
        uint256[][] memory initialExpirationTimestamps
    ) external returns (VertexCore);
}
