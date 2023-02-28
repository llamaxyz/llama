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
import {Action, Strategy, PermissionData, WeightByPermission, BatchGrantData, PermissionChangeData} from "src/utils/Structs.sol";

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
    address[] public addresses;
    uint256[] public policyIds;

    // Strategy config
    uint256 public constant approvalPeriod = 14400; // 2 days in blocks
    uint256 public constant queuingPeriod = 4 days;
    uint256 public constant expirationPeriod = 8 days;
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

        BatchGrantData[] memory initialPolicies = buildInitialBatchGrantData();

        // Deploy vertex and mock protocol
        vertexFactory = new VertexFactory(
          vertexCoreLogic,
          vertexAccountLogic,
          "ProtocolXYZ",
          "VXP",
          initialStrategies,
          buildInitialAccounts(),
          initialPolicies
        );

        rootVertex = VertexCore(vertexFactory.rootVertex());
        protocol = new ProtocolXYZ(address(rootVertex));

        // Use create2 to get vertex strategy addresses
        for (uint256 i; i < initialStrategies.length; i++) {
            strategies.push(VertexStrategy(_computeStrategyAddress(initialStrategies[i])));
        }

        // Set vertex's policy
        policy = rootVertex.policy();

        // Create and assign policies
        // createPolicies();

        vm.label(actionCreator, "Action Creator");
    }

    function _computeStrategyAddress(Strategy memory _strategy) internal returns (address _address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(rootVertex),
                keccak256(abi.encode(_strategy)), // strategy salt
                keccak256(
                    abi.encodePacked(
                        type(VertexStrategy).creationCode, // bytecode
                        abi.encode(_strategy, rootVertex.policy(), address(rootVertex))
                    )
                )
            )
        );
        _address = address(uint160(uint256(hash)));
    }

    struct TestHelperVars {
        PermissionData pausePermissionData;
        PermissionData failPermissionData;
        PermissionChangeData[] defaultPermissions;
        PermissionChangeData[] creatorPermissions;
    }

    function createPolicies() internal {
        vm.startPrank(address(rootVertex));

        TestHelperVars memory _vars;

        _vars.pausePermissionData = PermissionData({target: address(protocol), selector: pauseSelector, strategy: strategies[0]});
        _vars.failPermissionData = PermissionData({target: address(protocol), selector: failSelector, strategy: strategies[0]});
        permissions.push(_vars.pausePermissionData);

        _vars.creatorPermissions = new PermissionChangeData[](2);
        _vars.creatorPermissions[0] = PermissionChangeData({
            permissionId: policy.hashPermission(_vars.failPermissionData),
            expirationTimestamp: 0 // no expiration
        });
        _vars.creatorPermissions[1] = PermissionChangeData({
            permissionId: policy.hashPermission(_vars.pausePermissionData),
            expirationTimestamp: 0 // no expiration
        });

        _vars.defaultPermissions = new PermissionChangeData[](1);
        _vars.defaultPermissions[0] = PermissionChangeData({
            permissionId: policy.hashPermission(_vars.pausePermissionData),
            expirationTimestamp: 0 // no expiration
        });

        addresses.push(actionCreator);
        addresses.push(policyholder1);
        addresses.push(policyholder2);
        addresses.push(policyholder3);
        addresses.push(policyholder4);

        BatchGrantData[] memory initialPolicies = new BatchGrantData[](5);
        initialPolicies[0] = BatchGrantData(actionCreator, _vars.creatorPermissions);
        initialPolicies[1] = BatchGrantData(policyholder1, _vars.defaultPermissions);
        initialPolicies[2] = BatchGrantData(policyholder2, _vars.defaultPermissions);
        initialPolicies[3] = BatchGrantData(policyholder3, _vars.defaultPermissions);
        initialPolicies[4] = BatchGrantData(policyholder4, _vars.defaultPermissions);

        policy.batchGrantPolicies(initialPolicies);

        vm.stopPrank();
    }

    function createInitialStrategies() internal pure returns (Strategy[] memory _strategies) {
        WeightByPermission[] memory _permissionsWithWeights = new WeightByPermission[](2);
        _permissionsWithWeights[0] = WeightByPermission({permissionSignature: 0xa9cc4718a9cc4718, weight: uint256(2)});
        _permissionsWithWeights[1] = WeightByPermission({permissionSignature: 0xffffffffffffffff, weight: uint256(0)});

        _strategies = new Strategy[](2);

        _strategies[0] = Strategy({
            approvalPeriod: approvalPeriod,
            queuingPeriod: queuingPeriod,
            expirationPeriod: expirationPeriod,
            isFixedLengthApprovalPeriod: isFixedLengthApprovalPeriod,
            minApprovalPct: minApprovalPct,
            minDisapprovalPct: minDisapprovalPct,
            approvalWeightByPermission: _permissionsWithWeights,
            disapprovalWeightByPermission: _permissionsWithWeights
        });

        _strategies[1] = Strategy({
            approvalPeriod: approvalPeriod,
            queuingPeriod: 0,
            expirationPeriod: 1 days,
            isFixedLengthApprovalPeriod: false,
            minApprovalPct: 80_00,
            minDisapprovalPct: 10001,
            approvalWeightByPermission: _permissionsWithWeights,
            disapprovalWeightByPermission: _permissionsWithWeights
        });
    }

    function buildInitialAccounts() internal pure returns (string[] memory) {
        string[] memory initialAccounts = new string[](2);
        initialAccounts[0] = "VertexAccount0";
        initialAccounts[1] = "VertexAccount1";
        return initialAccounts;
    }

    function buildInitialBatchGrantData() internal returns (BatchGrantData[] memory initialBatchGrantData) {
        PermissionChangeData[] memory firstPermissions = new PermissionChangeData[](1);
        firstPermissions[0] = PermissionChangeData(0xa9cc4718a9cc4718, 0);

        PermissionChangeData[] memory secondPermissions = new PermissionChangeData[](1);
        secondPermissions[0] = PermissionChangeData(0xffffffffffffffff, 0);

        initialBatchGrantData = new BatchGrantData[](2);
        initialBatchGrantData[0] = BatchGrantData({user: actionCreator, permissionsToAdd: firstPermissions});
        initialBatchGrantData[1] = BatchGrantData({user: policyholder1, permissionsToAdd: secondPermissions});
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
    address constant NEW_VERTEX = 0x5Fa39CD9DD20a3A77BA0CaD164bD5CF0d7bb3303;
    address constant NEW_POLICY = 0xf047BDe414204DC44Ce598aE4d72C84780739995;

    function deployVertex() internal returns (VertexCore) {
        Strategy[] memory initialStrategies = createInitialStrategies();
        string[] memory initialAccounts = buildInitialAccounts();
        vm.prank(address(rootVertex));
        return vertexFactory.deploy("NewProject", "NP", initialStrategies, initialAccounts, buildInitialBatchGrantData());
    }

    function test_RevertsIf_CalledByAccountThatIsNotRootVertex(address caller) public {
        vm.assume(caller != address(rootVertex));
        Strategy[] memory initialStrategies = createInitialStrategies();
        string[] memory initialAccounts = buildInitialAccounts();

        vm.prank(address(caller));
        vm.expectRevert(VertexFactory.OnlyVertex.selector);
        vertexFactory.deploy("ProtocolXYZ", "VXP", initialStrategies, initialAccounts, buildInitialBatchGrantData());
    }

    function test_IncrementsVertexCountByOne() public {
        uint256 initialVertexCount = vertexFactory.vertexCount();
        deployVertex();
        assertEq(vertexFactory.vertexCount(), initialVertexCount + 1);
    }

    function test_DeploysPolicy() public {
        assertEq(NEW_POLICY.code.length, 0);
        VertexCore _vertex = deployVertex();
        assertGt(NEW_POLICY.code.length, 0);
        VertexPolicyNFT(NEW_POLICY).baseURI(); // Sanity check that this doesn't revert.
    }

    function test_DeploysVertexCore() public {
        assertEq(NEW_VERTEX.code.length, 0);
        VertexCore _vertex = deployVertex();
        assertGt(NEW_VERTEX.code.length, 0);
        VertexCore(NEW_VERTEX).name(); // Sanity check that this doesn't revert.
    }

    function test_InitializesVertexCore() public {
        deployVertex();
        assertEq(VertexCore(NEW_VERTEX).name(), "NewProject");

        Strategy[] memory initialStrategies = createInitialStrategies();
        string[] memory initialAccounts = buildInitialAccounts();
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
