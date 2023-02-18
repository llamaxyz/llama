// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {VertexAccount} from "src/account/VertexAccount.sol";
import {VertexFactory} from "src/factory/VertexFactory.sol";
import {Strategy, WeightByPermission} from "src/utils/Structs.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract VertexAccountTest is Test {
    // Testing Parameters
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    uint256 public constant USDC_AMOUNT = 1000e6;

    address public constant ETH_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    uint256 public constant ETH_AMOUNT = 1000e18;

    // Vertex system
    VertexCore public vertex;
    VertexCore public vertexCore;
    VertexFactory public vertexFactory;
    VertexAccount[] public accounts;

    address[] public initialPolicies;
    bytes8[][] public initialPermissions;
    uint256[][] public initialExpirationTimestamps;

    // Strategy config
    uint256 public constant approvalPeriod = 14400; // 2 days in blocks
    uint256 public constant queuingDuration = 4 days;
    uint256 public constant expirationDelay = 8 days;
    bool public constant isFixedLengthApprovalPeriod = true;
    uint256 public constant minApprovalPct = 40_00;
    uint256 public constant minDisapprovalPct = 20_00;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        // Setup strategy parameters
        WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](0);
        WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](0);
        Strategy[] memory initialStrategies = new Strategy[](2);
        string[] memory initialAccounts = new string[](2);

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

        initialAccounts[0] = "VertexAccount0";
        initialAccounts[1] = "VertexAccount1";

        // Deploy vertex and mock protocol
        vertexCore = new VertexCore();
        vertexFactory =
        new VertexFactory(vertexCore, "ProtocolXYZ", "VXP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
        vertex = VertexCore(vertexFactory.rootVertex());

        // Use create2 to get vertex account addresses
        for (uint256 i; i < initialAccounts.length; i++) {
            bytes32 accountSalt = bytes32(keccak256(abi.encode(initialAccounts[i])));
            bytes memory bytecode = type(VertexAccount).creationCode;
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff), address(vertex), accountSalt, keccak256(abi.encodePacked(bytecode, abi.encode(initialAccounts[i], address(vertex))))
                )
            );
            accounts.push(VertexAccount(payable(address(uint160(uint256(hash))))));
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Unit tests
    //////////////////////////////////////////////////////////////*/

    // transfer Native unit tests
    function test_VertexAccount_transfer_TransferETH() public {
        _transferETHToAccount(ETH_AMOUNT);

        uint256 accountETHBalance = address(accounts[0]).balance;
        uint256 whaleETHBalance = ETH_WHALE.balance;

        // Transfer ETH from account to whale
        vm.startPrank(address(vertex));
        accounts[0].transfer(payable(ETH_WHALE), ETH_AMOUNT);
        assertEq(address(accounts[0]).balance, 0);
        assertEq(address(accounts[0]).balance, accountETHBalance - ETH_AMOUNT);
        assertEq(ETH_WHALE.balance, whaleETHBalance + ETH_AMOUNT);
        vm.stopPrank();
    }

    function test_VertexAccount_transfer_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].transfer(payable(ETH_WHALE), ETH_AMOUNT);
    }

    function test_VertexAccount_transfer_RevertIfToZeroAddress() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].transfer(payable(address(0)), ETH_AMOUNT);
        vm.stopPrank();
    }

    // transfer ERC20 unit tests
    function test_VertexAccount_transferERC20_TransferUSDC() public {
        _transferUSDCToAccount(USDC_AMOUNT);

        uint256 accountUSDCBalance = USDC.balanceOf(address(accounts[0]));
        uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);

        // Transfer USDC from account to whale
        vm.startPrank(address(vertex));
        accounts[0].transferERC20(USDC, USDC_WHALE, USDC_AMOUNT);
        assertEq(USDC.balanceOf(address(accounts[0])), 0);
        assertEq(USDC.balanceOf(address(accounts[0])), accountUSDCBalance - USDC_AMOUNT);
        assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + USDC_AMOUNT);
        vm.stopPrank();
    }

    function test_VertexAccount_transferERC20_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].transferERC20(USDC, USDC_WHALE, USDC_AMOUNT);
    }

    function test_VertexAccount_transferERC20_RevertIfToZeroAddress() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].transferERC20(USDC, address(0), USDC_AMOUNT);
        vm.stopPrank();
    }

    // approve ERC20 unit tests
    function test_VertexAccount_approveERC20_ApproveUSDC() public {
        _approveUSDCToRecipient(USDC_AMOUNT);
    }

    function test_VertexAccount_approveERC20_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].approveERC20(USDC, USDC_WHALE, USDC_AMOUNT);
    }

    /*///////////////////////////////////////////////////////////////
                            Integration tests
    //////////////////////////////////////////////////////////////*/

    // Test that VertexAccount can receive ETH
    function test_VertexAccount_ReceiveETH() public {
        _transferETHToAccount(ETH_AMOUNT);
    }

    // Test that VertexAccount can receive ERC20 tokens
    function test_VertexAccount_ReceiveERC20() public {
        _transferUSDCToAccount(USDC_AMOUNT);
    }

    // Test that approved ERC20 tokens can be transferred from VertexAccount to a recipient
    function test_VertexAccount_TransferApprovedERC20() public {
        _transferUSDCToAccount(USDC_AMOUNT);
        _approveUSDCToRecipient(USDC_AMOUNT);

        uint256 accountUSDCBalance = USDC.balanceOf(address(accounts[0]));
        uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);

        // Transfer USDC from account to whale
        vm.startPrank(USDC_WHALE);
        USDC.transferFrom(address(accounts[0]), USDC_WHALE, USDC_AMOUNT);
        assertEq(USDC.balanceOf(address(accounts[0])), 0);
        assertEq(USDC.balanceOf(address(accounts[0])), accountUSDCBalance - USDC_AMOUNT);
        assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + USDC_AMOUNT);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            Helpers
    //////////////////////////////////////////////////////////////*/

    function _approveUSDCToRecipient(uint256 amount) public {
        vm.startPrank(address(vertex));
        accounts[0].approveERC20(USDC, USDC_WHALE, amount);
        assertEq(USDC.allowance(address(accounts[0]), USDC_WHALE), amount);
        vm.stopPrank();
    }

    function _transferETHToAccount(uint256 amount) public {
        assertEq(address(accounts[0]).balance, 0);

        vm.startPrank(ETH_WHALE);
        (bool success,) = address(accounts[0]).call{value: amount}("");
        assertTrue(success);
        assertEq(address(accounts[0]).balance, amount);
        vm.stopPrank();
    }

    function _transferUSDCToAccount(uint256 amount) public {
        assertEq(USDC.balanceOf(address(accounts[0])), 0);

        vm.startPrank(USDC_WHALE);
        USDC.transfer(address(accounts[0]), amount);
        assertEq(USDC.balanceOf(address(accounts[0])), amount);
        vm.stopPrank();
    }
}
