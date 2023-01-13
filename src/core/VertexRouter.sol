// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Governor, IGovernor} from "@openzeppelin/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes, IVotes} from "@openzeppelin/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/governance/extensions/GovernorVotesQuorumFraction.sol";
import {VertexExecutor} from "src/core/VertexExecutor.sol";
import {VertexExecutorControl} from "src/core/VertexExecutorControl.sol";

contract VertexRouter is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, VertexExecutorControl {
    constructor(
        IVotes _token,
        VertexExecutor _timelock
    ) Governor("ProtocolXYZ") GovernorSettings(0, 50400, 1) GovernorVotes(_token) GovernorVotesQuorumFraction(2) VertexExecutorControl(_timelock) {} // solhint-disable-line no-empty-blocks

    function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber) public view override(IGovernor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId) public view override(Governor, VertexExecutorControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, VertexExecutorControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, VertexExecutorControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, VertexExecutorControl) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId) public view override(Governor, VertexExecutorControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
