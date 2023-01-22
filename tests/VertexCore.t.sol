// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {ProtocolXYZ} from "src/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {ActionWithoutApprovals, Strategy, WeightByPermission} from "src/utils/Structs.sol";

contract VertexCoreTest is Test {
    VertexCore public vertex;
    VertexStrategy public strategy;
    ProtocolXYZ public protocol;
    VertexPolicyNFT public policy;
    address public constant actionCreator = address(0x1337);
    address public constant policyHolder1 = address(0x1338);
    address public constant policyHolder2 = address(0x1339);
    address public constant policyHolder3 = address(0x1340);
    address public constant policyHolder4 = address(0x1341);

    event ActionCreated(uint256 id, address indexed creator, VertexStrategy indexed strategy, address target, uint256 value, string signature, bytes data);

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

        // Use create2 to get policy's address
        bytes32 policySalt = bytes32(keccak256(abi.encode("ProtocolXYZ", "VXP")));
        bytes memory policyBytecode = type(VertexPolicyNFT).creationCode;
        bytes32 policyHash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(vertex),
                policySalt,
                keccak256(abi.encodePacked(policyBytecode, abi.encode("ProtocolXYZ", "VXP", IVertexCore(address(vertex)))))
            )
        );
        policy = VertexPolicyNFT(address(uint160(uint256(policyHash))));
        console2.log(address(policy));

        vm.startPrank(address(vertex));
        bytes32[] memory roles = new bytes32[](0);
        policy.mint(actionCreator, roles);
        policy.mint(policyHolder1, roles);
        policy.mint(policyHolder2, roles);
        policy.mint(policyHolder3, roles);
        policy.mint(policyHolder4, roles);
        vm.stopPrank();

        vm.label(actionCreator, "Action Creator");
    }

    function test_HappyActionFlow() public {
        vm.startPrank(actionCreator);

        vm.expectEmit(true, true, true, true);
        emit ActionCreated(0, actionCreator, strategy, address(protocol), 0, "function pause()", abi.encode(true));
        vertex.createAction(strategy, address(protocol), 0, "function pause()", abi.encode(true));

        ActionWithoutApprovals memory action = vertex.getActionWithoutApprovals(0);
        IVertexCore.ActionState state = vertex.getActionState(0);

        assertEq(vertex.actionsCount(), 1);
        assertEq(action.createdBlockNumber, block.number);
        assertEq(action.approvalEndTime, block.timestamp + 2 days);
        assertEq(action.approvalPolicySupply, 5);
        assertEq(action.disapprovalPolicySupply, 5);
    }
}
