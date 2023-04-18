// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {Checkpoints} from "src/lib/Checkpoints.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {DeployVertex} from "script/DeployVertex.s.sol";
import {PermissionData} from "src/lib/Structs.sol";

contract DeployVertexTest is Test, DeployVertex {
  function setUp() public virtual {}
}

contract Run is DeployVertexTest {
  // This is the address that we're using with the CreateAction script to
  // automate action creation to deploy new Vertex instances. It could be
  // replaced with any address that we hold the private key for.
  address VERTEX_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  function test_DeploysFactory() public {
    assertEq(address(factory), address(0));

    DeployVertex.run();

    assertNotEq(address(factory), address(0));
    assertEq(address(factory.VERTEX_CORE_LOGIC()), address(coreLogic));
    assertEq(address(factory.VERTEX_POLICY_LOGIC()), address(policyLogic));
    assertEq(factory.authorizedStrategyLogics(strategyLogic), true);
    assertEq(factory.authorizedAccountLogics(accountLogic), true);
  }

  function test_DeploysRootVertex() public {
    vm.recordLogs();
    DeployVertex.run();
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();

    assertEq(factory.vertexCount(), 1);
    VertexCore rootVertex = factory.ROOT_VERTEX();
    assertEq(rootVertex.name(), "Root Vertex");

    // There are two strategies we expect to have been deployed.
    VertexStrategy[] memory strategiesAuthorized = new VertexStrategy[](2);
    uint8 strategiesCount;
    bytes32 strategiesAuthorizedSig = keccak256(
      "StrategyAuthorized(address,address,(uint256,uint256,uint256,uint256,uint256,bool,uint8,uint8,uint8[],uint8[]))"
    );

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
        address payable account = payable(address(uint160(uint256(_event.topics[1]))));
        accountsAuthorized[accountsCount++] = VertexAccount(account);
      }
    }

    VertexStrategy firstStrategy = strategiesAuthorized[0];
    assertEq(rootVertex.authorizedStrategies(firstStrategy), true);
    assertEq(firstStrategy.approvalPeriod(), 172_800);
    assertEq(firstStrategy.approvalRole(), 2);
    assertEq(firstStrategy.disapprovalRole(), 3);
    assertEq(firstStrategy.expirationPeriod(), 691_200);
    assertEq(firstStrategy.isFixedLengthApprovalPeriod(), true);
    assertEq(firstStrategy.minApprovalPct(), 4000);
    assertEq(firstStrategy.minDisapprovalPct(), 2000);
    assertEq(firstStrategy.queuingPeriod(), 345_600);
    assertEq(firstStrategy.forceApprovalRole(1), false);
    assertEq(firstStrategy.forceDisapprovalRole(1), false);

    VertexStrategy secondStrategy = strategiesAuthorized[1];
    assertEq(rootVertex.authorizedStrategies(secondStrategy), true);
    assertEq(secondStrategy.approvalPeriod(), 172_800);
    assertEq(secondStrategy.approvalRole(), 2);
    assertEq(secondStrategy.disapprovalRole(), 3);
    assertEq(secondStrategy.expirationPeriod(), 86_400);
    assertEq(secondStrategy.isFixedLengthApprovalPeriod(), false);
    assertEq(secondStrategy.minApprovalPct(), 8000);
    assertEq(secondStrategy.minDisapprovalPct(), 10_001);
    assertEq(secondStrategy.queuingPeriod(), 0);
    assertEq(secondStrategy.forceApprovalRole(1), true);
    assertEq(secondStrategy.forceDisapprovalRole(1), true);

    VertexAccount firstAccount = accountsAuthorized[0];
    assertEq(firstAccount.vertex(), address(rootVertex));
    assertEq(
      keccak256(abi.encodePacked(firstAccount.name())), // Encode to compare.
      keccak256("Llama Treasury")
    );

    VertexAccount secondAccount = accountsAuthorized[1];
    assertEq(secondAccount.vertex(), address(rootVertex));
    assertEq(
      keccak256(abi.encodePacked(secondAccount.name())), // Encode to compare.
      keccak256("Llama Grants")
    );

    VertexPolicy rootPolicy = rootVertex.policy();
    assertEq(address(rootPolicy.factory()), address(factory));
    assertEq(rootPolicy.numRoles(), 8);

    address initRoleHolder = makeAddr("randomLogicAddress");
    uint8 approverRoleId = 2;
    assertEq(rootPolicy.hasRole(initRoleHolder, approverRoleId), true);
    Checkpoints.History memory balances = rootPolicy.roleBalanceCheckpoints(initRoleHolder, approverRoleId);
    Checkpoints.Checkpoint memory checkpoint = balances._checkpoints[0];
    assertEq(checkpoint.expiration, type(uint64).max);
    assertEq(checkpoint.quantity, 1);

    uint8 actionCreatorRole = 1;
    assertEq(rootPolicy.hasRole(VERTEX_INSTANCE_DEPLOYER, actionCreatorRole), true);
    balances = rootPolicy.roleBalanceCheckpoints(initRoleHolder, approverRoleId);
    checkpoint = balances._checkpoints[0];
    assertEq(checkpoint.expiration, type(uint64).max);
    assertEq(checkpoint.quantity, 1);

    bytes32 permissionId = lens.computePermissionId(PermissionData(
      address(factory), // target
      VertexFactory.deploy.selector, // selector
      secondStrategy // strategy
    ));
    assertTrue(rootPolicy.canCreateAction(actionCreatorRole, permissionId));
  }

  function test_DeploysCoreLogic() public {
    assertEq(address(coreLogic), address(0));

    DeployVertex.run();

    assertNotEq(address(coreLogic), address(0));
  }

  function test_DeploysStrategyLogic() public {
    assertEq(address(strategyLogic), address(0));

    DeployVertex.run();

    assertNotEq(address(strategyLogic), address(0));
  }

  function test_DeploysAccountLogic() public {
    assertEq(address(accountLogic), address(0));

    DeployVertex.run();

    assertNotEq(address(accountLogic), address(0));
  }

  function test_DeploysPolicyLogic() public {
    assertEq(address(policyLogic), address(0));

    DeployVertex.run();

    assertNotEq(address(policyLogic), address(0));
    assertEq(policyLogic.ALL_HOLDERS_ROLE(), 0);
  }

  function test_DeploysPolicyTokenURI() public {
    assertEq(address(policyTokenUri), address(0));

    DeployVertex.run();

    assertNotEq(address(policyTokenUri), address(0));
    assertNotEq(policyTokenUri.tokenURI("MyVertex", "MTX", 42, "teal", "https://logo.com"), "");
  }

  function test_DeploysLens() public {
    assertEq(address(lens), address(0));

    DeployVertex.run();

    assertNotEq(address(lens), address(0));
    PermissionData memory permissionData = PermissionData(
      makeAddr("target"), // Could be any address, choosing a random one.
      bytes4(bytes32("transfer(address,uint256)")),
      VertexStrategy(makeAddr("strategy"))
    );
    assertEq(
      lens.computePermissionId(permissionData),
      bytes32(0xb015298f3f29356efa6d653f1f06c375fa6ad631144702003798f9939f8ce444)
    );
  }
}
