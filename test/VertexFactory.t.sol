// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Solarray} from "solarray/Solarray.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {ERC20Mock} from "@openzeppelin/mocks/ERC20Mock.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexCore} from "src/VertexCore.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {Action, RoleHolderData, RolePermissionData, Strategy, PermissionData} from "src/lib/Structs.sol";
import {VertexTestSetup, Roles} from "test/utils/VertexTestSetup.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {SolarrayVertex} from "test/utils/SolarrayVertex.sol";

contract VertexFactoryTest is VertexTestSetup {
  uint128 constant DEFAULT_WEIGHT = 1;

  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicy);
  event StrategyAuthorized(VertexStrategy indexed strategy, address indexed strategyLogic, Strategy strategyData);
  event AccountAuthorized(VertexAccount indexed account, address indexed accountLogic, string name);
  event PolicyTokenURIUpdated(VertexPolicyTokenURI indexed vertexPolicyTokenURI);

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
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 weight, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 weight, string reason);
  event StrategiesAuthorized(Strategy[] strategies);
  event StrategiesUnauthorized(VertexStrategy[] strategies);
  event StrategyLogicAuthorized(VertexStrategy indexed strategyLogic);
  event AccountLogicAuthorized(VertexAccount indexed accountLogic);
}

contract Constructor is VertexFactoryTest {
  function deployVertexFactory() internal returns (VertexFactory) {
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account 1", "Account 2", "Account 3");

    RoleDescription[] memory roleDescriptionStrings = SolarrayVertex.roleDescription(
      "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
    );
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    return new VertexFactory(
      coreLogic,
      strategyLogic,
      accountLogic,
      policyLogic,
      policyTokenURI,
      "Root Vertex",
      strategies,
      accounts,
      roleDescriptionStrings,
      roleHolders,
      new RolePermissionData[](0)
    );
  }

  function test_SetsVertexCoreLogicAddress() public {
    assertEq(address(factory.VERTEX_CORE_LOGIC()), address(coreLogic));
  }

  function test_SetsVertexPolicyLogicAddress() public {
    assertEq(address(factory.VERTEX_POLICY_LOGIC()), address(policyLogic));
  }

  function test_SetsVertexPolicyTokenURIAddress() public {
    assertEq(address(factory.vertexPolicyTokenURI()), address(policyTokenURI));
  }

  function test_EmitsPolicyTokenURIUpdatedEvent() public {
    vm.expectEmit();
    emit PolicyTokenURIUpdated(policyTokenURI);
    deployVertexFactory();
  }

  function test_SetsVertexStrategyLogicAddress() public {
    assertTrue(factory.authorizedStrategyLogics(strategyLogic));
  }

  function test_EmitsStrategyLogicAuthorizedEvent() public {
    vm.expectEmit();
    emit StrategyLogicAuthorized(strategyLogic);
    deployVertexFactory();
  }

  function test_SetsVertexAccountLogicAddress() public {
    assertTrue(factory.authorizedAccountLogics(accountLogic));
  }

  function test_EmitsAccountLogicAuthorizedEvent() public {
    vm.expectEmit();
    emit AccountLogicAuthorized(accountLogic);
    deployVertexFactory();
  }

  function test_SetsRootVertexAddress() public {
    assertEq(address(factory.ROOT_VERTEX()), address(rootCore));
  }

  function test_DeploysRootVertexViaInternalDeployMethod() public {
    // The internal `_deploy` method is tested in the `Deploy` contract, so here we just check
    // one side effect of that method as a sanity check it was called. If it was called, the
    // vertex count should no longer be zero.
    assertEq(factory.vertexCount(), 2);
  }
}

