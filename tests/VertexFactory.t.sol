// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexFactory} from "src/factory/VertexFactory.sol";
import {ProtocolXYZ} from "src/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Action, Strategy, PermissionData, WeightByPermission} from "src/utils/Structs.sol";

contract VertexFactoryTest is Test {
    event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT);

    // Vertex system
    VertexCore public vertex;
    VertexCore public vertexCore;
    VertexFactory public vertexFactory;
    VertexStrategy[] public strategies;
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
    address[] public addresses;
    uint256[] public policyIds;

    address[] public initialPolicies;
    bytes8[][] public initialPermissions;
    uint256[][] public initialExpirationTimestamps;
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
    event StrategiesAuthorized(Strategy[] strategies);
    event StrategiesUnauthorized(VertexStrategy[] strategies);

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        vertexCore = new VertexCore();
        // Setup strategy parameters
        Strategy[] memory initialStrategies = _createInitialStrategies();
        string[] memory initialAccounts = _createInitialAccounts();

        // Deploy vertex and mock protocol
        vertexFactory =
        new VertexFactory(vertexCore, "ProtocolXYZ", "VXP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
        vertex = VertexCore(vertexFactory.initialVertex());
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
        // Set vertex's policy
        policy = vertex.policy();

        // Create and assign policies
        _createPolicies();

        vm.label(actionCreator, "Action Creator");
    }

    function test_deploy_DeployIfInitialVertex() public {
        Strategy[] memory initialStrategies = _createInitialStrategies();
        string[] memory initialAccounts = _createInitialAccounts();
        address deployedVertex = 0x76006C4471fb6aDd17728e9c9c8B67d5AF06cDA0;
        address deployedPolicy = 0x525F3daaB67189A2763B96A1518aaE34292a4f0b;
        vm.startPrank(address(vertex));
        vm.expectEmit(true, true, true, true);
        emit VertexCreated(1, "NewProject", deployedVertex, deployedPolicy);
        vertexFactory.deploy("NewProject", "NP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
    }

    function testFuzz_deploy_RevertIfNotInitialVertex(address notInitialVertex) public {
        vm.assume(notInitialVertex != address(vertex));
        Strategy[] memory initialStrategies = _createInitialStrategies();
        string[] memory initialAccounts = _createInitialAccounts();
        vm.prank(address(notInitialVertex));
        vm.expectRevert(VertexFactory.OnlyVertex.selector);
        vertexFactory.deploy("ProtocolXYZ", "VXP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
    }

    function test_deploy_RevertIfReinitialized() public {
        Strategy[] memory initialStrategies = _createInitialStrategies();
        string[] memory initialAccounts = _createInitialAccounts();
        vm.prank(address(vertex));
        VertexCore newVertex =
            vertexFactory.deploy("NewProject", "NP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
        VertexPolicyNFT _policy = newVertex.policy();
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        newVertex.initialize("NewProject", _policy, initialStrategies, initialAccounts);

        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vertexCore.initialize("NewProject", _policy, initialStrategies, initialAccounts);
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
        policy.batchGrantPermissions(addresses, permissionSignatures, initialExpirationTimestamps);
        vm.stopPrank();
    }

    function _createInitialStrategies() public pure returns (Strategy[] memory) {
        bytes8 permissionSig = 0xa9cc4718a9cc4718;
        WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](2);
        approvalWeightByPermission[0] = WeightByPermission({permissionSignature: permissionSig, weight: uint248(2)});
        approvalWeightByPermission[1] = WeightByPermission({permissionSignature: 0xffffffffffffffff, weight: uint248(0)});

        WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](2);
        disapprovalWeightByPermission[0] = WeightByPermission({permissionSignature: permissionSig, weight: uint248(2)});
        disapprovalWeightByPermission[1] = WeightByPermission({permissionSignature: 0xffffffffffffffff, weight: uint248(0)});
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

        return initialStrategies;
    }

    function _createInitialAccounts() public pure returns (string[] memory) {
        string[] memory initialAccounts = new string[](2);
        initialAccounts[0] = "VertexAccount0";
        initialAccounts[1] = "VertexAccount1";
        return initialAccounts;
    }
}
