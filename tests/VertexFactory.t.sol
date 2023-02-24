// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexFactory} from "src/factory/VertexFactory.sol";
import {ProtocolXYZ} from "src/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {VertexAccount} from "src/account/VertexAccount.sol";
import {Action, Strategy, PermissionData, WeightByPermission} from "src/utils/Structs.sol";

contract VertexFactoryTest is Test {
    event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT);

    // Vertex system
    VertexCore public rootVertex;
    VertexCore public vertexCoreLogic;
    VertexAccount public vertexAccountLogic;
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
    event PolicyholderApproved(uint256 id, address indexed policyholder, uint256 weight);
    event PolicyholderDisapproved(uint256 id, address indexed policyholder, uint256 weight);
    event StrategiesAuthorized(Strategy[] strategies);
    event StrategiesUnauthorized(VertexStrategy[] strategies);

    function setUp() public {
        vertexCoreLogic = new VertexCore();
        vertexAccountLogic = new VertexAccount();

        // Setup strategy parameters
        Strategy[] memory initialStrategies = createInitialStrategies();
        string[] memory initialAccounts = createInitialAccounts();

        // Deploy vertex and mock protocol
        vertexFactory =
        new VertexFactory(vertexCoreLogic, vertexAccountLogic, "ProtocolXYZ", "VXP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
        rootVertex = VertexCore(vertexFactory.rootVertex());
        protocol = new ProtocolXYZ(address(rootVertex));

        // Use create2 to get vertex strategy addresses
        for (uint256 i; i < initialStrategies.length; i++) {
            bytes32 strategySalt = bytes32(keccak256(abi.encode(initialStrategies[i])));
            bytes memory bytecode = type(VertexStrategy).creationCode;
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(rootVertex),
                    strategySalt,
                    keccak256(abi.encodePacked(bytecode, abi.encode(initialStrategies[i], rootVertex.policy(), address(rootVertex))))
                )
            );
            strategies.push(VertexStrategy(address(uint160(uint256(hash)))));
        }
        // Set vertex's policy
        policy = rootVertex.policy();

        // Create and assign policies
        createPolicies();

        vm.label(actionCreator, "Action Creator");
    }

    function createPolicies() internal {
        vm.startPrank(address(rootVertex));
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
        policy.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
        vm.stopPrank();
    }

    function createInitialStrategies() internal pure returns (Strategy[] memory) {
        bytes8 permissionSig = 0xa9cc4718a9cc4718;
        WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](2);
        approvalWeightByPermission[0] = WeightByPermission({permissionSignature: permissionSig, weight: uint256(2)});
        approvalWeightByPermission[1] = WeightByPermission({permissionSignature: 0xffffffffffffffff, weight: uint256(0)});

        WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](2);
        disapprovalWeightByPermission[0] = WeightByPermission({permissionSignature: permissionSig, weight: uint256(2)});
        disapprovalWeightByPermission[1] = WeightByPermission({permissionSignature: 0xffffffffffffffff, weight: uint256(0)});
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

    function createInitialAccounts() internal pure returns (string[] memory) {
        string[] memory initialAccounts = new string[](2);
        initialAccounts[0] = "VertexAccount0";
        initialAccounts[1] = "VertexAccount1";
        return initialAccounts;
    }
}

contract Constructor is VertexFactoryTest {
    function test_SetsVertexCoreLogicAddress() public {
        assertEq(address(vertexFactory.vertexCoreLogic()), address(vertexCoreLogic));
    }

    function test_SetsVertexAccountLogicAddress() public {
        assertEq(address(vertexFactory.vertexAccountLogic()), address(vertexAccountLogic));
    }

    function test_SetsRootVertexAddress() public {
        assertEq(address(vertexFactory.rootVertex()), address(rootVertex));
    }

    function test_DeploysRootVertexViaInternalDeployMethod() public {
        // The internal `_deploy` method is tested in the `Deploy` contract, so here we just check
        // one side effect of that method as a sanity check it was called. If it was called, the
        // vertex count should no longer be zero.
        assertEq(vertexFactory.vertexCount(), 1);
    }
}

