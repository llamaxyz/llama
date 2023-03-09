// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {VertexCore} from "src/VertexCore.sol";
import {IVertexCore} from "src/interfaces/IVertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Action, Strategy, PermissionData, PolicyGrantData, PermissionMetadata} from "src/lib/Structs.sol";

contract VertexTestSetup is Test {
  // Logic contracts.
  VertexCore coreLogic;
  VertexAccount accountLogic;
  VertexPolicy policyLogic;

  // Core Protocol.
  VertexFactory factory;

  // Vertex instance.
  VertexCore core;
  VertexPolicy policy;
  VertexStrategy strategy1;
  VertexStrategy strategy2;
  VertexAccount account1;
  VertexAccount account2;

  // Mock protocol for action targets.
  ProtocolXYZ public mockProtocol;

  function setUp() public virtual {
    // Deploy logic contracts.
    coreLogic = new VertexCore();
    accountLogic = new VertexAccount();
    policyLogic = new VertexPolicy();

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
    new VertexFactory(coreLogic, accountLogic, policyLogic, "Root Vertex", "RVTX", strategies, accounts, new PolicyGrantData[](0));
    core = factory.rootVertex();
    policy = core.policy();

    // Set vertex account addresses.
    for (uint256 i; i < accounts.length; i++) {
      bytes32 salt = keccak256(abi.encode(accounts[i]));
      address account = Clones.predictDeterministicAddress(address(accountLogic), salt, address(core));
      if (i == 0) account1 = VertexAccount(payable(account));
      if (i == 1) account2 = VertexAccount(payable(account));
    }

    // Deploy mock protocol that uses VertexCore as the admin.
    mockProtocol = new ProtocolXYZ(address(core));

    // Verify that all storage variables were initialized. Standard assertions are in `setUp` are
    // not well supported by the Forge test runner, so we use require statements instead.
    require(address(coreLogic) != address(0), "coreLogic not set");
    require(address(accountLogic) != address(0), "accountLogic not set");
    require(address(factory) != address(0), "factory not set");
    require(address(core) != address(0), "core not set");
    require(address(policy) != address(0), "policy not set");
    // require(address(strategy1) != address(0), "strategy1 not set");
    // require(address(strategy2) != address(0), "strategy2 not set");
    require(address(account1) != address(0), "account1 not set");
    require(address(account2) != address(0), "account2 not set");
    require(address(mockProtocol) != address(0), "mockProtocol not set");
  }
}
