// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {ProtocolXYZ} from "src/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Action, Strategy, Permission, WeightByPermission} from "src/utils/Structs.sol";

contract VertexCoreTest is Test {
    // Vertex system
    VertexCore public vertex;
    VertexStrategy public strategy;
    VertexStrategy public strategy2;
    VertexPolicyNFT public policy;

    // Mock protocol
    ProtocolXYZ public protocol;
    bytes4 public constant pauseSelector = 0x02329a29;

    // Testing agents
    address public constant actionCreator = address(0x1337);
    address public constant policyholder1 = address(0x1338);
    address public constant policyholder2 = address(0x1339);
    address public constant policyholder3 = address(0x1340);
    address public constant policyholder4 = address(0x1341);

    // Vertex parameters
    Permission public permission;
    string[] public roles;
    Permission[] public permissions;
    Permission[][] public permissionsArray;
    bytes8[] public permissionSignature;
    bytes8[][] public permissionSignatures;
    bytes32[] public roleHashes;

    // Strategy config
    uint256 public constant approvalPeriod = 14400; // 2 days in blocks
    uint256 public constant queuingDuration = 4 days;
    uint256 public constant expirationDelay = 8 days;
    bool public constant isFixedLengthApprovalPeriod = true;
    uint256 public constant minApprovalPct = 40_00;
    uint256 public constant minDisapprovalPct = 20_00;

    // Events
    event ActionCreated(uint256 id, address indexed creator, VertexStrategy indexed strategy, address target, uint256 value, bytes4 selector, bytes data);
    event PolicyholderApproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
    event ActionQueued(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime);
    event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);
    event PolicyholderDisapproved(uint256 id, address indexed policyholder, bool support, uint256 weight);

    function hashRole(string memory role) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(role));
    }

    function setUp() public {
        // Setup strategy parameters
        WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](0);
        WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](0);
        Strategy[] memory initialStrategies = new Strategy[](2);
        initialStrategies[0] = Strategy({
            approvalPeriod: approvalPeriod,
            queuingDuration: queuingDuration,
            expirationDelay: expirationDelay,
            isFixedLengthApprovalPeriod: isFixedLengthApprovalPeriod,
            minApprovalPct: minApprovalPct,
            minDisapprovalPct: minDisapprovalPct,
            approvalWeightByPermission: approvalWeightByPermission,
            disapprovalWeightByPermission: disapprovalWeightByPermission
        });

        initialStrategies[1] = Strategy({
            approvalPeriod: approvalPeriod,
            queuingDuration: 0,
            expirationDelay: 1 days,
            isFixedLengthApprovalPeriod: false,
            minApprovalPct: 80_00,
            minDisapprovalPct: 10001,
            approvalWeightByPermission: approvalWeightByPermission,
            disapprovalWeightByPermission: disapprovalWeightByPermission
        });

        // Deploy vertex and mock protocol
        vertex = new VertexCore("ProtocolXYZ", "VXP", initialStrategies);
        protocol = new ProtocolXYZ(address(vertex));

        // Use create2 to get vertex strategy's address
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

        // Use create2 to get vertex strategy 2's address
        bytes32 strategy2Salt = bytes32(keccak256(abi.encode(initialStrategies[1])));
        bytes memory bytecode2 = type(VertexStrategy).creationCode;
        bytes32 hash2 = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(vertex),
                strategy2Salt,
                keccak256(abi.encodePacked(bytecode2, abi.encode(initialStrategies[1], vertex.policy(), address(vertex))))
            )
        );
        strategy2 = VertexStrategy(address(uint160(uint256(hash2))));

        // Use create2 to get vertex policy's address
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

        // Assign permissions to policyholders
        vm.startPrank(address(vertex));
        permission = Permission({target: address(protocol), selector: pauseSelector, strategy: strategy});
        permissions.push(permission);
        permissionsArray.push(permissions);
        permissionSignature.push(policy.hashPermission(permission));
        permissionSignatures.push(permissionSignature);
        roles.push("admin");
        roleHashes.push(hashRole(roles[0]));
        policy.addRoles(roles, permissionsArray);
        bytes32[] memory _roles = new bytes32[](0);
        policy.mint(actionCreator, _roles);
        policy.mint(policyholder1, _roles);
        policy.mint(policyholder2, _roles);
        policy.mint(policyholder3, _roles);
        policy.mint(policyholder4, _roles);
        policy.assignRoles(0, roleHashes);

        vm.stopPrank();

        vm.label(actionCreator, "Action Creator");
    }

    function test_HappyActionFlow() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.stopPrank();

        vm.startPrank(policyholder1);
        _approveAction(policyholder1);
        vm.stopPrank();

        vm.startPrank(policyholder2);
        _approveAction(policyholder2);
        vm.stopPrank();

        vm.warp(block.timestamp + 6 days);
        vm.roll(block.number + 43200);

        assertEq(strategy.isActionPassed(0), true);
        _queueAction();

        vm.startPrank(policyholder1);
        _disapproveAction(policyholder1);
        vm.stopPrank();

        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + 36000);

        _executeAction();
    }

    function test_InvalidStrategy() public {
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.InvalidStrategy.selector);
        vertex.createAction(0, VertexStrategy(address(0xdead)), address(protocol), 0, pauseSelector, abi.encode(true));
    }

    function test_InvalidPolicyholder() public {
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.InvalidPolicyholder.selector);
        vertex.createAction(1, strategy, address(protocol), 0, pauseSelector, abi.encode(true));
    }

    function test_NoStrategyPermission() public {
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
        vertex.createAction(0, strategy2, address(protocol), 0, pauseSelector, abi.encode(true));
    }

    function test_NoTargetPermission() public {
        address fakeTarget = address(0xdead);
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
        vertex.createAction(0, strategy, fakeTarget, 0, pauseSelector, abi.encode(true));
    }

    function test_NoSelectorPermission() public {
        bytes4 fakeSelector = 0x02222222;
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
        vertex.createAction(0, strategy, address(protocol), 0, fakeSelector, abi.encode(true));
    }

    /*///////////////////////////////////////////////////////////////
                        Action setup helpers
    //////////////////////////////////////////////////////////////*/

    function _createAction() public {
        vm.expectEmit(true, true, true, true);
        emit ActionCreated(0, actionCreator, strategy, address(protocol), 0, pauseSelector, abi.encode(true));
        vertex.createAction(0, strategy, address(protocol), 0, pauseSelector, abi.encode(true));

        Action memory action = vertex.getAction(0);
        uint256 approvalEndTime = block.number + action.strategy.approvalPeriod();

        assertEq(vertex.actionsCount(), 1);
        assertEq(action.createdBlockNumber, block.number);
        assertEq(approvalEndTime, block.number + 14400);
        assertEq(action.approvalPolicySupply, 5);
        assertEq(action.disapprovalPolicySupply, 5);
    }

    function _approveAction(address policyholder) public {
        vm.expectEmit(true, true, true, true);
        emit PolicyholderApproved(0, policyholder, true, 1);
        vertex.submitApproval(0, true);
    }

    function _disapproveAction(address policyholder) public {
        vm.expectEmit(true, true, true, true);
        emit PolicyholderDisapproved(0, policyholder, true, 1);
        vertex.submitDisapproval(0, true);
    }

    function _queueAction() public {
        uint256 executionTime = block.timestamp + strategy.queuingDuration();
        vm.expectEmit(true, true, true, true);
        emit ActionQueued(0, address(this), strategy, actionCreator, executionTime);
        vertex.queueAction(0);
    }

    function _executeAction() public {
        vm.expectEmit(true, true, true, true);
        emit ActionExecuted(0, address(this), strategy, actionCreator);
        vertex.executeAction(0);

        Action memory action = vertex.getAction(0);
        assertEq(action.executed, true);
    }
}
