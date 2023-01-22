// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {ProtocolXYZ} from "src/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {Strategy, WeightByPermission} from "src/utils/Structs.sol";

contract VertexCoreTest is Test {
    VertexCore public vertex;
    VertexStrategy public strategy;
    ProtocolXYZ public protocol;
    address public constant actionCreator = address(0x1337);

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
        protocol = new ProtocolXYZ(address(vertex));

        // Use create2 to get strategy's address
        bytes32 strategySalt = bytes32(keccak256(abi.encode(initialStrategies[0])));
        bytes memory bytecode = type(VertexStrategy).creationCode;
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(vertex),
                strategySalt,
                keccak256(abi.encodePacked(bytecode, abi.encode(initialStrategies[0], vertex.policy(), address(vertex))))
            )
        );
        strategy = VertexStrategy(address(uint160(uint256(hash))));

        vm.label(actionCreator, "Action Creator");
    }

    function test_HappyActionFlow() public {
        vm.startPrank(actionCreator);
        vertex.createAction(strategy, address(protocol), 0, "function pause()", abi.encode(true));
        assertEq(vertex.actionsCount(), 1);
    }
}
