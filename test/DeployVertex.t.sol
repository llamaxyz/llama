// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {DeployVertex} from "script/DeployVertex.s.sol";
import {PermissionData} from "src/lib/Structs.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

contract DeployVertexTest is Test {
  DeployVertex script;

  function setUp() virtual public {
    script = new DeployVertex();
  }
}

contract Run is DeployVertexTest {
  // function setUp() override public {
  //   super.setUp();
  //   script.run();
  // }
  function test_DeploysFactory() public {
    VertexFactory factory = script.factory();
    assertEq(address(factory), address(0));

    script.run();

    factory = script.factory();
    assertNotEq(address(factory), address(0));
    assertEq(address(factory.VERTEX_CORE_LOGIC()), address(script.coreLogic()));
    assertEq(address(factory.VERTEX_POLICY_LOGIC()), address(script.policyLogic()));
    assertEq(factory.authorizedStrategyLogics(address(script.strategyLogic())), true);
    assertEq(factory.authorizedAccountLogics(address(script.accountLogic())), true);
  }

  function test_DeploysRootVertex() public {
    // ROOT_VERTEX
    // vertexCount
    vm.recordLogs();
    script.run();
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();
    VertexFactory factory = script.factory();
    VertexCore rootVertex = factory.ROOT_VERTEX();
    assertEq(rootVertex.name(), "Root Vertex");

    // There are two strategies we expect to have been deployed.
    VertexStrategy[] memory strategiesAuthorized = new VertexStrategy[](2);
    uint8 strategiesCount;
    bytes32 strategiesAuthorizedSig = keccak256("StrategyAuthorized(address,address,(uint256,uint256,uint256,uint256,uint256,bool,uint8,uint8,uint8[],uint8[]))");

    // There are two accounts we expect to have been deployed.
    VertexAccount[] memory accountsAuthorized = new VertexAccount[](2);
    uint8 accountsCount;
    bytes32 accountAuthorizedSig = keccak256("AccountAuthorized(address,address,string)");

    Vm.Log memory _event;
    for (uint256 i; i < emittedEvents.length; i++) {
      _event = emittedEvents[i];
      if (_event.topics[0] == strategiesAuthorizedSig) {
        // event StrategyAuthorized(
        //   VertexStrategy indexed strategy,  <-- The topic we want.
        //   address indexed strategyLogic,
        //   Strategy strategyData
        // );
        address strategy = address(uint160(uint256(_event.topics[1])));
        strategiesAuthorized[strategiesCount++] = VertexStrategy(strategy);
      }
      if (_event.topics[0] == accountAuthorizedSig) {
        // event AccountAuthorized(
        //   VertexAccount indexed account,  <-- The topic we want.
        //   address indexed accountLogic,
        //   string name
        // );
        address account = address(uint160(uint256(_event.topics[1])));
        accountsAuthorized[accountsCount++] = VertexAccount(account);
      }
    }

    VertexStrategy firstStrategy = strategiesAuthorized[0];
    assertEq(rootVertex.authorizedStrategies(firstStrategy), true);
    assertEq(firstStrategy.approvalPeriod(), 172_800);
    assertEq(firstStrategy.approvalRole(), 3);
    assertEq(firstStrategy.disapprovalRole(), 4);
    assertEq(firstStrategy.expirationPeriod(), 691_200);
    assertEq(firstStrategy.isFixedLengthApprovalPeriod(), true);
    assertEq(firstStrategy.minApprovalPct(), 4_000);
    assertEq(firstStrategy.minDisapprovalPct(), 2_000);
    assertEq(firstStrategy.queuingPeriod(), 345_600);
    assertEq(firstStrategy.forceApprovalRole(2), false);
    assertEq(firstStrategy.forceDisapprovalRole(2), false);

    VertexStrategy secondStrategy = strategiesAuthorized[1];
    assertEq(rootVertex.authorizedStrategies(secondStrategy), true);
    assertEq(secondStrategy.approvalPeriod(), 172_800);
    assertEq(secondStrategy.approvalRole(), 3);
    assertEq(secondStrategy.disapprovalRole(), 4);
    assertEq(secondStrategy.expirationPeriod(), 86_400);
    assertEq(secondStrategy.isFixedLengthApprovalPeriod(), false);
    assertEq(secondStrategy.minApprovalPct(), 8_000);
    assertEq(secondStrategy.minDisapprovalPct(), 10_001);
    assertEq(secondStrategy.queuingPeriod(), 0);
    assertEq(secondStrategy.forceApprovalRole(2), true);
    assertEq(secondStrategy.forceDisapprovalRole(2), true);

    // TODO authorizedAccounts

    VertexPolicy rootPolicy = rootVertex.policy();
  }

  function test_DeploysCoreLogic() public {
    VertexCore coreLogic = script.coreLogic();
    assertEq(address(coreLogic), address(0));

    script.run();

    coreLogic = script.coreLogic();
    assertNotEq(address(coreLogic), address(0));
    assertEq(coreLogic.DOMAIN_TYPEHASH(), bytes32(0x8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a866));
    // TODO assert it's initialized!
  }

  function test_DeploysStrategyLogic() public {
    VertexStrategy strategyLogic = script.strategyLogic();
    assertEq(address(strategyLogic), address(0));

    script.run();

    strategyLogic = script.strategyLogic();
    assertNotEq(address(strategyLogic), address(0));
  }

  function test_DeploysAccountLogic() public {
    VertexAccount accountLogic = script.accountLogic();
    assertEq(address(accountLogic), address(0));

    script.run();

    accountLogic = script.accountLogic();
    assertNotEq(address(accountLogic), address(0));
  }

  function test_DeploysPolicyLogic() public {
    VertexPolicy policyLogic = script.policyLogic();
    assertEq(address(policyLogic), address(0));

    script.run();

    policyLogic = script.policyLogic();
    assertNotEq(address(policyLogic), address(0));
    assertEq(policyLogic.ALL_HOLDERS_ROLE(), 0);
  }

  function test_DeploysLens() public {
    VertexLens lens = script.lens();
    assertEq(address(lens), address(0));

    script.run();

    lens = script.lens();
    assertNotEq(address(lens), address(0));
    PermissionData memory permissionData = PermissionData(
      makeAddr('target'),
      bytes4(bytes32("transfer(address,uint256)")),
      VertexStrategy(makeAddr("strategy"))
    );
    assertEq(
      lens.computePermissionId(permissionData),
      bytes32(0xb015298f3f29356efa6d653f1f06c375fa6ad631144702003798f9939f8ce444)
    );
  }

  // function test_DeploysAccountsToSameAddressAccrossDifferentChains() public {
  // }

  // Once root vertex is deployed, deploy a new vertex with the factory
}
