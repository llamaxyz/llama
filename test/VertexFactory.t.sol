// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Solarray} from "solarray/Solarray.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {ERC20Mock} from "@openzeppelin/mocks/ERC20Mock.sol";
import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexCore} from "src/VertexCore.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {DefaultStrategy} from "src/strategies/DefaultStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {Action, RoleHolderData, RolePermissionData, DefaultStrategyConfig, PermissionData} from "src/lib/Structs.sol";
import {VertexTestSetup, Roles} from "test/utils/VertexTestSetup.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {SolarrayVertex} from "test/utils/SolarrayVertex.sol";

contract VertexFactoryTest is VertexTestSetup {
  uint128 constant DEFAULT_QUANTITY = 1;

  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicy);
  event StrategyAuthorized(IVertexStrategy indexed strategy, address indexed strategyLogic, bytes initializationData);
  event AccountAuthorized(VertexAccount indexed account, address indexed accountLogic, string name);
  event PolicyTokenURIUpdated(VertexPolicyTokenURI indexed vertexPolicyTokenURI);

  event ActionCreated(
    uint256 id,
    address indexed creator,
    IVertexStrategy indexed strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes data
  );
  event ActionCanceled(uint256 id);
  event ActionQueued(
    uint256 id, address indexed caller, IVertexStrategy indexed strategy, address indexed creator, uint256 executionTime
  );
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event StrategiesAuthorized(DefaultStrategyConfig[] strategies);
  event StrategiesUnauthorized(IVertexStrategy[] strategies);
  event StrategyLogicAuthorized(IVertexStrategy indexed strategyLogic);
  event AccountLogicAuthorized(VertexAccount indexed accountLogic);
}

contract Constructor is VertexFactoryTest {
  function deployVertexFactory() internal returns (VertexFactory) {
    bytes[] memory strategyConfigs = defaultStrategyConfigs();
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
      strategyConfigs,
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

  function test_SetsVertexAccountLogicAddress() public {
    assertEq(address(factory.VERTEX_ACCOUNT_LOGIC()), address(accountLogic));
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
    bytes[] memory strategyConfigs = defaultStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    RoleDescription[] memory roleDescriptionStrings = SolarrayVertex.roleDescription(
      "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
    );
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(rootCore));
    return factory.deploy(
      "NewProject",
      strategyLogic,
      strategyConfigs,
      accounts,
      roleDescriptionStrings,
      roleHolders,
      new RolePermissionData[](0)
    );
  }

  function test_RevertIf_CallerIsNotVertex(address caller) public {
    vm.assume(caller != address(rootCore));
    bytes[] memory strategyConfigs = defaultStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(caller));
    vm.expectRevert(VertexFactory.OnlyVertex.selector);
    factory.deploy(
      "NewProject",
      strategyLogic,
      strategyConfigs,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0)
    );
  }

  function test_RevertIf_InstanceDeployedWithSameName(string memory name) public {
    bytes[] memory strategyConfigs = defaultStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    RoleDescription[] memory roleDescriptionStrings = SolarrayVertex.roleDescription(
      "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
    );
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(rootCore));
    factory.deploy(
      name, strategyLogic, strategyConfigs, accounts, roleDescriptionStrings, roleHolders, new RolePermissionData[](0)
    );

    vm.expectRevert();
    factory.deploy(
      name, strategyLogic, strategyConfigs, accounts, new RoleDescription[](0), roleHolders, new RolePermissionData[](0)
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

    bytes[] memory strategyConfigs = defaultStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");

    VertexPolicy _policy = _vertex.policy();
    vm.expectRevert("Initializable: contract is already initialized");
    _vertex.initialize("NewProject", _policy, strategyLogic, accountLogic, strategyConfigs, accounts);
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

  function test_SetsAccountLogicAddressOnVertexCore() public {
    VertexCore _vertex = deployVertex();
    assertEq(address(_vertex.vertexAccountLogic()), address(accountLogic));
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
    factory.authorizeStrategyLogic(IVertexStrategy(randomLogicAddress));
  }

  function test_SetsValueInStorageMappingToTrue() public {
    assertEq(factory.authorizedStrategyLogics(IVertexStrategy(randomLogicAddress)), false);
    vm.prank(address(rootCore));
    factory.authorizeStrategyLogic(IVertexStrategy(randomLogicAddress));
    assertEq(factory.authorizedStrategyLogics(IVertexStrategy(randomLogicAddress)), true);
  }

  function test_EmitsStrategyLogicAuthorizedEvent() public {
    vm.prank(address(rootCore));
    vm.expectEmit();
    emit StrategyLogicAuthorized(IVertexStrategy(randomLogicAddress));
    factory.authorizeStrategyLogic(IVertexStrategy(randomLogicAddress));
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
  function setTokenURIMetadata() internal {
    string memory color = "#FF0000";
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.startPrank(address(rootCore));
    policyTokenURIParamRegistry.setColor(mpCore, color);
    policyTokenURIParamRegistry.setLogo(mpCore, logo);
    vm.stopPrank();
  }

  function testFuzz_ProxiesToMetadataContract(uint256 _tokenId) public {
    setTokenURIMetadata();

    (string memory _color, string memory _logo) = policyTokenURIParamRegistry.getMetadata(mpCore);
    assertEq(
      factory.tokenURI(mpCore, mpPolicy.name(), mpPolicy.symbol(), _tokenId),
      policyTokenURI.tokenURI(mpPolicy.name(), mpPolicy.symbol(), _tokenId, _color, _logo)
    );
  }
}
