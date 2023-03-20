// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicyMetadata} from "src/VertexPolicyMetadata.sol";
import {Action, Strategy, PermissionData, PolicyGrantData, PermissionMetadata} from "src/lib/Structs.sol";

contract VertexTestSetup is Test {
  // Logic contracts.
  VertexCore coreLogic;
  VertexStrategy strategyLogic;
  VertexAccount accountLogic;
  VertexPolicy policyLogic;

  // Core Protocol.
  VertexFactory factory;
  VertexPolicyMetadata policyMetadata;
  VertexLens lens;

  // Vertex instance.
  VertexCore core;
  VertexPolicy policy;
  VertexStrategy strategy1;
  VertexStrategy strategy2;
  VertexAccount account1;
  VertexAccount account2;

  // Mock protocol for action targets.
  ProtocolXYZ public mockProtocol;

  // Users.
  address actionCreator = makeAddr("action creator");
  address policyHolderPam = makeAddr("policy holder pam");
  address policyHolderPatty = makeAddr("policy holder patty");
  address policyHolderPaul = makeAddr("policy holder paul");
  address policyHolderPete = makeAddr("policy holder pete");

  // Constants.
  uint256 SELF_TOKEN_ID = uint256(uint160(address(this)));

  // Function selectors used in tests.
  bytes4 public constant PAUSE_SELECTOR = 0x02329a29; // pause(bool)
  bytes4 public constant FAIL_SELECTOR = 0xa9cc4718; // fail()
  bytes4 public constant RECEIVE_ETH_SELECTOR = 0x4185f8eb; // receiveEth()

  address randomLogicAddress = makeAddr("randomLogicAddress");

  function setUp() public virtual {
    // Deploy logic contracts.
    coreLogic = new VertexCore();
    strategyLogic = new VertexStrategy();
    accountLogic = new VertexAccount();
    policyLogic = new VertexPolicy();
    policyMetadata = new VertexPolicyMetadata();

    // Deploy lens.
    lens = new VertexLens();

    // Define two strategies.
    Strategy memory strategy1Config = Strategy({
      approvalPeriod: 2 days,
      queuingPeriod: 4 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: true,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });
    Strategy memory strategy2Config = Strategy({
      approvalPeriod: 2 days,
      queuingPeriod: 0,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 8000,
      minDisapprovalPct: 10_001,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });
    Strategy[] memory strategies = new Strategy[](2);
    strategies[0] = strategy1Config;
    strategies[1] = strategy2Config;

    // Define two accounts.
    string[] memory accounts = new string[](2);
    accounts[0] = "Root Account 1";
    accounts[1] = "Root Account 2";

    // Deploy factory. The first two arguments are protocol parameters, the rest of the args
    // configure the root vertex instance.
    factory =
    new VertexFactory(coreLogic, address(strategyLogic), address(accountLogic), policyLogic, policyMetadata, "Root Vertex", strategies, accounts, new PolicyGrantData[](0));
    core = factory.ROOT_VERTEX();
    policy = core.policy();

    // Set vertex account addresses.
    for (uint256 i; i < accounts.length; i++) {
      bytes32 salt = keccak256(abi.encode(accounts[i]));
      address account = Clones.predictDeterministicAddress(address(accountLogic), salt, address(core));
      if (i == 0) account1 = VertexAccount(payable(account));
      if (i == 1) account2 = VertexAccount(payable(account));
    }

    // Set vertex strategy addresses.
    strategy1 = lens.computeVertexStrategyAddress(address(strategyLogic), strategy1Config, address(core));
    strategy2 = lens.computeVertexStrategyAddress(address(strategyLogic), strategy2Config, address(core));

    // Deploy mock protocol that uses VertexCore as the admin.
    mockProtocol = new ProtocolXYZ(address(core));

    // Verify that all storage variables were initialized. Standard assertions are in `setUp` are
    // not well supported by the Forge test runner, so we use require statements instead.
    require(address(coreLogic) != address(0), "coreLogic not set");
    require(address(accountLogic) != address(0), "accountLogic not set");
    require(address(lens) != address(0), "lens not set");
    require(address(factory) != address(0), "factory not set");
    require(address(core) != address(0), "core not set");
    require(address(policy) != address(0), "policy not set");
    require(address(strategy1) != address(0), "strategy1 not set");
    require(address(strategy2) != address(0), "strategy2 not set");
    require(address(account1) != address(0), "account1 not set");
    require(address(account2) != address(0), "account2 not set");
    require(address(mockProtocol) != address(0), "mockProtocol not set");

    // Now we give the action creator permission to create actions.
    grantInitialPolicies();
  }

  function grantInitialPolicies() private {
    PolicyGrantData[] memory policies = getDefaultPolicies();
    vm.prank(address(core));
    policy.batchGrantPolicies(policies);
  }

  function getDefaultPolicies() internal view returns (PolicyGrantData[] memory) {
    PermissionData memory pausePermission = PermissionData(address(mockProtocol), PAUSE_SELECTOR, strategy1);
    PermissionData memory failPermission = PermissionData(address(mockProtocol), FAIL_SELECTOR, strategy1);
    PermissionData memory receiveETHPermission = PermissionData(address(mockProtocol), RECEIVE_ETH_SELECTOR, strategy1);

    PermissionMetadata[] memory creatorPermissions = new PermissionMetadata[](5);
    creatorPermissions[0] = PermissionMetadata(lens.computePermissionId(failPermission), 0);
    creatorPermissions[1] = PermissionMetadata(lens.computePermissionId(pausePermission), 0);
    creatorPermissions[2] = PermissionMetadata(lens.computePermissionId(receiveETHPermission), 0);
    creatorPermissions[3] = PermissionMetadata("approver", 0);
    creatorPermissions[4] = PermissionMetadata("disapprover", 0);

    PermissionMetadata[] memory pauserPermissions = new PermissionMetadata[](3);
    pauserPermissions[0] = PermissionMetadata(lens.computePermissionId(pausePermission), 0);
    pauserPermissions[1] = PermissionMetadata("approver", 0);
    pauserPermissions[2] = PermissionMetadata("disapprover", 0);

    PolicyGrantData[] memory policies = new PolicyGrantData[](5);
    policies[0] = PolicyGrantData(actionCreator, creatorPermissions);
    policies[1] = PolicyGrantData(policyHolderPam, pauserPermissions);
    policies[2] = PolicyGrantData(policyHolderPatty, pauserPermissions);
    policies[3] = PolicyGrantData(policyHolderPaul, pauserPermissions);
    policies[4] = PolicyGrantData(policyHolderPete, pauserPermissions);
    return policies;
  }

  function getDefaultVertexDeployParameters()
    internal
    view
    returns (Strategy[] memory, string[] memory, PolicyGrantData[] memory)
  {
    // Define two strategies.
    Strategy memory strategy1Config = Strategy({
      approvalPeriod: 2 days,
      queuingPeriod: 4 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: true,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });
    Strategy memory strategy2Config = Strategy({
      approvalPeriod: 2 days,
      queuingPeriod: 0,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 8000,
      minDisapprovalPct: 10_001,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });
    Strategy[] memory strategies = new Strategy[](2);
    strategies[0] = strategy1Config;
    strategies[1] = strategy2Config;

    // Define two accounts.
    string[] memory accounts = new string[](2);
    accounts[0] = "Root Account 1";
    accounts[1] = "Root Account 2";

    return (strategies, accounts, getDefaultPolicies());
  }
}
