// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {ERC20Mock} from "@openzeppelin/mocks/ERC20Mock.sol";
import {VertexCore} from "src/VertexCore.sol";
import {IVertexCore} from "src/interfaces/IVertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexLens} from "src/VertexLens.sol";
import {
  Action,
  Strategy,
  PermissionData,
  WeightByPermission,
  PolicyGrantData,
  PermissionMetadata
} from "src/lib/Structs.sol";

contract VertexFactoryTest is Test {
  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicy);
  event StrategyAuthorized(VertexStrategy indexed strategy, Strategy strategyData);
  event AccountAuthorized(VertexAccount indexed account, string name);
  event PolicyAdded(PolicyGrantData grantData);

  // Vertex system
  VertexCore public rootVertex;
  VertexCore public vertexCoreLogic;
  VertexAccount public vertexAccountLogic;
  VertexPolicy public vertexPolicyLogic;
  VertexFactory public vertexFactory;
  VertexLens public vertexLens;
  VertexStrategy[] public strategies;
  VertexPolicy public policy;

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
  uint256 public constant approvalPeriod = 14_400; // 2 days in blocks
  uint256 public constant queuingPeriod = 4 days;
  uint256 public constant expirationPeriod = 8 days;
  bool public constant isFixedLengthApprovalPeriod = true;
  uint256 public constant minApprovalPct = 4000;
  uint256 public constant minDisapprovalPct = 2000;

  // Events
  event ActionCreated(
    uint256 id,
    address indexed creator,
    VertexStrategy indexed strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes data
  );
  event ActionCanceled(uint256 id);
  event ActionQueued(
    uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime
  );
  event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);
  event PolicyholderApproved(uint256 id, address indexed policyholder, uint256 weight);
  event PolicyholderDisapproved(uint256 id, address indexed policyholder, uint256 weight);
  event StrategiesAuthorized(Strategy[] strategies);
  event StrategiesUnauthorized(VertexStrategy[] strategies);

  function setUp() public {
    vertexCoreLogic = new VertexCore();
    vertexAccountLogic = new VertexAccount();
    vertexPolicyLogic = new VertexPolicy();

    // Setup strategy parameters
    Strategy[] memory initialStrategies = createInitialStrategies();

    PolicyGrantData[] memory initialPolicies = buildInitialPolicyGrantData();

    // Deploy vertex and mock protocol
    vertexFactory = new VertexFactory(
          vertexCoreLogic,
          vertexAccountLogic,
          vertexPolicyLogic,
          "ProtocolXYZ",
          "VXP",
          initialStrategies,
          buildInitialAccounts(),
          initialPolicies
        );

    vertexLens = new VertexLens();

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

  function _computeStrategyAddress(Strategy memory _strategy) internal view returns (address _address) {
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
    PermissionMetadata[] defaultPermissions;
    PermissionMetadata[] creatorPermissions;
  }

  function createPolicies() internal {
    vm.startPrank(address(rootVertex));

    TestHelperVars memory _vars;

    _vars.pausePermissionData =
      PermissionData({target: address(protocol), selector: pauseSelector, strategy: strategies[0]});
    _vars.failPermissionData =
      PermissionData({target: address(protocol), selector: failSelector, strategy: strategies[0]});
    permissions.push(_vars.pausePermissionData);

    _vars.creatorPermissions = new PermissionMetadata[](2);
    _vars.creatorPermissions[0] = PermissionMetadata({
      permissionId: vertexLens.computePermissionId(_vars.failPermissionData),
      expirationTimestamp: 0 // no expiration
    });
    _vars.creatorPermissions[1] = PermissionMetadata({
      permissionId: vertexLens.computePermissionId(_vars.pausePermissionData),
      expirationTimestamp: 0 // no expiration
    });

    _vars.defaultPermissions = new PermissionMetadata[](1);
    _vars.defaultPermissions[0] = PermissionMetadata({
      permissionId: vertexLens.computePermissionId(_vars.pausePermissionData),
      expirationTimestamp: 0 // no expiration
    });

    addresses.push(actionCreator);
    addresses.push(policyholder1);
    addresses.push(policyholder2);
    addresses.push(policyholder3);
    addresses.push(policyholder4);

    PolicyGrantData[] memory initialPolicies = new PolicyGrantData[](5);
    initialPolicies[0] = PolicyGrantData(actionCreator, _vars.creatorPermissions);
    initialPolicies[1] = PolicyGrantData(policyholder1, _vars.defaultPermissions);
    initialPolicies[2] = PolicyGrantData(policyholder2, _vars.defaultPermissions);
    initialPolicies[3] = PolicyGrantData(policyholder3, _vars.defaultPermissions);
    initialPolicies[4] = PolicyGrantData(policyholder4, _vars.defaultPermissions);

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
      minApprovalPct: 8000,
      minDisapprovalPct: 10_001,
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

  function buildInitialPolicyGrantData() internal pure returns (PolicyGrantData[] memory initialPolicyGrantData) {
    PermissionMetadata[] memory firstPermissions = new PermissionMetadata[](1);
    firstPermissions[0] = PermissionMetadata(0xa9cc4718a9cc4718, 0);

    PermissionMetadata[] memory secondPermissions = new PermissionMetadata[](1);
    secondPermissions[0] = PermissionMetadata(0xffffffffffffffff, 0);

    initialPolicyGrantData = new PolicyGrantData[](2);
    initialPolicyGrantData[0] = PolicyGrantData({user: actionCreator, permissionsToAdd: firstPermissions});
    initialPolicyGrantData[1] = PolicyGrantData({user: policyholder1, permissionsToAdd: secondPermissions});
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
  function deployVertex() internal returns (VertexCore) {
    Strategy[] memory initialStrategies = createInitialStrategies();
    string[] memory initialAccounts = buildInitialAccounts();
    vm.prank(address(rootVertex));
    return vertexFactory.deploy("NewProject", "NP", initialStrategies, initialAccounts, buildInitialPolicyGrantData());
  }

  function test_RevertsIf_CalledByAccountThatIsNotRootVertex(address caller) public {
    vm.assume(caller != address(rootVertex));
    Strategy[] memory initialStrategies = createInitialStrategies();
    string[] memory initialAccounts = buildInitialAccounts();

    vm.prank(address(caller));
    vm.expectRevert(VertexFactory.OnlyVertex.selector);
    vertexFactory.deploy("ProtocolXYZ", "VXP", initialStrategies, initialAccounts, buildInitialPolicyGrantData());
  }

  function test_RevertsIf_InstanceDeployedWithSameName(string memory name) public {
    Strategy[] memory initialStrategies = createInitialStrategies();
    string[] memory initialAccounts = buildInitialAccounts();

    vm.prank(address(rootVertex));
    vertexFactory.deploy(name, "SYMBOL", initialStrategies, initialAccounts, buildInitialPolicyGrantData());
    vm.expectRevert();
    vertexFactory.deploy(name, "SYMBOL", initialStrategies, initialAccounts, buildInitialPolicyGrantData());
  }

  function test_IncrementsVertexCountByOne() public {
    uint256 initialVertexCount = vertexFactory.vertexCount();
    deployVertex();
    assertEq(vertexFactory.vertexCount(), initialVertexCount + 1);
  }

  function test_DeploysPolicy() public {
    VertexPolicy _policy =
      vertexLens.computeVertexPolicyAddress("NewProject", address(vertexPolicyLogic), address(vertexFactory));
    assertEq(address(_policy).code.length, 0);
    deployVertex();
    assertGt(address(_policy).code.length, 0);
    VertexPolicy(_policy).baseURI(); // Sanity check that this doesn't revert.
  }

  function test_DeploysVertexCore() public {
    VertexCore _vertex =
      vertexLens.computeVertexCoreAddress("NewProject", address(vertexCoreLogic), address(vertexFactory));
    assertEq(address(_vertex).code.length, 0);
    deployVertex();
    assertGt(address(_vertex).code.length, 0);
    VertexCore(address(_vertex)).name(); // Sanity check that this doesn't revert.
  }

  function test_InitializesVertexCore() public {
    VertexCore _vertex = deployVertex();
    assertEq(_vertex.name(), "NewProject");

    Strategy[] memory initialStrategies = createInitialStrategies();
    string[] memory initialAccounts = buildInitialAccounts();
    VertexPolicy _policy = _vertex.policy();
    vm.expectRevert("Initializable: contract is already initialized");
    _vertex.initialize("NewProject", _policy, vertexAccountLogic, initialStrategies, initialAccounts);
  }

  function test_SetsVertexCoreAddressOnThePolicy() public {
    VertexCore _vertex = deployVertex();
    VertexPolicy _policy = _vertex.policy();
    VertexCore _vertexFromPolicy = VertexCore(_policy.vertex());
    assertEq(address(_vertexFromPolicy), address(_vertex));
  }

  function test_SetsPolicyAddressOnVertexCore() public {
    VertexPolicy computedPolicy =
      vertexLens.computeVertexPolicyAddress("NewProject", address(vertexPolicyLogic), address(vertexFactory));
    VertexCore _vertex = deployVertex();
    assertEq(address(_vertex.policy()), address(computedPolicy));
  }

  function test_EmitsVertexCreatedEvent() public {
    vm.expectEmit(true, true, true, true);
    VertexCore computedVertex =
      vertexLens.computeVertexCoreAddress("NewProject", address(vertexCoreLogic), address(vertexFactory));
    VertexPolicy computedPolicy =
      vertexLens.computeVertexPolicyAddress("NewProject", address(vertexPolicyLogic), address(vertexFactory));
    emit VertexCreated(1, "NewProject", address(computedVertex), address(computedPolicy));
    deployVertex();
  }

  function test_ReturnsAddressOfTheNewVertexCoreContract() public {
    VertexCore computedVertex =
      vertexLens.computeVertexCoreAddress("NewProject", address(vertexCoreLogic), address(vertexFactory));
    VertexCore newVertex = deployVertex();
    assertEq(address(newVertex), address(computedVertex));
    assertEq(address(computedVertex), VertexPolicy(computedVertex.policy()).vertex());
    assertEq(address(computedVertex), VertexPolicy(newVertex.policy()).vertex());
  }
}

contract Integration is VertexFactoryTest {
  string[] initialAccounts;
  WeightByPermission[] emptyWeights;
  PermissionMetadata[] emptyPermissions;
  address user1 = address(0x1); // admin
  address user2 = address(0x2); // empty policy

  function test_DeploysInstanceWithFullySpecificiedStrategiesAndPolicies() public {
    initialAccounts.push("Integration Test Account");
    VertexCore computedVertexCore =
      vertexLens.computeVertexCoreAddress("Integration Test", address(vertexCoreLogic), address(vertexFactory));
    VertexPolicy computedVertexPolicy =
      vertexLens.computeVertexPolicyAddress("Integration Test", address(vertexPolicyLogic), address(vertexFactory));
    VertexAccount computedVertexAccount = vertexLens.computeVertexAccountAddress(
      address(vertexAccountLogic), initialAccounts[0], address(computedVertexCore)
    );
    Strategy memory strategyData = buildStrategyData();
    VertexStrategy computedStrategy =
      vertexLens.computeVertexStrategyAddress(strategyData, computedVertexPolicy, address(computedVertexCore));
    ERC20Mock token = new ERC20Mock("Mock", "MCK", address(computedVertexAccount), 100000);
    (WeightByPermission[] memory newWeights, PermissionMetadata[] memory permissionMetadata) =
      buildNewWeightsAndPermissions(computedVertexAccount, computedStrategy, computedVertexPolicy);
    strategyData.approvalWeightByPermission = newWeights;
    strategyData.disapprovalWeightByPermission = newWeights;
    Strategy[] memory initialStrategies = buildInitialStrategies(strategyData);
    PolicyGrantData[] memory initialPolicies = buildInitialPolicies(permissionMetadata);
    vm.prank(address(rootVertex));
    vm.expectEmit(true, true, true, true);
    emit VertexCreated(1, "Integration Test", address(computedVertexCore), address(computedVertexPolicy));
    emit StrategyAuthorized(computedStrategy, strategyData);
    emit AccountAuthorized(computedVertexAccount, initialAccounts[0]);
    emit PolicyAdded(initialPolicies[0]);
    emit PolicyAdded(initialPolicies[1]);
    VertexCore newVertex =
      vertexFactory.deploy("Integration Test", "IT", initialStrategies, initialAccounts, initialPolicies);
    assertEq(address(newVertex), address(computedVertexCore));
    assertEq(address(newVertex.policy()), address(computedVertexPolicy));
  }

  function buildStrategyData() public view returns (Strategy memory) {
    return Strategy(
      1 days, // The length of time of the approval period.
      1 days, // The length of time of the queuing period. The disapproval period is the queuing period when enabled.
      1 days, // The length of time an action can be executed before it expires.
      5000, // Minimum percentage of total approval weight / total approval supply.
      5000, // Minimum percentage of total disapproval weight / total disapproval supply.
      emptyWeights, // List of permissionSignatures and weights that define the validation process for
        // approval.
      emptyWeights, // List of permissionSignatures and weights that define the validation process for
        // disapproval.
      false // Determines if an action be queued before approvalEndTime.
    );
  }

  function buildNewWeightsAndPermissions(
    VertexAccount computedVertexAccount,
    VertexStrategy computedStrategy,
    VertexPolicy computedVertexPolicy
  ) public view returns (WeightByPermission[] memory, PermissionMetadata[] memory) {
    PermissionData memory approveERC20Permission =
      PermissionData(address(computedVertexAccount), computedVertexAccount.approveERC20.selector, computedStrategy);
    PermissionData memory transferERC20Permission =
      PermissionData(address(computedVertexAccount), computedVertexAccount.transferERC20.selector, computedStrategy);
    PermissionData memory revokePolicyPermission =
      PermissionData(address(computedVertexPolicy), computedVertexPolicy.batchRevokePolicies.selector, computedStrategy);
    bytes8 permissionId1 = vertexLens.computePermissionId(approveERC20Permission);
    bytes8 permissionId2 = vertexLens.computePermissionId(transferERC20Permission);
    bytes8 permissionId3 = vertexLens.computePermissionId(revokePolicyPermission);
    WeightByPermission[] memory newWeights = new WeightByPermission[](3);
    newWeights[0] = WeightByPermission(permissionId1, 2);
    newWeights[1] = WeightByPermission(permissionId2, 2);
    newWeights[2] = WeightByPermission(permissionId3, 2);

    PermissionMetadata[] memory permissionMetadata = new PermissionMetadata[](3);
    {
      permissionMetadata[0] = PermissionMetadata(permissionId1, 0);
      permissionMetadata[1] = PermissionMetadata(permissionId2, 0);
      permissionMetadata[1] = PermissionMetadata(permissionId3, 0);
    }
    return (newWeights, permissionMetadata);
  }

  function buildInitialStrategies(Strategy memory strategyData) public pure returns (Strategy[] memory) {
    Strategy[] memory initialStrategies = new Strategy[](1);
    initialStrategies[0] = strategyData;
    return initialStrategies;
  }

  function buildInitialPolicies(PermissionMetadata[] memory permissionMetadata)
    public
    view
    returns (PolicyGrantData[] memory)
  {
    PolicyGrantData[] memory initialPolicies = new PolicyGrantData[](2);
    initialPolicies[0] = PolicyGrantData(user1, permissionMetadata);
    initialPolicies[1] = PolicyGrantData(user2, emptyPermissions);
    return initialPolicies;
  }
}

