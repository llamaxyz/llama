// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexFactory} from "src/factory/VertexFactory.sol";
import {ProtocolXYZ} from "src/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {VertexAccount} from "src/account/VertexAccount.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Action, Strategy, PermissionData, WeightByPermission} from "src/utils/Structs.sol";

contract VertexCoreTest is Test {
    // Vertex system
    VertexCore public vertex;
    VertexCore public vertexCore;
    VertexFactory public vertexFactory;
    VertexStrategy[] public strategies;
    VertexAccount[] public accounts;
    VertexPolicyNFT public policy;

    // Mock protocol
    ProtocolXYZ public protocol;

    // Testing agents
    address public constant actionCreator = address(0x1337);
    address public constant policyholder1 = address(0x1338);
    address public constant policyholder2 = address(0x1339);
    address public constant policyholder3 = address(0x1340);
    address public constant policyholder4 = address(0x1341);
    bytes4 public constant pauseSelector = 0x02329a29;
    bytes4 public constant failSelector = 0xa9cc4718;

    PermissionData public permission;
    PermissionData[] public permissions;
    bytes8[] public permissionSignature;
    bytes8[][] public permissionSignatures;
    uint256[][] public expirationTimestamps;
    address[] public addresses;
    uint256[] public policyIds;

    address[] public initialPolicies;
    bytes8[][] public initialPermissions;
    // Strategy config
    uint256 public constant approvalPeriod = 14400; // 2 days in blocks
    uint256 public constant queuingDuration = 4 days;
    uint256 public constant expirationDelay = 8 days;
    bool public constant isFixedLengthApprovalPeriod = true;
    uint256 public constant minApprovalPct = 40_00;
    uint256 public constant minDisapprovalPct = 20_00;

    // Events
    event ActionCreated(uint256 id, address indexed creator, VertexStrategy indexed strategy, address target, uint256 value, bytes4 selector, bytes data);
    event ActionCanceled(uint256 id);
    event ActionQueued(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime);
    event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);
    event PolicyholderApproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
    event PolicyholderDisapproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
    event StrategyAuthorized(VertexStrategy indexed strategy, Strategy strategyData);
    event StrategyUnauthorized(VertexStrategy indexed strategy);
    event AccountAuthorized(VertexAccount indexed account, string name);

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        // Setup strategy parameters
        WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](0);
        WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](0);
        Strategy[] memory initialStrategies = new Strategy[](2);
        string[] memory initialAccounts = new string[](2);

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

        initialAccounts[0] = "VertexAccount0";
        initialAccounts[1] = "VertexAccount1";

        // Deploy vertex and mock protocol
        vertexCore = new VertexCore();
        vertexFactory =
            new VertexFactory(vertexCore, "ProtocolXYZ", "VXP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, expirationTimestamps);
        vertex = VertexCore(vertexFactory.rootVertex());
        protocol = new ProtocolXYZ(address(vertex));

        // Use create2 to get vertex strategy addresses
        for (uint256 i; i < initialStrategies.length; i++) {
            bytes32 strategySalt = bytes32(keccak256(abi.encode(initialStrategies[i])));
            bytes memory bytecode = type(VertexStrategy).creationCode;
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(vertex),
                    strategySalt,
                    keccak256(abi.encodePacked(bytecode, abi.encode(initialStrategies[i], vertex.policy(), address(vertex))))
                )
            );
            strategies.push(VertexStrategy(address(uint160(uint256(hash)))));
        }

        // Use create2 to get vertex account addresses
        for (uint256 i; i < initialAccounts.length; i++) {
            bytes32 accountSalt = bytes32(keccak256(abi.encode(initialAccounts[i])));
            bytes memory bytecode = type(VertexAccount).creationCode;
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff), address(vertex), accountSalt, keccak256(abi.encodePacked(bytecode, abi.encode(initialAccounts[i], address(vertex))))
                )
            );
            accounts.push(VertexAccount(payable(address(uint160(uint256(hash))))));
        }

        // Set vertex's policy
        policy = vertex.policy();

        // Create and assign policies
        _createPolicies();

        vm.label(actionCreator, "Action Creator");
    }

    /*///////////////////////////////////////////////////////////////
                            Setup tests
    //////////////////////////////////////////////////////////////*/

    function test_setUp() public {
        assertEq(vertex.name(), "ProtocolXYZ");

        assertTrue(vertex.authorizedStrategies(strategies[0]));
        assertTrue(vertex.authorizedStrategies(strategies[1]));
        assertEq(strategies.length, 2);

        assertTrue(vertex.authorizedAccounts(accounts[0]));
        assertTrue(vertex.authorizedAccounts(accounts[1]));
        assertEq(accounts.length, 2);
    }

    /*///////////////////////////////////////////////////////////////
                            Unit tests
    //////////////////////////////////////////////////////////////*/

    // createAction unit tests
    function test_createAction_RevertIfStrategyUnauthorized() public {
        VertexStrategy unauthorizedStrategy = VertexStrategy(address(0xdead));
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.InvalidStrategy.selector);
        vertex.createAction(unauthorizedStrategy, address(protocol), 0, pauseSelector, abi.encode(true));
    }

    function test_createAction_RevertIfPolicyholderNotMinted() public {
        vm.prank(address(0xdead));
        vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
        vertex.createAction(strategies[1], address(protocol), 0, pauseSelector, abi.encode(true));
    }

    function test_createAction_RevertIfNoPermissionForStrategy() public {
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
        vertex.createAction(strategies[1], address(protocol), 0, pauseSelector, abi.encode(true));
    }

    function test_createAction_RevertIfNoPermissionForTarget() public {
        address fakeTarget = address(0xdead);
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
        vertex.createAction(strategies[0], fakeTarget, 0, pauseSelector, abi.encode(true));
    }

    function test_createAction_RevertIfNoPermissionForSelector() public {
        bytes4 fakeSelector = 0x02222222;
        vm.prank(actionCreator);
        vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
        vertex.createAction(strategies[0], address(protocol), 0, fakeSelector, abi.encode(true));
    }

    // cancelAction unit tests
    function test_cancelAction_RevertIfNotCreator() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.stopPrank();
        vm.expectRevert(VertexCore.ActionCannotBeCanceled.selector);
        vertex.cancelAction(0);
    }

    function test_cancelAction_CreatorCancelFlow() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.expectEmit(true, true, true, true);
        emit ActionCanceled(0);
        vertex.cancelAction(0);
        vm.stopPrank();
    }

    function test_cancelAction_RevertIfInvalidActionId() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.expectRevert(VertexCore.InvalidActionId.selector);
        vertex.cancelAction(1);
        vm.stopPrank();
    }

    function test_cancelAction_RevertIfAlreadyCanceled() public {
        vm.startPrank(actionCreator);
        _createAction();
        vertex.cancelAction(0);
        vm.expectRevert(VertexCore.InvalidCancelation.selector);
        vertex.cancelAction(0);
        vm.stopPrank();
    }

    function test_cancelAction_RevertIfActionExecuted() public {
        test_VertexCore_CompleteActionFlow();

        vm.startPrank(actionCreator);
        vm.expectRevert(VertexCore.InvalidCancelation.selector);
        vertex.cancelAction(0);
        vm.stopPrank();
    }

    function test_cancelAction_RevertIfActionExpired() public {
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

        assertEq(strategies[0].isActionPassed(0), true);
        _queueAction();

        vm.startPrank(policyholder1);
        _disapproveAction(policyholder1);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);
        vm.roll(block.number + 108000);

        vm.startPrank(actionCreator);
        vm.expectRevert(VertexCore.InvalidCancelation.selector);
        vertex.cancelAction(0);
        vm.stopPrank();
    }

    function test_cancelAction_RevertIfActionFailed() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.stopPrank();

        vm.startPrank(policyholder1);
        _approveAction(policyholder1);
        vm.stopPrank();

        vm.warp(block.timestamp + 6 days);
        vm.roll(block.number + 43200);

        assertEq(strategies[0].isActionPassed(0), false);

        vm.expectRevert(VertexCore.InvalidCancelation.selector);
        vertex.cancelAction(0);
    }

    function test_cancelAction_CancelIfDisapproved() public {
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

        assertEq(strategies[0].isActionPassed(0), true);
        _queueAction();

        vm.startPrank(policyholder1);
        _disapproveAction(policyholder1);
        vm.stopPrank();

        vm.startPrank(policyholder2);
        _disapproveAction(policyholder2);
        vm.stopPrank();

        vm.startPrank(policyholder3);
        _disapproveAction(policyholder3);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit ActionCanceled(0);
        vertex.cancelAction(0);
    }

    function test_cancelAction_RevertIfDisapprovalDoesNotReachQuorum() public {
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

        assertEq(strategies[0].isActionPassed(0), true);
        _queueAction();

        vm.expectRevert(VertexCore.ActionCannotBeCanceled.selector);
        vertex.cancelAction(0);
    }

    // queueAction unit tests
    function test_queueAction_RevertIfNotApproved() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.stopPrank();

        vm.startPrank(policyholder1);
        _approveAction(policyholder1);
        vm.stopPrank();

        vm.warp(block.timestamp + 6 days);
        vm.roll(block.number + 43200);

        vm.expectRevert(VertexCore.InvalidStateForQueue.selector);
        vertex.queueAction(0);
    }

    function test_queueAction_RevertIfInvalidActionId() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.stopPrank();

        vm.startPrank(policyholder1);
        _approveAction(policyholder1);
        vm.stopPrank();

        vm.startPrank(policyholder2);
        _approveAction(policyholder2);
        vm.stopPrank();

        vm.startPrank(policyholder3);
        _approveAction(policyholder3);
        vm.stopPrank();

        vm.warp(block.timestamp + 6 days);
        vm.roll(block.number + 43200);

        vm.expectRevert(VertexCore.InvalidActionId.selector);
        vertex.queueAction(1);
    }

    // executeAction unit tests
    function test_executeAction_RevertIfNotQueued() public {
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

        assertEq(strategies[0].isActionPassed(0), true);

        vm.expectRevert(VertexCore.OnlyQueuedActions.selector);
        vertex.executeAction(0);
    }

    function test_executeAction_RevertIfInvalidActionId() public {
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

        assertEq(strategies[0].isActionPassed(0), true);

        vertex.queueAction(0);

        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + 36000);

        vm.expectRevert(VertexCore.InvalidActionId.selector);
        vertex.executeAction(1);
    }

    function test_executeAction_RevertIfTimelockNotFinished() public {
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

        assertEq(strategies[0].isActionPassed(0), true);

        vertex.queueAction(0);

        vm.warp(block.timestamp + 6 hours);
        vm.roll(block.number + 1800);

        vm.expectRevert(VertexCore.TimelockNotFinished.selector);
        vertex.executeAction(0);
    }

    function test_executeAction_RevertIfFailedActionExecution() public {
        vm.startPrank(actionCreator);
        vertex.createAction(strategies[0], address(protocol), 0, failSelector, abi.encode(""));
        vm.stopPrank();

        vm.startPrank(policyholder1);
        _approveAction(policyholder1);
        vm.stopPrank();

        vm.startPrank(policyholder2);
        _approveAction(policyholder2);
        vm.stopPrank();

        vm.warp(block.timestamp + 6 days);
        vm.roll(block.number + 43200);

        assertEq(strategies[0].isActionPassed(0), true);

        vertex.queueAction(0);

        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + 36000);

        vm.expectRevert(VertexCore.FailedActionExecution.selector);
        vertex.executeAction(0);
    }

    // submitApproval unit tests
    function test_submitApproval_RevertIfActionNotActive() public {
        vm.startPrank(actionCreator);
        vertex.createAction(strategies[0], address(protocol), 0, failSelector, abi.encode(""));
        vm.stopPrank();

        vm.startPrank(policyholder1);
        _approveAction(policyholder1);
        vm.stopPrank();

        vm.startPrank(policyholder2);
        _approveAction(policyholder2);
        vm.stopPrank();

        vm.warp(block.timestamp + 6 days);
        vm.roll(block.number + 43200);

        vertex.queueAction(0);

        vm.expectRevert(VertexCore.ActionNotActive.selector);
        vertex.submitApproval(0, true);
    }

    function test_submitApproval_RevertIfDuplicateApproval() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.stopPrank();

        vm.startPrank(policyholder1);
        _approveAction(policyholder1);

        vm.expectRevert(VertexCore.DuplicateApproval.selector);
        vertex.submitApproval(0, true);
    }

    function test_submitApproval_ChangeApprovalSupport() public {
        vm.startPrank(actionCreator);
        _createAction();
        vm.stopPrank();

        vm.startPrank(policyholder1);
        vertex.submitApproval(0, true);

        vm.expectEmit(true, true, true, true);
        emit PolicyholderApproved(0, policyholder1, false, 1);
        vertex.submitApproval(0, false);

        Action memory action = vertex.getAction(0);

        assertEq(action.totalApprovals, 0);
    }

    // submitDisapproval unit tests
    function test_submitDisapproval_RevertIfActionNotQueued() public {
        vm.startPrank(actionCreator);
        vertex.createAction(strategies[0], address(protocol), 0, failSelector, abi.encode(""));
        vm.stopPrank();

        vm.expectRevert(VertexCore.ActionNotQueued.selector);
        vertex.submitDisapproval(0, true);
    }

    function test_submitDisapproval_RevertIfDuplicateDisapproval() public {
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

        assertEq(strategies[0].isActionPassed(0), true);
        _queueAction();

        vm.startPrank(policyholder1);
        _disapproveAction(policyholder1);

        vm.expectRevert(VertexCore.DuplicateDisapproval.selector);
        vertex.submitDisapproval(0, true);
    }

    function test_submitDisapproval_ChangeDisapprovalSupport() public {
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

        _queueAction();

        vm.startPrank(policyholder1);
        vertex.submitDisapproval(0, true);

        vm.expectEmit(true, true, true, true);
        emit PolicyholderDisapproved(0, policyholder1, false, 1);
        vertex.submitDisapproval(0, false);

        Action memory action = vertex.getAction(0);

        assertEq(action.totalDisapprovals, 0);
    }

    // createAndAuthorizeStrategies unit tests
    function test_createAndAuthorizeStrategies_CreateNewStrategies() public {
        Strategy[] memory newStrategies = new Strategy[](3);
        VertexStrategy[] memory strategyAddresses = new VertexStrategy[](3);
        WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](0);
        WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](0);

        newStrategies[0] = Strategy({
            approvalPeriod: 4 days,
            queuingDuration: 14 days,
            expirationDelay: 3 days,
            isFixedLengthApprovalPeriod: false,
            minApprovalPct: 0,
            minDisapprovalPct: 20_00,
            approvalWeightByPermission: approvalWeightByPermission,
            disapprovalWeightByPermission: disapprovalWeightByPermission
        });

        newStrategies[1] = Strategy({
            approvalPeriod: 5 days,
            queuingDuration: 14 days,
            expirationDelay: 3 days,
            isFixedLengthApprovalPeriod: false,
            minApprovalPct: 0,
            minDisapprovalPct: 20_00,
            approvalWeightByPermission: approvalWeightByPermission,
            disapprovalWeightByPermission: disapprovalWeightByPermission
        });

        newStrategies[2] = Strategy({
            approvalPeriod: 6 days,
            queuingDuration: 14 days,
            expirationDelay: 3 days,
            isFixedLengthApprovalPeriod: false,
            minApprovalPct: 0,
            minDisapprovalPct: 20_00,
            approvalWeightByPermission: approvalWeightByPermission,
            disapprovalWeightByPermission: disapprovalWeightByPermission
        });

        for (uint256 i; i < newStrategies.length; i++) {
            bytes32 strategySalt = bytes32(keccak256(abi.encode(newStrategies[i])));
            bytes memory bytecode = type(VertexStrategy).creationCode;
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(vertex),
                    strategySalt,
                    keccak256(abi.encodePacked(bytecode, abi.encode(newStrategies[i], vertex.policy(), address(vertex))))
                )
            );
            strategyAddresses[i] = VertexStrategy(address(uint160(uint256(hash))));
        }

        vm.startPrank(address(vertex));

        vm.expectEmit(true, true, true, true);
        emit StrategyAuthorized(strategyAddresses[0], newStrategies[0]);
        vm.expectEmit(true, true, true, true);
        emit StrategyAuthorized(strategyAddresses[1], newStrategies[1]);
        vm.expectEmit(true, true, true, true);
        emit StrategyAuthorized(strategyAddresses[2], newStrategies[2]);
        vertex.createAndAuthorizeStrategies(newStrategies);

        assertEq(vertex.authorizedStrategies(strategyAddresses[0]), true);
        assertEq(vertex.authorizedStrategies(strategyAddresses[1]), true);
        assertEq(vertex.authorizedStrategies(strategyAddresses[2]), true);
    }

    // unauthorizeStrategies unit tests
    function test_unauthorizeStrategies_UnauthorizeStrategies() public {
        vm.startPrank(address(vertex));

        vm.expectEmit(true, true, true, true);
        emit StrategyUnauthorized(strategies[0]);
        vm.expectEmit(true, true, true, true);
        emit StrategyUnauthorized(strategies[1]);
        vertex.unauthorizeStrategies(strategies);

        assertEq(vertex.authorizedStrategies(strategies[0]), false);
        assertEq(vertex.authorizedStrategies(strategies[1]), false);
    }

    // createAndAuthorizeAccounts unit tests
    function test_createAndAuthorizeAccounts_CreateNewAccounts() public {
        string[] memory newAccounts = new string[](3);
        VertexAccount[] memory accountAddresses = new VertexAccount[](3);

        newAccounts[0] = "VertexAccount2";
        newAccounts[1] = "VertexAccount3";
        newAccounts[2] = "VertexAccount4";

        for (uint256 i; i < newAccounts.length; i++) {
            bytes32 accountSalt = bytes32(keccak256(abi.encode(newAccounts[i])));
            bytes memory bytecode = type(VertexAccount).creationCode;
            bytes32 hash = keccak256(
                abi.encodePacked(bytes1(0xff), address(vertex), accountSalt, keccak256(abi.encodePacked(bytecode, abi.encode(newAccounts[i], address(vertex)))))
            );
            accountAddresses[i] = VertexAccount(payable(address(uint160(uint256(hash)))));
        }

        vm.startPrank(address(vertex));

        vm.expectEmit(true, true, true, true);
        emit AccountAuthorized(accountAddresses[0], newAccounts[0]);
        vm.expectEmit(true, true, true, true);
        emit AccountAuthorized(accountAddresses[1], newAccounts[1]);
        vm.expectEmit(true, true, true, true);
        emit AccountAuthorized(accountAddresses[2], newAccounts[2]);
        vertex.createAndAuthorizeAccounts(newAccounts);

        assertEq(vertex.authorizedAccounts(accountAddresses[0]), true);
        assertEq(vertex.authorizedAccounts(accountAddresses[1]), true);
        assertEq(vertex.authorizedAccounts(accountAddresses[2]), true);
    }

    /*///////////////////////////////////////////////////////////////
                        Integration tests
    //////////////////////////////////////////////////////////////*/

    function test_VertexCore_CompleteActionFlow() public {
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

        assertEq(strategies[0].isActionPassed(0), true);
        _queueAction();

        vm.startPrank(policyholder1);
        _disapproveAction(policyholder1);
        vm.stopPrank();

        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + 36000);

        _executeAction();
    }

    /*///////////////////////////////////////////////////////////////
                        Action setup helpers
    //////////////////////////////////////////////////////////////*/

    function _createAction() public {
        vm.expectEmit(true, true, true, true);
        emit ActionCreated(0, actionCreator, strategies[0], address(protocol), 0, pauseSelector, abi.encode(true));
        vertex.createAction(strategies[0], address(protocol), 0, pauseSelector, abi.encode(true));

        Action memory action = vertex.getAction(0);
        uint256 approvalEndTime = block.number + action.strategy.approvalPeriod();

        assertEq(vertex.actionsCount(), 1);
        assertEq(action.createdBlockNumber, block.number);
        assertEq(approvalEndTime, block.number + 14400);
        assertEq(action.approvalPolicySupply, 5);
        assertEq(action.disapprovalPolicySupply, 5);
    }

    function _createPolicies() public {
        vm.startPrank(address(vertex));
        permission = PermissionData({target: address(protocol), selector: pauseSelector, strategy: strategies[0]});
        permissions.push(permission);
        permissionSignature.push(policy.hashPermission(permission));
        for (uint256 i; i < 5; i++) {
            if (i == 0) {
                bytes8[] memory creatorPermissions = new bytes8[](2);
                PermissionData memory failPermission = PermissionData({target: address(protocol), selector: failSelector, strategy: strategies[0]});
                creatorPermissions[0] = policy.hashPermission(failPermission);
                creatorPermissions[1] = policy.hashPermission(permission);
                permissionSignatures.push(creatorPermissions);
            } else {
                permissionSignatures.push(permissionSignature);
            }
        }
        addresses.push(actionCreator);
        addresses.push(policyholder1);
        addresses.push(policyholder2);
        addresses.push(policyholder3);
        addresses.push(policyholder4);
        policy.batchGrantPermissions(addresses, permissionSignatures, expirationTimestamps);
        vm.stopPrank();
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
        uint256 executionTime = block.timestamp + strategies[0].queuingDuration();
        vm.expectEmit(true, true, true, true);
        emit ActionQueued(0, address(this), strategies[0], actionCreator, executionTime);
        vertex.queueAction(0);
    }

    function _executeAction() public {
        vm.expectEmit(true, true, true, true);
        emit ActionExecuted(0, address(this), strategies[0], actionCreator);
        vertex.executeAction(0);

        Action memory action = vertex.getAction(0);
        assertEq(action.executed, true);
    }
}
