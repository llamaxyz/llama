// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {ERC20Mock} from "@openzeppelin/mocks/ERC20Mock.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexCore} from "src/VertexCore.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexLens} from "src/VertexLens.sol";
import {Action, Strategy, PermissionData, PolicyGrantData, PermissionMetadata} from "src/lib/Structs.sol";
import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";

contract VertexFactoryTest is VertexTestSetup {
  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicy);
  event StrategyAuthorized(VertexStrategy indexed strategy, Strategy strategyData);
  event AccountAuthorized(VertexAccount indexed account, string name);
  event PolicyAdded(PolicyGrantData grantData);

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
}

contract Constructor is VertexFactoryTest {
  function test_SetsVertexCoreLogicAddress() public {
    assertEq(address(factory.vertexCoreLogic()), address(coreLogic));
  }

  function test_SetsVertexAccountLogicAddress() public {
    assertEq(address(factory.vertexAccountLogic()), address(accountLogic));
  }

  function test_SetsRootVertexAddress() public {
    assertEq(address(factory.rootVertex()), address(core));
  }

  function test_DeploysRootVertexViaInternalDeployMethod() public {
    // The internal `_deploy` method is tested in the `Deploy` contract, so here we just check
    // one side effect of that method as a sanity check it was called. If it was called, the
    // vertex count should no longer be zero.
    assertEq(factory.vertexCount(), 1);
  }
}

contract Deploy is VertexFactoryTest {
  function deployVertex() internal returns (VertexCore) {
    (Strategy[] memory strategies, string[] memory accounts, PolicyGrantData[] memory policies) =
      getDefaultVertexDeployParameters();
    vm.prank(address(core));
    return factory.deploy("NewProject", strategies, accounts, policies);
  }

  function test_RevertsIf_CalledByAccountThatIsNotRootVertex(address caller) public {
    vm.assume(caller != address(core));
    (Strategy[] memory strategies, string[] memory accounts, PolicyGrantData[] memory policies) =
      getDefaultVertexDeployParameters();

    vm.prank(address(caller));
    vm.expectRevert(VertexFactory.OnlyVertex.selector);
    factory.deploy("ProtocolXYZ", strategies, accounts, policies);
  }

  function test_RevertsIf_InstanceDeployedWithSameName(string memory name) public {
    (Strategy[] memory strategies, string[] memory accounts, PolicyGrantData[] memory policies) =
      getDefaultVertexDeployParameters();

    vm.prank(address(core));
    factory.deploy(name, strategies, accounts, policies);
    vm.expectRevert();
    factory.deploy(name, strategies, accounts, policies);
  }

  function test_IncrementsVertexCountByOne() public {
    uint256 initialVertexCount = factory.vertexCount();
    deployVertex();
    assertEq(factory.vertexCount(), initialVertexCount + 1);
  }

  function test_DeploysPolicy() public {
    VertexPolicy _policy = lens.computeVertexPolicyAddress("NewProject", address(policyLogic), address(factory));
    assertEq(address(_policy).code.length, 0);
    deployVertex();
    assertGt(address(_policy).code.length, 0);
    VertexPolicy(_policy).baseURI(); // Sanity check that this doesn't revert.
  }

  function test_InitializesVertexPolicy() public {
    VertexPolicy _policy = lens.computeVertexPolicyAddress("NewProject", address(policyLogic), address(factory));

    assertEq(address(_policy).code.length, 0);
    deployVertex();
    assertGt(address(_policy).code.length, 0);

    PolicyGrantData[] memory policies = getDefaultPolicies();
    vm.expectRevert("Initializable: contract is already initialized");
    _policy.initialize("Test", policies, policySVG);
  }

  function test_DeploysVertexCore() public {
    VertexCore _vertex = lens.computeVertexCoreAddress("NewProject", address(coreLogic), address(factory));
    assertEq(address(_vertex).code.length, 0);
    deployVertex();
    assertGt(address(_vertex).code.length, 0);
    assertGt(address(_vertex.policy()).code.length, 0);
    VertexCore(address(_vertex)).name(); // Sanity check that this doesn't revert.
    VertexCore(address(_vertex.policy())).name(); // Sanity check that this doesn't revert.
  }

  function test_InitializesVertexCore() public {
    VertexCore _vertex = deployVertex();
    assertEq(_vertex.name(), "NewProject");

    (Strategy[] memory strategies, string[] memory accounts,) = getDefaultVertexDeployParameters();
    VertexPolicy _policy = _vertex.policy();
    vm.expectRevert("Initializable: contract is already initialized");
    _vertex.initialize("NewProject", _policy, strategyLogic, accountLogic, strategies, accounts);
  }

  function test_SetsVertexCoreAddressOnThePolicy() public {
    VertexCore _vertex = deployVertex();
    VertexPolicy _policy = _vertex.policy();
    VertexCore _vertexFromPolicy = VertexCore(_policy.vertex());
    assertEq(address(_vertexFromPolicy), address(_vertex));
  }

  function test_SetsPolicyAddressOnVertexCore() public {
    VertexPolicy computedPolicy = lens.computeVertexPolicyAddress("NewProject", address(policyLogic), address(factory));
    VertexCore _vertex = deployVertex();
    assertEq(address(_vertex.policy()), address(computedPolicy));
  }

  function test_EmitsVertexCreatedEvent() public {
    vm.expectEmit(true, true, true, true);
    VertexCore computedVertex = lens.computeVertexCoreAddress("NewProject", address(coreLogic), address(factory));
    VertexPolicy computedPolicy = lens.computeVertexPolicyAddress("NewProject", address(policyLogic), address(factory));
    emit VertexCreated(1, "NewProject", address(computedVertex), address(computedPolicy));
    deployVertex();
  }

  function test_ReturnsAddressOfTheNewVertexCoreContract() public {
    VertexCore computedVertex = lens.computeVertexCoreAddress("NewProject", address(coreLogic), address(factory));
    VertexCore newVertex = deployVertex();
    assertEq(address(newVertex), address(computedVertex));
    assertEq(address(computedVertex), VertexPolicy(computedVertex.policy()).vertex());
    assertEq(address(computedVertex), VertexPolicy(newVertex.policy()).vertex());
  }
}

