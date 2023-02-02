// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {VertexCollector} from "src/vault/VertexCollector.sol";
import {Strategy, WeightByPermission} from "src/utils/Structs.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract VertexCollectorTest is Test {
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address public constant ETH_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Vertex system
    VertexCore public vertex;
    VertexCollector public collector;

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
        // Set Vertex's collector
        collector = vertex.collector();
    }

    /*///////////////////////////////////////////////////////////////
                            Unit tests
    //////////////////////////////////////////////////////////////*/

    // approve unit tests
    function test_VertexCollector_approve() public {
        uint256 amount = 1000e6;
        assertEq(USDC.balanceOf(address(collector)), 0);

        // Transfer USDC to collector
        vm.startPrank(USDC_WHALE);
        USDC.transfer(address(collector), amount);
        assertEq(USDC.balanceOf(address(collector)), amount);
        vm.stopPrank();

        uint256 vaultUSDCBalance = USDC.balanceOf(address(collector));
        uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);

        // Approve USDC to whale
        vm.startPrank(address(vertex));
        collector.approve(USDC, USDC_WHALE, amount);
        assertEq(USDC.allowance(address(collector), USDC_WHALE), amount);
        vm.stopPrank();

        // Transfer USDC from collector to whale
        vm.startPrank(USDC_WHALE);
        USDC.transferFrom(address(collector), USDC_WHALE, amount);
        assertEq(USDC.balanceOf(address(collector)), 0);
        assertEq(USDC.balanceOf(address(collector)), vaultUSDCBalance - amount);
        assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + amount);
        vm.stopPrank();
    }

    function test_VertexCollector_approve_RevertIfNotVertexMsgSender() public {
        uint256 amount = 1000e6;
        vm.expectRevert(VertexCollector.OnlyVertex.selector);
        collector.approve(USDC, USDC_WHALE, amount);
    }

    // transfer unit tests
    function test_VertexCollector_transfer_TransferETH() public {
        uint256 amount = 1000e18;
        assertEq(address(collector).balance, 0);

        // Transfer ETH to collector
        vm.startPrank(ETH_WHALE);
        (bool success,) = address(collector).call{value: amount}("");
        assertTrue(success);
        assertEq(address(collector).balance, amount);
        vm.stopPrank();

        uint256 vaultETHBalance = address(collector).balance;
        uint256 whaleETHBalance = ETH_WHALE.balance;

        // Transfer ETH from collector to whale
        vm.startPrank(address(vertex));
        collector.transfer(IERC20(collector.ETH_MOCK_ADDRESS()), ETH_WHALE, amount);
        assertEq(address(collector).balance, 0);
        assertEq(address(collector).balance, vaultETHBalance - amount);
        assertEq(ETH_WHALE.balance, whaleETHBalance + amount);
        vm.stopPrank();
    }

    function test_VertexCollector_transfer_TransferERC20() public {
        uint256 amount = 1000e6;
        assertEq(USDC.balanceOf(address(collector)), 0);

        // Transfer USDC to collector
        vm.startPrank(USDC_WHALE);
        USDC.transfer(address(collector), amount);
        assertEq(USDC.balanceOf(address(collector)), amount);
        vm.stopPrank();

        uint256 vaultUSDCBalance = USDC.balanceOf(address(collector));
        uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);

        // Transfer USDC from collector to whale
        vm.startPrank(address(vertex));
        collector.transfer(USDC, USDC_WHALE, amount);
        assertEq(USDC.balanceOf(address(collector)), 0);
        assertEq(USDC.balanceOf(address(collector)), vaultUSDCBalance - amount);
        assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + amount);
        vm.stopPrank();
    }

    function test_VertexCollector_transfer_RevertIfNotVertexMsgSender() public {
        uint256 amount = 1000e6;
        vm.expectRevert(VertexCollector.OnlyVertex.selector);
        collector.transfer(USDC, USDC_WHALE, amount);
    }

    function test_VertexCollector_transfer_RevertIfToZeroAddress() public {
        uint256 amount = 1000e6;
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexCollector.Invalid0xRecipient.selector);
        collector.transfer(USDC, address(0), amount);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            Integration tests
    //////////////////////////////////////////////////////////////*/

    // Test that VertexCollector can receive ETH
    function test_VertexCollector_ReceiveETH() public {
        uint256 amount = 1000e18;
        assertEq(address(collector).balance, 0);

        vm.startPrank(ETH_WHALE);
        (bool success,) = address(collector).call{value: amount}("");
        assertTrue(success);
        assertEq(address(collector).balance, amount);
        vm.stopPrank();
    }

    // Test that VertexCollector can receive ERC20 tokens
    function test_VertexCollector_ReceiveERC20() public {
        uint256 amount = 1000e6;
        assertEq(USDC.balanceOf(address(collector)), 0);

        vm.startPrank(USDC_WHALE);
        USDC.transfer(address(collector), amount);
        assertEq(USDC.balanceOf(address(collector)), amount);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            Helpers
    //////////////////////////////////////////////////////////////*/
}
