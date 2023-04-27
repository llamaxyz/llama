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
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {RelativeStrategy} from "src/strategies/RelativeStrategy.sol";

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
    assertEq(factory.authorizedStrategyLogics(relativeStrategyLogic), true);
  }

  function test_DeploysRootLlama() public {
    vm.recordLogs();
    DeployLlama.run();
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();

    assertEq(factory.llamaCount(), 1);
    LlamaCore rootLlama = factory.ROOT_LLAMA();
    assertEq(rootLlama.name(), "Root Llama");

    // There are two strategies we expect to have been deployed.
    ILlamaStrategy[] memory strategiesAuthorized = new ILlamaStrategy[](2);
    uint8 strategiesCount;
    bytes32 strategiesAuthorizedSig = keccak256("StrategyAuthorized(address,address,bytes)");

    // There are two accounts we expect to have been deployed.
    LlamaAccount[] memory accountsAuthorized = new LlamaAccount[](2);
    uint8 accountsCount;
    bytes32 accountAuthorizedSig = keccak256("AccountCreated(address,string)");

    Vm.Log memory _event;
    for (uint256 i; i < emittedEvents.length; i++) {
      _event = emittedEvents[i];
      if (_event.topics[0] == strategiesAuthorizedSig) {
        // event StrategyAuthorized(
        //   ILlamaStrategy indexed strategy,  <-- The topic we want.
        //   address indexed relativeStrategyLogic,
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
    assertEq(rootLlama.authorizedStrategies(firstStrategy), true);
    assertEq(toRelativeStrategy(firstStrategy).approvalPeriod(), 172_800);
    assertEq(toRelativeStrategy(firstStrategy).approvalRole(), 2);
    assertEq(toRelativeStrategy(firstStrategy).disapprovalRole(), 3);
    assertEq(toRelativeStrategy(firstStrategy).expirationPeriod(), 691_200);
    assertEq(toRelativeStrategy(firstStrategy).isFixedLengthApprovalPeriod(), true);
    assertEq(toRelativeStrategy(firstStrategy).minApprovalPct(), 4000);
    assertEq(toRelativeStrategy(firstStrategy).minDisapprovalPct(), 5100);
    assertEq(toRelativeStrategy(firstStrategy).queuingPeriod(), 345_600);
    assertEq(toRelativeStrategy(firstStrategy).forceApprovalRole(1), false);
    assertEq(toRelativeStrategy(firstStrategy).forceDisapprovalRole(1), false);

    ILlamaStrategy secondStrategy = strategiesAuthorized[1];
    assertEq(rootLlama.authorizedStrategies(secondStrategy), true);
    assertEq(toRelativeStrategy(secondStrategy).approvalPeriod(), 172_800);
    assertEq(toRelativeStrategy(secondStrategy).approvalRole(), 2);
    assertEq(toRelativeStrategy(secondStrategy).disapprovalRole(), 3);
    assertEq(toRelativeStrategy(secondStrategy).expirationPeriod(), 86_400);
    assertEq(toRelativeStrategy(secondStrategy).isFixedLengthApprovalPeriod(), false);
    assertEq(toRelativeStrategy(secondStrategy).minApprovalPct(), 8000);
    assertEq(toRelativeStrategy(secondStrategy).minDisapprovalPct(), 10_001);
    assertEq(toRelativeStrategy(secondStrategy).queuingPeriod(), 0);
    assertEq(toRelativeStrategy(secondStrategy).forceApprovalRole(1), true);
    assertEq(toRelativeStrategy(secondStrategy).forceDisapprovalRole(1), true);

    LlamaAccount firstAccount = accountsAuthorized[0];
    assertEq(firstAccount.llamaCore(), address(rootLlama));
    assertEq(
      keccak256(abi.encodePacked(firstAccount.name())), // Encode to compare.
      keccak256("Llama Treasury")
    );

    LlamaAccount secondAccount = accountsAuthorized[1];
    assertEq(secondAccount.llamaCore(), address(rootLlama));
    assertEq(
      keccak256(abi.encodePacked(secondAccount.name())), // Encode to compare.
      keccak256("Llama Grants")
    );

    LlamaPolicy rootPolicy = rootLlama.policy();
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
        secondStrategy // strategy
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
    assertEq(address(relativeStrategyLogic), address(0));

    DeployLlama.run();

    assertNotEq(address(relativeStrategyLogic), address(0));
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

  function test_DeploysPolicyTokenURI() public {
    assertEq(address(policyTokenURI), address(0));

    DeployLlama.run();

    assertNotEq(address(policyTokenURI), address(0));
    assertNotEq(policyTokenURI.tokenURI("MyLlama", "MTX", 42, "teal", "https://logo.com"), "");
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

  function toRelativeStrategy(ILlamaStrategy strategy) internal pure returns (RelativeStrategy converted) {
    assembly {
      converted := strategy
    }
  }
}