contract Deploy is VertexFactoryTest {
  function deployVertex() internal returns (VertexCore) {
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    RoleDescription[] memory roleDescriptionStrings = SolarrayVertex.roleDescription(
      "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
    );
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(rootCore));
    return factory.deploy(
      "NewProject",
      strategyLogic,
      accountLogic,
      strategies,
      accounts,
      roleDescriptionStrings,
      roleHolders,
      new RolePermissionData[](0)
    );
  }

  function test_RevertIf_CalledByAccountThatIsNotRootVertex(address caller) public {
    vm.assume(caller != address(rootCore));
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(caller));
    vm.expectRevert(VertexFactory.OnlyVertex.selector);
    factory.deploy(
      "NewProject",
      strategyLogic,
      accountLogic,
      strategies,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0)
    );
  }

  function test_RevertIf_InstanceDeployedWithSameName(string memory name) public {
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    RoleDescription[] memory roleDescriptionStrings = SolarrayVertex.roleDescription(
      "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
    );
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(rootCore));
    factory.deploy(
      name,
      strategyLogic,
      accountLogic,
      strategies,
      accounts,
      roleDescriptionStrings,
      roleHolders,
      new RolePermissionData[](0)
    );

    vm.expectRevert();
    factory.deploy(
      name,
      strategyLogic,
      accountLogic,
      strategies,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0)
    );
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
  }

  function test_InitializesVertexPolicy() public {
    VertexPolicy _policy = lens.computeVertexPolicyAddress("NewProject", address(policyLogic), address(factory));

    assertEq(address(_policy).code.length, 0);
    deployVertex();
    assertGt(address(_policy).code.length, 0);

    vm.expectRevert("Initializable: contract is already initialized");
    _policy.initialize("Test", new RoleDescription[](0), new RoleHolderData[](0), new RolePermissionData[](0));
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

    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");

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
    vm.expectEmit();
    VertexCore computedVertex = lens.computeVertexCoreAddress("NewProject", address(coreLogic), address(factory));
    VertexPolicy computedPolicy = lens.computeVertexPolicyAddress("NewProject", address(policyLogic), address(factory));
    emit VertexCreated(2, "NewProject", address(computedVertex), address(computedPolicy));
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

contract AuthorizeStrategyLogic is VertexFactoryTest {
  function testFuzz_RevertIf_CallerIsNotVertex(address _caller) public {
    vm.assume(_caller != address(rootCore));
    vm.expectRevert(VertexFactory.OnlyVertex.selector);
    vm.prank(_caller);
    factory.authorizeStrategyLogic(VertexStrategy(randomLogicAddress));
  }

  function test_SetsValueInStorageMappingToTrue() public {
    assertEq(factory.authorizedStrategyLogics(VertexStrategy(randomLogicAddress)), false);
    vm.prank(address(rootCore));
    factory.authorizeStrategyLogic(VertexStrategy(randomLogicAddress));
    assertEq(factory.authorizedStrategyLogics(VertexStrategy(randomLogicAddress)), true);
  }

  function test_EmitsStrategyLogicAuthorizedEvent() public {
    vm.prank(address(rootCore));
    vm.expectEmit();
    emit StrategyLogicAuthorized(VertexStrategy(randomLogicAddress));
    factory.authorizeStrategyLogic(VertexStrategy(randomLogicAddress));
  }
}

contract AuthorizeAccountLogic is VertexFactoryTest {
  function test_RevertIf_CallerIsNotVertex(address _caller) public {
    vm.assume(_caller != address(rootCore));
    vm.expectRevert(VertexFactory.OnlyVertex.selector);
    vm.prank(_caller);
    factory.authorizeAccountLogic(VertexAccount(randomLogicAddress));
  }

  function test_SetsValueInStorageMappingToTrue() public {
    assertEq(factory.authorizedAccountLogics(VertexAccount(randomLogicAddress)), false);
    vm.prank(address(rootCore));
    factory.authorizeAccountLogic(VertexAccount(randomLogicAddress));
    assertEq(factory.authorizedAccountLogics(VertexAccount(randomLogicAddress)), true);
  }

  function test_EmitsAccountLogicAuthorizedEvent() public {
    vm.prank(address(rootCore));
    vm.expectEmit();
    emit AccountLogicAuthorized(VertexAccount(randomLogicAddress));
    factory.authorizeAccountLogic(VertexAccount(randomLogicAddress));
  }
}

contract SetPolicyTokenURI is VertexFactoryTest {
  function testFuzz_RevertIf_NotCalledByVertex(address _caller, address _policyTokenURI) public {
    vm.assume(_caller != address(rootCore));
    vm.prank(address(_caller));
    vm.expectRevert(VertexFactory.OnlyVertex.selector);
    factory.setPolicyTokenURI(VertexPolicyTokenURI(_policyTokenURI));
  }

  function testFuzz_WritesMetadataAddressToStorage(address _policyTokenURI) public {
    vm.prank(address(rootCore));
    vm.expectEmit();
    emit PolicyTokenURIUpdated(VertexPolicyTokenURI(_policyTokenURI));
    factory.setPolicyTokenURI(VertexPolicyTokenURI(_policyTokenURI));
    assertEq(address(factory.vertexPolicyTokenURI()), _policyTokenURI);
  }
}

contract TokenURI is VertexFactoryTest {
  function testFuzz_ProxiesToMetadataContract(uint256 _tokenId) public {
    (string memory _color, string memory _logo) = policyTokenURIParamRegistry.getMetadata(mpCore);
    assertEq(
      factory.tokenURI(mpCore, mpPolicy.name(), mpPolicy.symbol(), _tokenId),
      policyTokenURI.tokenURI(mpPolicy.name(), mpPolicy.symbol(), _tokenId, _color, _logo)
    );
  }
}
