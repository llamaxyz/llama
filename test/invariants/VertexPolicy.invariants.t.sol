// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {PermissionIdCheckpoint, Strategy} from "src/lib/Structs.sol";

import {VertexCoreTest} from "test/VertexCore.t.sol";
import {BaseHandler} from "test/invariants/BaseHandler.sol";

contract VertexPolicyHandler is BaseHandler {
  // =============================
  // ======== Constructor ========
  // =============================

  constructor(VertexFactory _vertexFactory, VertexCore _vertexCore) BaseHandler(_vertexFactory, _vertexCore) {
    // TODO Set some initial permissions, each actor is a policyholder.
  }

  // ==========================
  // ======== Helpers =========
  // ==========================

  function callSummary() public view override {
    BaseHandler.callSummary();
    console2.log("vertexPolicyNFT_batchGrantPolicies      ", calls["vertexPolicyNFT_batchGrantPolicies"]);
    console2.log("vertexPolicyNFT_batchUpdatePermissions  ", calls["vertexPolicyNFT_batchUpdatePermissions"]);
    console2.log("vertexPolicyNFT_batchRevokePolicies     ", calls["vertexPolicyNFT_batchRevokePolicies"]);
    console2.log("vertexPolicyNFT_setBaseURI              ", calls["vertexPolicyNFT_setBaseURI"]);
    console2.log("-----------------------------------------------");
    console2.log("policyholdersHadBalanceOf_0      ", calls["policyholdersHadBalanceOf_0"]);
    console2.log("policyholdersHadBalanceOf_1      ", calls["policyholdersHadBalanceOf_1"]);
  }

  // =====================================
  // ======== Methods for Fuzzer =========
  // =====================================

  function vertexPolicyNFT_batchGrantPolicies() public recordCall("vertexPolicyNFT_batchGrantPolicies") {
    vm.prank(address(policy.vertex()));
    // TODO Implement this call, record all permissionIds seen with `recordPermissionId(bytes8)`
  }

  function vertexPolicyNFT_batchUpdatePermissions() public recordCall("vertexPolicyNFT_batchUpdatePermissions") {
    vm.prank(address(policy.vertex()));
    // TODO Implement this call, record all permissionIds seen with `recordPermissionId(bytes8)`
  }

  function vertexPolicyNFT_batchRevokePolicies() public recordCall("vertexPolicyNFT_batchRevokePolicies") {
    vm.prank(address(policy.vertex()));
    // TODO Implement this call, record all permissionIds seen with `recordPermissionId(bytes8)`
  }

  function vertexPolicyNFT_setBaseURI(string calldata baseURI) public recordCall("vertexPolicyNFT_setBaseURI") {
    vm.prank(address(policy.vertex()));
    policy.setBaseURI(baseURI);
  }
}