contract Integration is VertexFactoryTest {
  string[] initialAccounts;
  PermissionMetadata[] emptyPermissions;
  address user1 = address(0x1); // admin
  address user2 = address(0x2); // empty policy

  function test_DeploysInstanceWithFullySpecificiedStrategiesAndPolicies() public {
    // compute core, policy, and account contract addresses
    initialAccounts.push("Integration Test Account");
    VertexCore computedVertexCore =
      lens.computeVertexCoreAddress("Integration Test", address(coreLogic), address(factory));
    VertexPolicy computedVertexPolicy =
      lens.computeVertexPolicyAddress("Integration Test", address(policyLogic), address(factory));
    VertexAccount computedVertexAccount =
      lens.computeVertexAccountAddress(address(accountLogic), initialAccounts[0], address(computedVertexCore));

    // compute strategy data and strategy addresses
    Strategy memory strategyData = buildStrategyData();
    VertexStrategy computedStrategy =
      lens.computeVertexStrategyAddress(address(strategyLogic), strategyData, address(computedVertexCore));

    // compute new weights and permission metadata
    PermissionMetadata[] memory permissionMetadata =
      buildNewWeightsAndPermissions(computedVertexAccount, computedStrategy, computedVertexPolicy);
    // strategyData.approvalWeightByPermission = newWeights;
    // strategyData.disapprovalWeightByPermission = newWeights;

    // compute initial strategies and policy data
    Strategy[] memory initialStrategies = buildInitialStrategies(strategyData);
    PolicyGrantData[] memory initialPolicies = buildInitialPolicies(permissionMetadata);

    // deploy the instance
    vm.prank(address(core));

    vm.expectEmit(true, true, true, true);
    emit VertexCreated(1, "Integration Test", address(computedVertexCore), address(computedVertexPolicy));
    emit StrategyAuthorized(computedStrategy, strategyData);
    emit AccountAuthorized(computedVertexAccount, initialAccounts[0]);
    emit PolicyAdded(initialPolicies[0]);
    emit PolicyAdded(initialPolicies[1]);

    VertexCore newVertex = factory.deploy("Integration Test", initialStrategies, initialAccounts, initialPolicies);

    assertEq(address(newVertex), address(computedVertexCore));
    assertEq(address(newVertex.policy()), address(computedVertexPolicy));
  }

  function buildStrategyData() public view returns (Strategy memory strategy) {
    // return Strategy(
    //   1 days, // The length of time of the approval period.
    //   1 days, // The length of time of the queuing period. The disapproval period is the queuing period when enabled.
    //   1 days, // The length of time an action can be executed before it expires.
    //   5000, // Minimum percentage of total approval weight / total approval supply.
    //   5000, // Minimum percentage of total disapproval weight / total disapproval supply.
    //   emptyWeights, // List of permissionIds and weights that define the validation process for
    //     // approval.
    //   emptyWeights, // List of permissionIds and weights that define the validation process for
    //     // disapproval.
    //   false // Determines if an action be queued before approvalEndTime.
    // );
  }

  function buildNewWeightsAndPermissions(
    VertexAccount computedVertexAccount,
    VertexStrategy computedStrategy,
    VertexPolicy computedVertexPolicy
  ) public view returns (PermissionMetadata[] memory) {
    PermissionData memory approveERC20Permission =
      PermissionData(address(computedVertexAccount), computedVertexAccount.approveERC20.selector, computedStrategy);
    PermissionData memory transferERC20Permission =
      PermissionData(address(computedVertexAccount), computedVertexAccount.transferERC20.selector, computedStrategy);
    PermissionData memory revokePolicyPermission =
      PermissionData(address(computedVertexPolicy), computedVertexPolicy.batchRevokePolicies.selector, computedStrategy);
    bytes32 permissionId1 = lens.computePermissionId(approveERC20Permission);
    bytes32 permissionId2 = lens.computePermissionId(transferERC20Permission);
    bytes32 permissionId3 = lens.computePermissionId(revokePolicyPermission);

    PermissionMetadata[] memory permissionMetadata = new PermissionMetadata[](3);
    {
      permissionMetadata[0] = PermissionMetadata(permissionId1, 0);
      permissionMetadata[1] = PermissionMetadata(permissionId2, 0);
      permissionMetadata[1] = PermissionMetadata(permissionId3, 0);
    }
    return permissionMetadata;
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
