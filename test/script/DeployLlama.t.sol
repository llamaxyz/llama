// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {DeployLlama} from "script/DeployLlama.s.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {RoleCheckpoints} from "src/lib/RoleCheckpoints.sol";
import {PermissionData} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaRelativeQuorum} from "src/strategies/LlamaRelativeQuorum.sol";

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

    assertFalse(address(factory) == address(0));
    assertEq(address(factory.LLAMA_CORE_LOGIC()), address(coreLogic));
    assertEq(address(factory.LLAMA_POLICY_LOGIC()), address(policyLogic));
    assertEq(address(factory.LLAMA_POLICY_METADATA_LOGIC()), address(policyMetadataLogic));
  }

  function test_DeploysRootLlama() public {
    vm.recordLogs();
    DeployLlama.run();
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();

    assertEq(factory.llamaCount(), 1);
    LlamaCore rootLlamaCore = factory.ROOT_LLAMA_CORE();
    LlamaExecutor rootLlamaExecutor = factory.ROOT_LLAMA_EXECUTOR();
    assertEq(rootLlamaCore.name(), "Root Llama");
    assertEq(rootLlamaCore.authorizedAccountLogics(accountLogic), true);

    // There are three strategies we expect to have been deployed.
    ILlamaStrategy[] memory strategiesAuthorized = new ILlamaStrategy[](3);
    uint8 strategiesCount;
    bytes32 strategiesAuthorizedSig = keccak256("StrategyCreated(address,address,bytes)");

    // There are two accounts we expect to have been deployed.
    LlamaAccount[] memory accountsAuthorized = new LlamaAccount[](2);
    uint8 accountsCount;
    bytes32 accountAuthorizedSig = keccak256("AccountCreated(address,address,bytes)");

    Vm.Log memory _event;
    for (uint256 i = 0; i < emittedEvents.length; i++) {
      _event = emittedEvents[i];
      if (_event.topics[0] == strategiesAuthorizedSig) {
        // event StrategyAuthorized(
        //   ILlamaStrategy strategy,  <-- The field we want.
        //   ILlamaStrategy indexed strategyLogic,
        //   bytes initializationData
        // );
        (address strategy,) = abi.decode(_event.data, (address, bytes));
        strategiesAuthorized[strategiesCount++] = ILlamaStrategy(strategy);
      }
      if (_event.topics[0] == accountAuthorizedSig) {
        // event AccountCreated(
        //   ILlamaAccount account,  <-- The topic we want.
        //   ILlamaAccount indexed accountLogic,
        //   bytes initializationData
        // );
        (address account,) = abi.decode(_event.data, (address, bytes));
        accountsAuthorized[accountsCount++] = LlamaAccount(payable(account));
      }
    }

    ILlamaStrategy firstStrategy = strategiesAuthorized[0];
    assertEqStrategyStatus(rootLlamaCore, firstStrategy, true, true);
    assertEq(toRelativeQuorum(firstStrategy).approvalPeriod(), 172_800);
    assertEq(toRelativeQuorum(firstStrategy).approvalRole(), 1);
    assertEq(toRelativeQuorum(firstStrategy).disapprovalRole(), 3);
    assertEq(toRelativeQuorum(firstStrategy).expirationPeriod(), 691_200);
    assertEq(toRelativeQuorum(firstStrategy).isFixedLengthApprovalPeriod(), true);
    assertEq(toRelativeQuorum(firstStrategy).minApprovalPct(), 4000);
    assertEq(toRelativeQuorum(firstStrategy).minDisapprovalPct(), 5100);
    assertEq(toRelativeQuorum(firstStrategy).queuingPeriod(), 345_600);
    assertEq(toRelativeQuorum(firstStrategy).forceApprovalRole(1), false);
    assertEq(toRelativeQuorum(firstStrategy).forceDisapprovalRole(1), false);

    ILlamaStrategy secondStrategy = strategiesAuthorized[1];
    assertEqStrategyStatus(rootLlamaCore, secondStrategy, true, true);
    assertEq(toRelativeQuorum(secondStrategy).approvalPeriod(), 172_800);
    assertEq(toRelativeQuorum(secondStrategy).approvalRole(), 2);
    assertEq(toRelativeQuorum(secondStrategy).disapprovalRole(), 3);
    assertEq(toRelativeQuorum(secondStrategy).expirationPeriod(), 691_200);
    assertEq(toRelativeQuorum(secondStrategy).isFixedLengthApprovalPeriod(), true);
    assertEq(toRelativeQuorum(secondStrategy).minApprovalPct(), 4000);
    assertEq(toRelativeQuorum(secondStrategy).minDisapprovalPct(), 5100);
    assertEq(toRelativeQuorum(secondStrategy).queuingPeriod(), 345_600);
    assertEq(toRelativeQuorum(secondStrategy).forceApprovalRole(1), false);
    assertEq(toRelativeQuorum(secondStrategy).forceDisapprovalRole(1), false);

    ILlamaStrategy thirdStrategy = strategiesAuthorized[2];
    assertEqStrategyStatus(rootLlamaCore, thirdStrategy, true, true);
    assertEq(toRelativeQuorum(thirdStrategy).approvalPeriod(), 172_800);
    assertEq(toRelativeQuorum(thirdStrategy).approvalRole(), 2);
    assertEq(toRelativeQuorum(thirdStrategy).disapprovalRole(), 3);
    assertEq(toRelativeQuorum(thirdStrategy).expirationPeriod(), 86_400);
    assertEq(toRelativeQuorum(thirdStrategy).isFixedLengthApprovalPeriod(), false);
    assertEq(toRelativeQuorum(thirdStrategy).minApprovalPct(), 8000);
    assertEq(toRelativeQuorum(thirdStrategy).minDisapprovalPct(), 10_001);
    assertEq(toRelativeQuorum(thirdStrategy).queuingPeriod(), 0);
    assertEq(toRelativeQuorum(thirdStrategy).forceApprovalRole(1), true);
    assertEq(toRelativeQuorum(thirdStrategy).forceDisapprovalRole(1), true);

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
    assertEq(rootPolicy.numRoles(), 8);

    address initRoleHolder = makeAddr("randomLogicAddress");
    uint8 approverRoleId = 2;
    assertEq(rootPolicy.hasRole(initRoleHolder, approverRoleId), true);
    RoleCheckpoints.History memory balances = rootPolicy.roleBalanceCheckpoints(initRoleHolder, approverRoleId);
    RoleCheckpoints.Checkpoint memory checkpoint = balances._checkpoints[0];
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

    assertFalse(address(coreLogic) == address(0));
  }

  function test_DeploysStrategyLogic() public {
    assertEq(address(relativeQuorumLogic), address(0));

    DeployLlama.run();

    assertFalse(address(relativeQuorumLogic) == address(0));
  }

  function test_DeploysAccountLogic() public {
    assertEq(address(accountLogic), address(0));

    DeployLlama.run();

    assertFalse(address(accountLogic) == address(0));
  }

  function test_DeploysPolicyLogic() public {
    assertEq(address(policyLogic), address(0));

    DeployLlama.run();

    assertFalse(address(policyLogic) == address(0));
    assertEq(policyLogic.ALL_HOLDERS_ROLE(), 0);
  }

  function test_DeploysPolicyMetadata() public {
    assertEq(address(policyMetadataLogic), address(0));

    DeployLlama.run();

    assertFalse(address(policyMetadataLogic) == address(0));
    assertFalse(keccak256(abi.encode(policyMetadataLogic.tokenURI("MyLlama", 42))) == keccak256(abi.encode("")));
  }

  function test_DeploysLens() public {
    assertEq(address(lens), address(0));

    DeployLlama.run();

    assertFalse(address(lens) == address(0));
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

  function toRelativeQuorum(ILlamaStrategy strategy) internal pure returns (LlamaRelativeQuorum converted) {
    assembly {
      converted := strategy
    }
  }

  function assertEqStrategyStatus(
    LlamaCore core,
    ILlamaStrategy strategy,
    bool expectedDeployed,
    bool expectedAuthorized
  ) internal {
    (bool deployed, bool authorized) = core.strategies(strategy);
    assertEq(deployed, expectedDeployed);
    assertEq(authorized, expectedAuthorized);
  }
}
