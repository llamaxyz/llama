// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {DeployLlama} from "script/DeployLlama.s.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {Checkpoints} from "src/lib/Checkpoints.sol";
import {PermissionData} from "src/lib/Structs.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {PercentageQuorum} from "src/strategies/PercentageQuorum.sol";

contract DeployLlamaTest is Test, DeployLlama {
  function setUp() public virtual {}
}

contract Run is DeployLlamaTest {
  // This is the address that we're using with the CreateAction script to
  // automate action creation to deploy new llamaCore instances. It could be
  // replaced with any address that we hold the private key for.
  address LLAMA_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  function test_DeploysFactory() public {
    assertEq(address(factory), address(0));

    DeployLlama.run();

    assertNotEq(address(factory), address(0));
    assertEq(address(factory.LLAMA_CORE_LOGIC()), address(coreLogic));
    assertEq(address(factory.LLAMA_POLICY_LOGIC()), address(policyLogic));
    assertEq(address(factory.LLAMA_ACCOUNT_LOGIC()), address(accountLogic));
    assertEq(factory.authorizedStrategyLogics(percentageQuorumLogic), true);
  }

  function test_DeploysRootLlama() public {
    vm.recordLogs();
    DeployLlama.run();
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();

    assertEq(factory.llamaCount(), 1);
    LlamaCore rootLlamaCore = factory.ROOT_LLAMA_CORE();
    LlamaExecutor rootLlamaExecutor = factory.ROOT_LLAMA_EXECUTOR();
    assertEq(rootLlamaCore.name(), "Root Llama");

    // There are three strategies we expect to have been deployed.
    ILlamaStrategy[] memory strategiesAuthorized = new ILlamaStrategy[](3);
    uint8 strategiesCount;
    bytes32 strategiesAuthorizedSig = keccak256("StrategyAuthorized(address,address,bytes)");

    // There are two accounts we expect to have been deployed.
    LlamaAccount[] memory accountsAuthorized = new LlamaAccount[](2);
    uint8 accountsCount;
    bytes32 accountAuthorizedSig = keccak256("AccountCreated(address,string)");

    Vm.Log memory _event;
    for (uint256 i = 0; i < emittedEvents.length; i++) {
      _event = emittedEvents[i];
      if (_event.topics[0] == strategiesAuthorizedSig) {
        // event StrategyAuthorized(
        //   ILlamaStrategy indexed strategy,  <-- The topic we want.
        //   address indexed percentageQuorumLogic,
        //   Strategy strategyData
        // );
        address strategy = address(uint160(uint256(_event.topics[1])));
        strategiesAuthorized[strategiesCount++] = ILlamaStrategy(strategy);
      }
      if (_event.topics[0] == accountAuthorizedSig) {
        // event AccountAuthorized(
        //   LlamaAccount indexed account,  <-- The topic we want.
        //   string name
        // );
        address payable account = payable(address(uint160(uint256(_event.topics[1]))));
        accountsAuthorized[accountsCount++] = LlamaAccount(account);
      }
    }

    ILlamaStrategy firstStrategy = strategiesAuthorized[0];
    assertEq(rootLlamaCore.strategies(firstStrategy), true);
    assertEq(toPercentageQuorum(firstStrategy).approvalPeriod(), 172_800);
    assertEq(toPercentageQuorum(firstStrategy).approvalRole(), 1);
    assertEq(toPercentageQuorum(firstStrategy).disapprovalRole(), 3);
    assertEq(toPercentageQuorum(firstStrategy).expirationPeriod(), 691_200);
    assertEq(toPercentageQuorum(firstStrategy).isFixedLengthApprovalPeriod(), true);
    assertEq(toPercentageQuorum(firstStrategy).minApprovalPct(), 4000);
    assertEq(toPercentageQuorum(firstStrategy).minDisapprovalPct(), 5100);
    assertEq(toPercentageQuorum(firstStrategy).queuingPeriod(), 345_600);
    assertEq(toPercentageQuorum(firstStrategy).forceApprovalRole(1), false);
    assertEq(toPercentageQuorum(firstStrategy).forceDisapprovalRole(1), false);

    ILlamaStrategy secondStrategy = strategiesAuthorized[1];
    assertEq(rootLlamaCore.strategies(secondStrategy), true);
    assertEq(toPercentageQuorum(secondStrategy).approvalPeriod(), 172_800);
    assertEq(toPercentageQuorum(secondStrategy).approvalRole(), 2);
    assertEq(toPercentageQuorum(secondStrategy).disapprovalRole(), 3);
    assertEq(toPercentageQuorum(secondStrategy).expirationPeriod(), 691_200);
    assertEq(toPercentageQuorum(secondStrategy).isFixedLengthApprovalPeriod(), true);
    assertEq(toPercentageQuorum(secondStrategy).minApprovalPct(), 4000);
    assertEq(toPercentageQuorum(secondStrategy).minDisapprovalPct(), 5100);
    assertEq(toPercentageQuorum(secondStrategy).queuingPeriod(), 345_600);
    assertEq(toPercentageQuorum(secondStrategy).forceApprovalRole(1), false);
    assertEq(toPercentageQuorum(secondStrategy).forceDisapprovalRole(1), false);

    ILlamaStrategy thirdStrategy = strategiesAuthorized[2];
    assertEq(rootLlamaCore.strategies(thirdStrategy), true);
    assertEq(toPercentageQuorum(thirdStrategy).approvalPeriod(), 172_800);
    assertEq(toPercentageQuorum(thirdStrategy).approvalRole(), 2);
    assertEq(toPercentageQuorum(thirdStrategy).disapprovalRole(), 3);
    assertEq(toPercentageQuorum(thirdStrategy).expirationPeriod(), 86_400);
    assertEq(toPercentageQuorum(thirdStrategy).isFixedLengthApprovalPeriod(), false);
    assertEq(toPercentageQuorum(thirdStrategy).minApprovalPct(), 8000);
    assertEq(toPercentageQuorum(thirdStrategy).minDisapprovalPct(), 10_001);
    assertEq(toPercentageQuorum(thirdStrategy).queuingPeriod(), 0);
    assertEq(toPercentageQuorum(thirdStrategy).forceApprovalRole(1), true);
    assertEq(toPercentageQuorum(thirdStrategy).forceDisapprovalRole(1), true);

    LlamaAccount firstAccount = accountsAuthorized[0];
    assertEq(firstAccount.llamaExecutor(), address(rootLlamaExecutor));
    assertEq(
      keccak256(abi.encodePacked(firstAccount.name())), // Encode to compare.
      keccak256("Llama Treasury")
    );

    LlamaAccount secondAccount = accountsAuthorized[1];
    assertEq(secondAccount.llamaExecutor(), address(rootLlamaExecutor));
    assertEq(
      keccak256(abi.encodePacked(secondAccount.name())), // Encode to compare.
      keccak256("Llama Grants")
    );

    LlamaPolicy rootPolicy = rootLlamaCore.policy();
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
    assertEq(rootPolicy.hasRole(LLAMA_INSTANCE_DEPLOYER, actionCreatorRole), true);
    balances = rootPolicy.roleBalanceCheckpoints(initRoleHolder, approverRoleId);
    checkpoint = balances._checkpoints[0];
    assertEq(checkpoint.expiration, type(uint64).max);
    assertEq(checkpoint.quantity, 1);

    bytes32 permissionId = lens.computePermissionId(
      PermissionData(
        address(factory), // target
        LlamaFactory.deploy.selector, // selector
        thirdStrategy // strategy
      )
    );
    assertTrue(rootPolicy.canCreateAction(actionCreatorRole, permissionId));
  }

  function test_DeploysCoreLogic() public {
    assertEq(address(coreLogic), address(0));

    DeployLlama.run();

    assertNotEq(address(coreLogic), address(0));
  }

  function test_DeploysStrategyLogic() public {
    assertEq(address(percentageQuorumLogic), address(0));

    DeployLlama.run();

    assertNotEq(address(percentageQuorumLogic), address(0));
  }

  function test_DeploysAccountLogic() public {
    assertEq(address(accountLogic), address(0));

    DeployLlama.run();

    assertNotEq(address(accountLogic), address(0));
  }

  function test_DeploysPolicyLogic() public {
    assertEq(address(policyLogic), address(0));

    DeployLlama.run();

    assertNotEq(address(policyLogic), address(0));
    assertEq(policyLogic.ALL_HOLDERS_ROLE(), 0);
  }

  function test_DeploysPolicyMetadata() public {
    assertEq(address(policyMetadata), address(0));

    DeployLlama.run();

    assertNotEq(address(policyMetadata), address(0));
    assertNotEq(policyMetadata.tokenURI("MyLlama", 42, "teal", "https://logo.com"), "");
  }

  function test_DeploysLens() public {
    assertEq(address(lens), address(0));

    DeployLlama.run();

    assertNotEq(address(lens), address(0));
    PermissionData memory permissionData = PermissionData(
      makeAddr("target"), // Could be any address, choosing a random one.
      bytes4(bytes32("transfer(address,uint256)")),
      ILlamaStrategy(makeAddr("strategy"))
    );
    assertEq(
      lens.computePermissionId(permissionData),
      bytes32(0xb015298f3f29356efa6d653f1f06c375fa6ad631144702003798f9939f8ce444)
    );
  }

  function toPercentageQuorum(ILlamaStrategy strategy) internal pure returns (PercentageQuorum converted) {
    assembly {
      converted := strategy
    }
  }
}