contract Deploy is VertexFactoryTest {
    // These are the expected addresses of the contracts deployed by the `deployVertex` helper
    // method. The addresses are functions of the constructor parameters in the `deployVertex`
    // helper method, so if those parameters change, or we change the constructor signature, these
    // will need to be updated.
    address constant NEW_VERTEX = 0xCe71065D4017F316EC606Fe4422e11eB2c47c246;
    address constant NEW_POLICY = 0x79F739E17E3a8e4b7eBBDcb96d3B7Ad1E116abEC;

    function deployVertex() internal returns (VertexCore) {
        Strategy[] memory initialStrategies = createInitialStrategies();
        string[] memory initialAccounts = createInitialAccounts();
        vm.prank(address(rootVertex));
        return vertexFactory.deploy("NewProject", "NP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
    }

    function test_RevertsIf_CalledByAccountThatIsNotRootVertex(address caller) public {
        vm.assume(caller != address(rootVertex));
        Strategy[] memory initialStrategies = createInitialStrategies();
        string[] memory initialAccounts = createInitialAccounts();

        vm.prank(address(caller));
        vm.expectRevert(VertexFactory.OnlyVertex.selector);
        vertexFactory.deploy("ProtocolXYZ", "VXP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
    }

    function test_IncrementsVertexCountByOne() public {
        uint256 initialVertexCount = vertexFactory.vertexCount();
        deployVertex();
        assertEq(vertexFactory.vertexCount(), initialVertexCount + 1);
    }

    function test_DeploysPolicy() public {
        assertEq(NEW_POLICY.code.length, 0);
        deployVertex();
        assertGt(NEW_POLICY.code.length, 0);
        VertexPolicyNFT(NEW_POLICY).baseURI(); // Sanity check that this doesn't revert.
    }

    function test_DeploysVertexCore() public {
        assertEq(NEW_VERTEX.code.length, 0);
        deployVertex();
        assertGt(NEW_VERTEX.code.length, 0);
        VertexCore(NEW_VERTEX).name(); // Sanity check that this doesn't revert.
    }

    function test_InitializesVertexCore() public {
        deployVertex();
        assertEq(VertexCore(NEW_VERTEX).name(), "NewProject");

        Strategy[] memory initialStrategies = createInitialStrategies();
        string[] memory initialAccounts = createInitialAccounts();
        vm.expectRevert("Initializable: contract is already initialized");
        VertexCore(NEW_VERTEX).initialize("NewProject", VertexPolicyNFT(NEW_POLICY), vertexAccountLogic, initialStrategies, initialAccounts);
    }

    function test_SetsVertexCoreAddressOnThePolicy() public {
        deployVertex();
        assertEq(VertexPolicyNFT(NEW_POLICY).vertex(), NEW_VERTEX);
    }

    function test_SetsPolicyAddressOnVertexCore() public {
        deployVertex();
        assertEq(address(VertexCore(NEW_VERTEX).policy()), NEW_POLICY);
    }

    function test_EmitsVertexCreatedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit VertexCreated(1, "NewProject", NEW_VERTEX, NEW_POLICY);
        deployVertex();
    }

    function test_ReturnsAddressOfTheNewVertexCoreContract() public {
        address newVertex = address(deployVertex());
        assertEq(newVertex, NEW_VERTEX);
        assertEq(newVertex, VertexPolicyNFT(NEW_POLICY).vertex());
    }
}

contract ComputeAddress is VertexFactoryTest {
    // TODO Add methods to the factory that, given the salt (or the fields used to derive the salt),
    // and constructor arguments if applicable, returns the address of the contract that would
    // deployed. Since the `deploy` method deploys two contracts, we need a method for each one.
    // One those methods exist we can fill in the tests for them here.

    function test_ComputesExpectedAddressForVertexCore() public {
        // TODO
    }

    function test_ComputesExpectedAddressForPolicy() public {
        // TODO
    }
}
