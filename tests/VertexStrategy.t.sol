// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";

contract VertexStrategyTest is Test {
    function setUp() public virtual {
        // TODO shared setup
    }

    // TODO shared helpers
}

contract Constructor is VertexStrategyTest {
    function testFuzz_SetsStrategyStorageQueuingDuration(uint256 _queuingDuration) public {} // TODO

    function testFuzz_SetsStrategyStorageExpirationDelay(uint256 _expirationDelay) public {} // TODO

    function test_SetsStrategyStorageIsFixedLengthApprovalPeriodTrue() public {} // TODO

    function test_SetsStrategyStorageIsFixedLengthApprovalPeriodFalse() public {} // TODO

    function testFuzz_SetsStrategyStorageApprovalPeriod(uint256 _approvalPeriod) public {} // TODO

    function testFuzz_SetsStrategyStoragePolicy(address _policy) public {} // TODO

    function testFuzz_SetsStrategyStorageVertex(address _vertex) public {} // TODO

    function testFuzz_SetsStrategyStorageMinApprovalPct(uint256 _percent) public {} // TODO

    function testFuzz_SetsStrategyStorageMinDisapprovalPct(uint256 _percent) public {} // TODO

    function test_SetsStrategyStorageDefaultOperatorWeights() public {
        // TODO
        // assert approvalWeightByPermission[DEFAULT_OPERATOR] = 1;
        // assert disapprovalWeightByPermission[DEFAULT_OPERATOR] = 1;
    }

    function testFuzz_CanOverrideDefaultOperatorWeights(uint256 _approvalWeight, uint256 _disapprovalWeight) public {
        // TODO
        // assert that the default weights can be overridden with the fuzz weights
        // assert approvalWeightByPermission[DEFAULT_OPERATOR] = _approvalWeight;
        // assert disapprovalWeightByPermission[DEFAULT_OPERATOR] = _disapprovalWeight;
    }

    function testFuzz_SetsApprovalPermissions( /*TODO decide on fuzz params*/ ) public {
        // TODO
        // deploy with strategyConfig.approvalWeightByPermission.length > 1
        // assert approvalWeightByPermission is stored accordingly
    }

    function testFuzz_HandlesDuplicateApprovalPermissions( /*TODO decide on fuzz params*/ ) public {
        // TODO
        // deploy with strategyConfig.approvalWeightByPermission.length > 1.
        // The strategyConfig.approvalWeightByPermission array should include duplicate
        // permissions with different weights.
        // Assert that only the final weight in the array is saved.
    }

    function testFuzz_SetsDisapprovalPermissions( /*TODO decide on fuzz params*/ ) public {
        // TODO
        // deploy with strategyConfig.approvalWeightByPermission.length > 1
        // assert disapprovalWeightByPermission is stored accordingly
    }

    function testFuzz_HandlesDuplicateDisapprovalPermissions( /*TODO decide on fuzz params*/ ) public {
        // TODO
        // deploy with strategyConfig.approvalWeightByPermission.length > 1.
        // The strategyConfig.disapprovalWeightByPermission array should include duplicate
        // permissions with different weights.
        // Assert that only the final weight in the array is saved.
    }

    function testFuzz_EmitsNewStrategyCreatedEvent(address _vertex, address _policy) public {
        // TODO
        // assert emits NewStrategyCreated event
    }
}

contract IsActionPassed is VertexStrategyTest {
    function testFuzz_ReturnsTrueForPassedActions(uint256 _actionApprovals) public {
        // TODO
        // call isActionPassed on an action that has sufficient (random) num of votes
        // assert response is true
    }

    function testFuzz_ReturnsFalseForFailedActions(uint256 _actionApprovals) public {
        // TODO
        // call isActionPassed on an action that has insufficient (random) num of votes
        // assert response is false
    }

    function testFuzz_RevertsForNonExistentActionId(uint256 _actionId) public {
        // TODO
        // what if nonexistent actionId is passed in? I think this will return true
        // currently but it should probably revert
    }

    function testFuzz_RoundsCorrectly(uint256 _actionAppovals) public {
        // TODO
        // what happens if the minAppovalPct rounds the action.approvalPolicySupply
        // the wrong way?
    }
}