contract VertexFactoryInvariants is VertexCoreTest {
  // TODO Remove inheritance on VertexCoreTest once https://github.com/llama-community/vertex-v1/issues/38 is
  // completed. Inheriting from it now just to simplify the test setup, but ideally our invariant
  // tests would not be coupled to our unit tests in this way.

  VertexPolicyHandler public handler;

  function setUp() public override {
    VertexCoreTest.setUp();
    handler = new VertexPolicyHandler(factory, core);

    // TODO Set this up and write tests.
    targetSender(makeAddr("invariantSender")); // TODO why does removing this result in failure due to clone being
      // deployed to a sender's address?
    targetContract(address(handler));
  }

  // ======================================
  // ======== Invariant Assertions ========
  // ======================================

  // For a given permission ID and timestamp, the sum of that permission's quantity over all users
  // with that permission should equal the total supply of that permission ID.
  function assertInvariant_ForEachPermissionId_SumOfPermissionsOverAllUsersEqualsTotalSupply() public view {
    bytes32[] memory allPermissionIds = handler.getPermissionIds();
    for (uint256 i = 0; i < allPermissionIds.length; i++) {
      PermissionIdCheckpoint[] memory checkpoints = policy.getTokenPermissionSupplyCheckpoints(allPermissionIds[i]);

      for (uint256 j = 0; j < checkpoints.length; j++) {
        uint256 sumOfPermissionsOverAllUsers = 0;
        address[] memory policyholders = handler.getActors();

        for (uint256 k = 0; k < policyholders.length; k++) {
          bool hasPermission =
            policy.holderWeightAt(policyholders[k], allPermissionIds[i], checkpoints[j].timestamp) > 0;
          sumOfPermissionsOverAllUsers += hasPermission ? 1 : 0;
        }
        require(
          sumOfPermissionsOverAllUsers == checkpoints[j].quantity,
          string.concat(
            "sum of permissions over all users should equal total supply: ",
            "(permissionId, timestamp) =",
            "(",
            vm.toString(allPermissionIds[i]),
            ", ",
            vm.toString(checkpoints[j].timestamp),
            ")"
          )
        );
      }
    }
  }

  // For a given permission ID,the tokenPermissionCheckpoints array should always be sorted by
  // timestamp in ascending order, with no duplicate timestamps.
  function assertInvariant_TokenPermissionSupplyCheckpointsAreAlwaysSortedByUniqueTimestamp() public view {
    uint256[] memory allPolicyIds = handler.getPolicyIds();
    bytes32[] memory allPermissionIds = handler.getPermissionIds();
    for (uint256 i = 0; i < allPolicyIds.length; i++) {
      // The use of `<` here instead of `<=` is intentional and disallows two checkpoints
      // with the same timestamp.
      for (uint256 j = 0; j < allPermissionIds.length; j++) {
        PermissionIdCheckpoint[] memory checkpoints =
          policy.getTokenPermissionCheckpoints(allPolicyIds[i], allPermissionIds[j]);
        for (uint256 k = 1; k < checkpoints.length; k++) {
          require(
            checkpoints[k - 1].timestamp < checkpoints[k].timestamp,
            string.concat(
              "tokenPermissionCheckpoints should be sorted by timestamp: ",
              "(policyId, permissionId) =",
              "(",
              vm.toString(allPolicyIds[i]),
              ", ",
              vm.toString(allPermissionIds[j]),
              ")"
            )
          );
        }
      }
    }
  }

  // The policyId, i.e. the token ID, held by a given user should always match that user's address.
  function assertInvariant_DeterministicPolicyIds() public view {
    address[] memory policyholders = handler.getActors();
    for (uint256 i = 0; i < policyholders.length; i++) {
      if (policy.balanceOf(policyholders[i]) == 0) continue;
      uint256 expectedTokenId = uint256(uint160(policyholders[i]));
      require(policy.ownerOf(expectedTokenId) == policyholders[i], "policyId should match user address");
    }
  }

  // A user should never have more than one policy NFT.
  function assertInvariant_PolicyholdersShouldNeverHaveMoreThanOneNFT() public view {
    address[] memory policyholders = handler.getActors();
    for (uint256 i = 0; i < policyholders.length; i++) {
      require(policy.balanceOf(policyholders[i]) <= 1, "policyholders should never have more than one NFT");
    }
  }

  // =================================
  // ======== Invariant Tests ========
  // =================================

  function invariant_AllInvariants() public view {
    assertInvariant_ForEachPermissionId_SumOfPermissionsOverAllUsersEqualsTotalSupply();
    assertInvariant_TokenPermissionSupplyCheckpointsAreAlwaysSortedByUniqueTimestamp();
    assertInvariant_DeterministicPolicyIds();
    assertInvariant_PolicyholdersShouldNeverHaveMoreThanOneNFT();
  }

  function invariant_CallSummary() public {
    address[] memory policyholders = handler.getActors();
    for (uint256 i = 0; i < policyholders.length; i++) {
      uint256 balance = policy.balanceOf(policyholders[i]);
      if (balance == 0) handler.recordMetric("policyholdersHadBalanceOf_0");
      else if (balance == 1) handler.recordMetric("policyholdersHadBalanceOf_1");
      else handler.recordMetric("policyholdersHadBalanceOf_2+");
    }

    handler.callSummary();
  }
}
