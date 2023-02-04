// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {VertexCollector} from "src/collector/VertexCollector.sol";
import {Strategy, WeightByPermission} from "src/utils/Structs.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract VertexCollectorTest is Test {
    // Testing Parameters
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    uint256 public constant USDC_AMOUNT = 1000e6;

    address public constant ETH_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    uint256 public constant ETH_AMOUNT = 1000e18;

    // Vertex system
    VertexCore public vertex;
    VertexCollector[] public collectors;

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
        string[] memory initialCollectors = new string[](2);

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

        initialCollectors[0] = "VertexCollector0";
        initialCollectors[1] = "VertexCollector1";

        // Deploy vertex and mock protocol
        vertex = new VertexCore("ProtocolXYZ", "VXP", initialStrategies, initialPolicies, initialPermissions, initialCollectors);

        // Use create2 to get vertex collector addresses
        for (uint256 i; i < initialCollectors.length; i++) {
            bytes32 collectorSalt = bytes32(keccak256(abi.encode(initialCollectors[i])));
            bytes memory bytecode = type(VertexCollector).creationCode;
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff), address(vertex), collectorSalt, keccak256(abi.encodePacked(bytecode, abi.encode(initialCollectors[i], address(vertex))))
                )
            );
            collectors.push(VertexCollector(payable(address(uint160(uint256(hash))))));
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Unit tests
    //////////////////////////////////////////////////////////////*/

    // transfer Native unit tests
    function test_VertexCollector_transfer_TransferETH() public {
        _transferETHToCollector(ETH_AMOUNT);

        uint256 collectorETHBalance = address(collectors[0]).balance;
        uint256 whaleETHBalance = ETH_WHALE.balance;

        // Transfer ETH from collector to whale
        vm.startPrank(address(vertex));
        collectors[0].transfer(payable(ETH_WHALE), ETH_AMOUNT);
        assertEq(address(collectors[0]).balance, 0);
        assertEq(address(collectors[0]).balance, collectorETHBalance - ETH_AMOUNT);
        assertEq(ETH_WHALE.balance, whaleETHBalance + ETH_AMOUNT);
        vm.stopPrank();
    }

    function test_VertexCollector_transfer_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexCollector.OnlyVertex.selector);
        collectors[0].transfer(payable(ETH_WHALE), ETH_AMOUNT);
    }

    function test_VertexCollector_transfer_RevertIfToZeroAddress() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexCollector.Invalid0xRecipient.selector);
        collectors[0].transfer(payable(address(0)), ETH_AMOUNT);
        vm.stopPrank();
    }

    // transfer ERC20 unit tests
    function test_VertexCollector_transferERC20_TransferUSDC() public {
        _transferUSDCToCollector(USDC_AMOUNT);

        uint256 collectorUSDCBalance = USDC.balanceOf(address(collectors[0]));
        uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);

        // Transfer USDC from collector to whale
        vm.startPrank(address(vertex));
        collectors[0].transferERC20(USDC, USDC_WHALE, USDC_AMOUNT);
        assertEq(USDC.balanceOf(address(collectors[0])), 0);
        assertEq(USDC.balanceOf(address(collectors[0])), collectorUSDCBalance - USDC_AMOUNT);
        assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + USDC_AMOUNT);
        vm.stopPrank();
    }

    function test_VertexCollector_transferERC20_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexCollector.OnlyVertex.selector);
        collectors[0].transferERC20(USDC, USDC_WHALE, USDC_AMOUNT);
    }

    function test_VertexCollector_transferERC20_RevertIfToZeroAddress() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexCollector.Invalid0xRecipient.selector);
        collectors[0].transferERC20(USDC, address(0), USDC_AMOUNT);
        vm.stopPrank();
    }

    // approve ERC20 unit tests
    function test_VertexCollector_approveERC20_ApproveUSDC() public {
        _approveUSDCToRecipient(USDC_AMOUNT);
    }

    function test_VertexCollector_approveERC20_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexCollector.OnlyVertex.selector);
        collectors[0].approveERC20(USDC, USDC_WHALE, USDC_AMOUNT);
    }

    /*///////////////////////////////////////////////////////////////
                            Integration tests
    //////////////////////////////////////////////////////////////*/

    // Test that VertexCollector can receive ETH
    function test_VertexCollector_ReceiveETH() public {
        _transferETHToCollector(ETH_AMOUNT);
    }

    // Test that VertexCollector can receive ERC20 tokens
    function test_VertexCollector_ReceiveERC20() public {
        _transferUSDCToCollector(USDC_AMOUNT);
    }

    // Test that approved ERC20 tokens can be transferred from VertexCollector to a recipient
    function test_VertexCollector_TransferApprovedERC20() public {
        _transferUSDCToCollector(USDC_AMOUNT);
        _approveUSDCToRecipient(USDC_AMOUNT);

        uint256 collectorUSDCBalance = USDC.balanceOf(address(collectors[0]));
        uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);

        // Transfer USDC from collector to whale
        vm.startPrank(USDC_WHALE);
        USDC.transferFrom(address(collectors[0]), USDC_WHALE, USDC_AMOUNT);
        assertEq(USDC.balanceOf(address(collectors[0])), 0);
        assertEq(USDC.balanceOf(address(collectors[0])), collectorUSDCBalance - USDC_AMOUNT);
        assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + USDC_AMOUNT);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            Helpers
    //////////////////////////////////////////////////////////////*/

    function _approveUSDCToRecipient(uint256 amount) public {
        vm.startPrank(address(vertex));
        collectors[0].approveERC20(USDC, USDC_WHALE, amount);
        assertEq(USDC.allowance(address(collectors[0]), USDC_WHALE), amount);
        vm.stopPrank();
    }

    function _transferETHToCollector(uint256 amount) public {
        assertEq(address(collectors[0]).balance, 0);

        vm.startPrank(ETH_WHALE);
        (bool success,) = address(collectors[0]).call{value: amount}("");
        assertTrue(success);
        assertEq(address(collectors[0]).balance, amount);
        vm.stopPrank();
    }

    function _transferUSDCToCollector(uint256 amount) public {
        assertEq(USDC.balanceOf(address(collectors[0])), 0);

        vm.startPrank(USDC_WHALE);
        USDC.transfer(address(collectors[0]), amount);
        assertEq(USDC.balanceOf(address(collectors[0])), amount);
        vm.stopPrank();
    }
}