contract IsActionCancelationValid is VertexStrategyTest {
    function testFuzz_ReturnsTrueForDisapprovedActions(uint256 _actionDisapprovals) public {
        // TODO
        // call isActionCancelationValid on an action that has sufficient (random)
        // num of disapprovals. assert response is true
    }

    function testFuzz_ReturnsFalseForActionsNotFullyDisapproved(uint256 _actionApprovals) public {
        // TODO
        // call isActionPassed on an action that has insufficient (random) num of
        // disapprovals. assert response is false
    }

    function testFuzz_RevertsForNonExistentActionId(uint256 _actionId) public {
        // TODO
        // what if nonexistent actionId is passed in? I think this will return true
        // currently but it should probably revert
    }

    function testFuzz_RoundsCorrectly(uint256 _actionAppovals) public {
        // TODO
        // what happens if the minDisapprovalPct rounds the
        // action.disapprovalPolicySupply the wrong way?
    }
}

contract GetApprovalWeightAt is VertexStrategyTest {
    function testFuzz_ReturnsZeroWeightPriorToAccountGainingPermission(
        uint256 _blocksUntilPermission,
        bytes8 _permission,
        uint256 _weight,
        address _policyHolder
    ) public {
        // TODO
        // vm.assume(_blocksUntilPermission > 0);
        // uint _referenceBlock = block.number;
        // vm.roll(_blocksUntilPermission)
        // grant the permission to _policyHolder
        // deploy strategy that gives _weight to _permission
        // assertEq(
        //   strategy.getApprovalWeightAt(_policyHolder, _referenceBlock);
        //   0 // there should be zero weight before permission was granted
        // );
    }

    function testFuzz_ReturnsWeightAfterBlockThatAccountGainedPermission(
        uint256 _blocksSincePermission, // no assume for this param, we want 0 tested
        bytes8 _permission,
        uint256 _weight,
        address _policyHolder
    ) public {
        // TODO
        // uint _referenceBlock = block.number;
        // grant the permission to _policyHolder
        // deploy strategy that gives _weight to _permission
        // vm.roll(_blocksSincePermission)
        // assertEq(
        //   strategy.getApprovalWeightAt(_policyHolder, block.number);
        //   _weight // the account should still have the weight
        // );
    }

    function testFuzz_ReturnsZeroWeightForNonPolicyHolders(uint256 _blockNumber, address _nonPolicyHolder) public {
        // TODO
    }

    function testFuzz_ReturnsDefaultWeightForPolicyHolderWithoutExplicitWeight(uint256 _blockNumber, bytes8 _permission, address _policyHolder) public {
        // TODO
        // _policyHolder doesn't have a weight for _permission
        // the function should return the default weight
    }
}

contract GetDisapprovalWeightAt is VertexStrategyTest {
    function testFuzz_ReturnsZeroWeightPriorToAccountGainingPermission(
        uint256 _blocksUntilPermission,
        bytes8 _permission,
        uint256 _weight,
        address _policyHolder
    ) public {
        // TODO
        // vm.assume(_blocksUntilPermission > 0);
        // uint _referenceBlock = block.number;
        // vm.roll(_blocksUntilPermission)
        // grant the permission to _policyHolder
        // deploy strategy that gives _weight to _permission
        // assertEq(
        //   strategy.getDisapprovalWeightAt(_policyHolder, _referenceBlock);
        //   0 // there should be zero weight before permission was granted
        // );
    }

    function testFuzz_ReturnsWeightAfterBlockThatAccountGainedPermission(
        uint256 _blocksSincePermission, // no assume for this param, we want 0 tested
        bytes8 _permission,
        uint256 _weight,
        address _policyHolder
    ) public {
        // TODO
        // uint _referenceBlock = block.number;
        // grant the permission to _policyHolder
        // deploy strategy that gives _weight to _permission
        // vm.roll(_blocksSincePermission)
        // assertEq(
        //   strategy.getDisapprovalWeightAt(_policyHolder, block.number);
        //   _weight // the account should still have the weight
        // );
    }

    function testFuzz_ReturnsZeroWeightForNonPolicyHolders(uint256 _blockNumber, address _nonPolicyHolder) public {
        // TODO
    }

    function testFuzz_ReturnsDefaultWeightForPolicyHolderWithoutExplicitWeight(uint256 _blockNumber, bytes8 _permission, address _policyHolder) public {
        // TODO
        // _policyHolder doesn't have a weight for _permission
        // the function should return the default weight
    }
}
