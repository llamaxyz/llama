// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {VertexVault} from "src/vault/VertexVault.sol";
import {Strategy, WeightByPermission} from "src/utils/Structs.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract VertexVaultTest is Test {
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address public constant ETH_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Vertex system
    VertexCore public vertex;
    VertexVault public vault;

    address[] public initialPolicies;
    bytes8[][] public initialPermissions;
    // Strategy config
    uint256 public constant approvalPeriod = 14400; // 2 days in blocks
    uint256 public constant queuingDuration = 4 days;
    uint256 public constant expirationDelay = 8 days;
    bool public constant isFixedLengthApprovalPeriod = true;
    uint256 public constant minApprovalPct = 40_00;
    uint256 public constant minDisapprovalPct = 20_00;

    function setUp() public {
        // Setup strategy parameters
        WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](0);
        WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](0);
        Strategy[] memory initialStrategies = new Strategy[](2);

        initialStrategies[0] = Strategy({
            approvalPeriod: approvalPeriod,
            queuingDuration: queuingDuration,
            expirationDelay: expirationDelay,
            isFixedLengthApprovalPeriod: isFixedLengthApprovalPeriod,
            minApprovalPct: minApprovalPct,
            minDisapprovalPct: minDisapprovalPct,
            approvalWeightByPermission: approvalWeightByPermission,
            disapprovalWeightByPermission: disapprovalWeightByPermission
        });

        initialStrategies[1] = Strategy({
            approvalPeriod: approvalPeriod,
            queuingDuration: 0,
            expirationDelay: 1 days,
            isFixedLengthApprovalPeriod: false,
            minApprovalPct: 80_00,
            minDisapprovalPct: 10001,
            approvalWeightByPermission: approvalWeightByPermission,
            disapprovalWeightByPermission: disapprovalWeightByPermission
        });

        // Deploy vertex and mock protocol
        vertex = new VertexCore("ProtocolXYZ", "VXP", initialStrategies, initialPolicies, initialPermissions);
        // Set Vertex's vault
        vault = vertex.vault();
    }

    /*///////////////////////////////////////////////////////////////
                            Unit tests
    //////////////////////////////////////////////////////////////*/

    // Test that VertexVault can receive ETH
    function test_vertexVault_receiveETH() public {
        uint256 amount = 1000e18;
        assertEq(address(vault).balance, 0);

        vm.startPrank(ETH_WHALE);
        (bool success,) = address(vault).call{value: amount}("");
        assertTrue(success);
        assertEq(address(vault).balance, amount);
        vm.stopPrank();
    }

    // Test that VertexVault can receive ERC20 tokens
    function test_vertexVault_receiveERC20() public {
        uint256 amount = 1000e6;
        assertEq(USDC.balanceOf(address(vault)), 0);

        vm.startPrank(USDC_WHALE);
        USDC.transfer(address(vault), amount);
        assertEq(USDC.balanceOf(address(vault)), amount);
        vm.stopPrank();
    }
}
