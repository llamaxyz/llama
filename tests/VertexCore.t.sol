// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ProtocolVotingNFT} from "src/mock/ProtocolVotingNFT.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {Strategy, WeightByPermission} from "src/utils/Structs.sol";

contract VertexCoreTest is Test {
    VertexCore public vertex;

    function setUp() public {
        WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](0);
        WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](0);
        Strategy[] memory initialStrategies = new Strategy[](1);
        initialStrategies[0] = Strategy({
            approvalDuration: 2 days,
            queuingDuration: 4 days,
            expirationDelay: 8 days,
            isFixedLengthApprovalPeriod: true,
            minApprovalPct: 40_00,
            minDisapprovalPct: 20_00,
            approvalWeightByPermission: approvalWeightByPermission,
            disapprovalWeightByPermission: disapprovalWeightByPermission
        });

        vertex = new VertexCore("ProtocolXYZ", "VXP", initialStrategies);
    }

    function testPropose() public {
        uint256 x = 1;
        assertEq(x, 1);
    }
}
