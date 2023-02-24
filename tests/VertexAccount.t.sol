// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/core/VertexCore.sol";
import {VertexAccount} from "src/account/VertexAccount.sol";
import {VertexFactory} from "src/factory/VertexFactory.sol";
import {Strategy, WeightByPermission} from "src/utils/Structs.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";
import {TestScript} from "src/mock/scripts/TestScript.sol";
import {ICryptoPunk} from "src/mock/external/ICryptoPunk.sol";

contract VertexAccountTest is Test {
    // Testing Parameters
    // Native Token
    address public constant ETH_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    uint256 public constant ETH_AMOUNT = 1000e18;

    // ERC20 Token
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    uint256 public constant USDC_AMOUNT = 1000e6;

    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address public constant USDT_WHALE = 0xA7A93fd0a276fc1C0197a5B5623eD117786eeD06;
    uint256 public constant USDT_AMOUNT = 1000e6;

    IERC20 public constant UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    address public constant UNI_WHALE = 0x47173B170C64d16393a52e6C480b3Ad8c302ba1e;
    uint256 public constant UNI_AMOUNT = 1000e18;

    // ERC721 Token
    IERC721 public constant BAYC = IERC721(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
    address public constant BAYC_WHALE = 0x619866736a3a101f65cfF3A8c3d2602fC54Fd749;
    uint256 public constant BAYC_ID = 27;
    uint256 public constant BAYC_ID_2 = 8885;

    IERC721 public constant NOUNS = IERC721(0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03);
    address public constant NOUNS_WHALE = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
    uint256 public constant NOUNS_ID = 540;
    uint256 public constant NOUNS_ID_2 = 550;

    // Non-standard NFT
    ICryptoPunk public constant PUNK = ICryptoPunk(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);
    address public constant PUNK_WHALE = 0xB88F61E6FbdA83fbfffAbE364112137480398018;
    uint256 public constant PUNK_ID = 9313;

    // ERC1155 Token
    IERC1155 public constant RARI = IERC1155(0xd07dc4262BCDbf85190C01c996b4C06a461d2430);
    address public constant RARI_WHALE = 0xEdba5d56d0147aee8a227D284bcAaC03B4a87eD4;
    uint256 public constant RARI_ID_1 = 657774;
    uint256 public constant RARI_ID_1_AMOUNT = 3;
    uint256 public constant RARI_ID_2 = 74385;
    uint256 public constant RARI_ID_2_AMOUNT = 1;

    IERC1155 public constant OPENSTORE = IERC1155(0x495f947276749Ce646f68AC8c248420045cb7b5e);
    address public constant OPENSTORE_WHALE = 0xaBA7161A7fb69c88e16ED9f455CE62B791EE4D03;
    uint256 public constant OPENSTORE_ID_1 = 50227944111491829717518767573293673148720215112283513814059266953762918367332;
    uint256 public constant OPENSTORE_ID_1_AMOUNT = 20;
    uint256 public constant OPENSTORE_ID_2 = 25221312271773506578423917291534224130165348289584384465161209685514687348761;
    uint256 public constant OPENSTORE_ID_2_AMOUNT = 1;

    // Vertex system
    VertexCore public vertex;
    VertexCore public vertexCore;
    VertexAccount public vertexAccountImplementation;
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
        vm.createSelectFork(vm.rpcUrl("mainnet"), 16573464);

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
        vertexAccountImplementation = new VertexAccount();
        vertexFactory =
        new VertexFactory(vertexCore, vertexAccountImplementation, "ProtocolXYZ", "VXP", initialStrategies, initialAccounts, initialPolicies, initialPermissions, initialExpirationTimestamps);
        vertex = VertexCore(vertexFactory.rootVertex());

        // Use create2 to get vertex account addresses
        for (uint256 i; i < initialAccounts.length; i++) {
            bytes32 accountSalt = bytes32(keccak256(abi.encode(initialAccounts[i])));
            accounts.push(VertexAccount(payable(Clones.predictDeterministicAddress(address(vertexAccountImplementation), accountSalt, address(vertex)))));
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Unit tests
    //////////////////////////////////////////////////////////////*/

    // transfer Native unit tests
    function test_transfer_TransferETH() public {
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

    function test_transfer_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].transfer(payable(ETH_WHALE), ETH_AMOUNT);
    }

    function test_transfer_RevertIfToZeroAddress() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].transfer(payable(address(0)), ETH_AMOUNT);
        vm.stopPrank();
    }

    // transfer ERC20 unit tests
    function test_transferERC20_TransferUSDC() public {
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

    function test_transferERC20_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].transferERC20(USDC, USDC_WHALE, USDC_AMOUNT);
    }

    function test_transferERC20_RevertIfToZeroAddress() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].transferERC20(USDC, address(0), USDC_AMOUNT);
        vm.stopPrank();
    }

    // batch transfer ERC20 unit tests
    function test_batchTransferERC20_TransferUSDCAndUNI() public {
        _transferUSDCToAccount(USDC_AMOUNT);
        _transferUNIToAccount(UNI_AMOUNT);

        uint256 accountUSDCBalance = USDC.balanceOf(address(accounts[0]));
        uint256 accountUNIBalance = UNI.balanceOf(address(accounts[0]));
        uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);
        uint256 whaleUSDTBalance = UNI.balanceOf(UNI_WHALE);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = USDC;
        tokens[1] = UNI;

        address[] memory recipients = new address[](2);
        recipients[0] = USDC_WHALE;
        recipients[1] = UNI_WHALE;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = USDC_AMOUNT;
        amounts[1] = UNI_AMOUNT;

        // Transfer USDC and USDT from account to whale
        vm.startPrank(address(vertex));
        accounts[0].batchTransferERC20(tokens, recipients, amounts);
        assertEq(USDC.balanceOf(address(accounts[0])), 0);
        assertEq(UNI.balanceOf(address(accounts[0])), 0);
        assertEq(USDC.balanceOf(address(accounts[0])), accountUSDCBalance - USDC_AMOUNT);
        assertEq(UNI.balanceOf(address(accounts[0])), accountUNIBalance - UNI_AMOUNT);
        assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + USDC_AMOUNT);
        assertEq(UNI.balanceOf(UNI_WHALE), whaleUSDTBalance + UNI_AMOUNT);
        vm.stopPrank();
    }

    function test_batchTransferERC20_RevertIfNotVertexMsgSender() public {
        IERC20[] memory tokens = new IERC20[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].batchTransferERC20(tokens, recipients, amounts);
    }

    function test_batchTransferERC20_RevertIfZeroInputLength() public {
        IERC20[] memory tokens = new IERC20[](0);
        address[] memory recipients = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchTransferERC20(tokens, recipients, amounts);
        vm.stopPrank();
    }

    function test_batchTransferERC20_RevertIfInvalidInputLength() public {
        IERC20[] memory tokens = new IERC20[](1);
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchTransferERC20(tokens, recipients, amounts);
        vm.stopPrank();
    }

    function test_batchTransferERC20_RevertIfToZeroAddress() public {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = USDC;

        address[] memory recipients = new address[](1);
        recipients[0] = address(0);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = USDC_AMOUNT;

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].batchTransferERC20(tokens, recipients, amounts);
        vm.stopPrank();
    }

    // approve ERC20 unit tests
    function test_approveERC20_ApproveUSDC() public {
        _approveUSDCToRecipient(USDC_AMOUNT);
    }

    function test_approveERC20_IncreaseUSDCAllowance() public {
        _approveUSDCToRecipient(USDC_AMOUNT);
        _approveUSDCToRecipient(0);
        _approveUSDCToRecipient(USDC_AMOUNT + 1);
    }

    function test_approveERC20_DecreaseUSDCAllowance() public {
        _approveUSDCToRecipient(USDC_AMOUNT);
        _approveUSDCToRecipient(0);
        _approveUSDCToRecipient(USDC_AMOUNT - 1);
    }

    function test_approveERC20_IncreaseUSDTAllowance() public {
        _approveUSDTToRecipient(USDT_AMOUNT);
        _approveUSDTToRecipient(0);
        _approveUSDTToRecipient(USDT_AMOUNT + 1);
    }

    function test_approveERC20_DecreaseUSDTAllowance() public {
        _approveUSDTToRecipient(USDT_AMOUNT);
        _approveUSDTToRecipient(0);
        _approveUSDTToRecipient(USDT_AMOUNT - 1);
    }

    function test_approveERC20_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].approveERC20(USDC, USDC_WHALE, USDC_AMOUNT);
    }

    // batch approve ERC20 unit tests
    function test_batchApproveERC20_ApproveUSDCAndUNI() public {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = USDC;
        tokens[1] = UNI;

        address[] memory recipients = new address[](2);
        recipients[0] = USDC_WHALE;
        recipients[1] = UNI_WHALE;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = USDC_AMOUNT;
        amounts[1] = UNI_AMOUNT;

        // Approve USDC and UNI to whale
        vm.startPrank(address(vertex));
        accounts[0].batchApproveERC20(tokens, recipients, amounts);
        assertEq(USDC.allowance(address(accounts[0]), USDC_WHALE), USDC_AMOUNT);
        assertEq(UNI.allowance(address(accounts[0]), UNI_WHALE), UNI_AMOUNT);
        vm.stopPrank();
    }

    function test_batchApproveERC20_RevertIfNotVertexMsgSender() public {
        IERC20[] memory tokens = new IERC20[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].batchApproveERC20(tokens, recipients, amounts);
    }

    function test_batchApproveERC20_RevertIfZeroInputLength() public {
        IERC20[] memory tokens = new IERC20[](0);
        address[] memory recipients = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchApproveERC20(tokens, recipients, amounts);
        vm.stopPrank();
    }

    function test_batchApproveERC20_RevertIfInvalidInputLength() public {
        IERC20[] memory tokens = new IERC20[](1);
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchApproveERC20(tokens, recipients, amounts);
        vm.stopPrank();
    }

    // transfer ERC721 unit tests
    function test_transferERC721_TransferBAYC() public {
        _transferBAYCToAccount(BAYC_ID);

        uint256 accountNFTBalance = BAYC.balanceOf(address(accounts[0]));
        uint256 whaleNFTBalance = BAYC.balanceOf(BAYC_WHALE);

        // Transfer NFT from account to whale
        vm.startPrank(address(vertex));
        accounts[0].transferERC721(BAYC, BAYC_WHALE, BAYC_ID);
        assertEq(BAYC.balanceOf(address(accounts[0])), 0);
        assertEq(BAYC.balanceOf(address(accounts[0])), accountNFTBalance - 1);
        assertEq(BAYC.balanceOf(BAYC_WHALE), whaleNFTBalance + 1);
        assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);
        vm.stopPrank();
    }

    function test_transferERC721_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].transferERC721(BAYC, BAYC_WHALE, BAYC_ID);
    }

    function test_transferERC721_RevertIfToZeroAddress() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].transferERC721(BAYC, address(0), BAYC_ID);
        vm.stopPrank();
    }

    // batch transfer ERC721 unit tests
    function test_batchTransferERC721_TransferBAYCAndNOUNS() public {
        _transferBAYCToAccount(BAYC_ID);
        _transferNOUNSToAccount(NOUNS_ID);

        uint256 accountBAYCBalance = BAYC.balanceOf(address(accounts[0]));
        uint256 whaleBAYCBalance = BAYC.balanceOf(BAYC_WHALE);
        uint256 accountNOUNSBalance = NOUNS.balanceOf(address(accounts[0]));
        uint256 whaleNOUNSBalance = NOUNS.balanceOf(NOUNS_WHALE);

        IERC721[] memory tokens = new IERC721[](2);
        tokens[0] = BAYC;
        tokens[1] = NOUNS;

        address[] memory recipients = new address[](2);
        recipients[0] = BAYC_WHALE;
        recipients[1] = NOUNS_WHALE;

        uint256[] memory ids = new uint256[](2);
        ids[0] = BAYC_ID;
        ids[1] = NOUNS_ID;

        // Transfer NFTs from account to whale
        vm.startPrank(address(vertex));
        accounts[0].batchTransferERC721(tokens, recipients, ids);
        assertEq(BAYC.balanceOf(address(accounts[0])), accountBAYCBalance - 1);
        assertEq(BAYC.balanceOf(BAYC_WHALE), whaleBAYCBalance + 1);
        assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);
        assertEq(NOUNS.balanceOf(address(accounts[0])), accountNOUNSBalance - 1);
        assertEq(NOUNS.balanceOf(NOUNS_WHALE), whaleNOUNSBalance + 1);
        assertEq(NOUNS.ownerOf(NOUNS_ID), NOUNS_WHALE);
        vm.stopPrank();
    }

    function test_batchTransferERC721_RevertIfNotVertexMsgSender() public {
        IERC721[] memory tokens = new IERC721[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory ids = new uint256[](2);

        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].batchTransferERC721(tokens, recipients, ids);
    }

    function test_batchTransferERC721_RevertIfZeroInputLength() public {
        IERC721[] memory tokens = new IERC721[](0);
        address[] memory recipients = new address[](0);
        uint256[] memory ids = new uint256[](0);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchTransferERC721(tokens, recipients, ids);
        vm.stopPrank();
    }

    function test_batchTransferERC721_RevertIfInvalidInputLength() public {
        IERC721[] memory tokens = new IERC721[](1);
        address[] memory recipients = new address[](2);
        uint256[] memory ids = new uint256[](2);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchTransferERC721(tokens, recipients, ids);
        vm.stopPrank();
    }

    function test_batchTransferERC721_RevertIfToZeroAddress() public {
        IERC721[] memory tokens = new IERC721[](1);
        tokens[0] = BAYC;

        address[] memory recipients = new address[](1);
        recipients[0] = address(0);

        uint256[] memory ids = new uint256[](1);
        ids[0] = BAYC_ID;

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].batchTransferERC721(tokens, recipients, ids);
        vm.stopPrank();
    }

    // approve ERC721 unit tests
    function test_approveERC721_ApproveBAYC() public {
        _transferBAYCToAccount(BAYC_ID);
        _approveBAYCToRecipient(BAYC_ID);
    }

    function test_approveERC721_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].approveERC721(BAYC, BAYC_WHALE, BAYC_ID);
    }

    // batch approve ERC721 unit tests
    function test_batchApproveERC721_ApproveBAYCAndNOUNS() public {
        _transferBAYCToAccount(BAYC_ID);
        _transferNOUNSToAccount(NOUNS_ID);

        IERC721[] memory tokens = new IERC721[](2);
        tokens[0] = BAYC;
        tokens[1] = NOUNS;

        address[] memory recipients = new address[](2);
        recipients[0] = BAYC_WHALE;
        recipients[1] = NOUNS_WHALE;

        uint256[] memory ids = new uint256[](2);
        ids[0] = BAYC_ID;
        ids[1] = NOUNS_ID;

        // Approve NFTs from account to whale
        vm.startPrank(address(vertex));
        accounts[0].batchApproveERC721(tokens, recipients, ids);
        assertEq(BAYC.getApproved(BAYC_ID), BAYC_WHALE);
        assertEq(NOUNS.getApproved(NOUNS_ID), NOUNS_WHALE);
        vm.stopPrank();
    }

    function test_batchApproveERC721_RevertIfNotVertexMsgSender() public {
        IERC721[] memory tokens = new IERC721[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory ids = new uint256[](2);

        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].batchApproveERC721(tokens, recipients, ids);
    }

    function test_batchApproveERC721_RevertIfZeroInputLength() public {
        IERC721[] memory tokens = new IERC721[](0);
        address[] memory recipients = new address[](0);
        uint256[] memory ids = new uint256[](0);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchApproveERC721(tokens, recipients, ids);
        vm.stopPrank();
    }

    function test_batchApproveERC721_RevertIfInvalidInputLength() public {
        IERC721[] memory tokens = new IERC721[](1);
        address[] memory recipients = new address[](2);
        uint256[] memory ids = new uint256[](2);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchApproveERC721(tokens, recipients, ids);
        vm.stopPrank();
    }

    // approve operator ERC721 unit tests
    function test_approveOperatorERC721_ApproveBAYC() public {
        _approveOperatorBAYCToRecipient(true);
    }

    function test_approveOperatorERC721_DisapproveBAYC() public {
        _approveOperatorBAYCToRecipient(false);
    }

    function test_approveOperatorERC721_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].approveOperatorERC721(BAYC, BAYC_WHALE, true);
    }

    // batch approve operator ERC721 unit tests
    function test_batchApproveOperatorERC721_ApproveBAYCAndNOUNS() public {
        IERC721[] memory tokens = new IERC721[](2);
        tokens[0] = BAYC;
        tokens[1] = NOUNS;

        address[] memory recipients = new address[](2);
        recipients[0] = BAYC_WHALE;
        recipients[1] = NOUNS_WHALE;

        bool[] memory approvals = new bool[](2);
        approvals[0] = true;
        approvals[1] = true;

        // Approve NFTs from account to whale
        vm.startPrank(address(vertex));
        accounts[0].batchApproveOperatorERC721(tokens, recipients, approvals);
        assertEq(BAYC.isApprovedForAll(address(accounts[0]), BAYC_WHALE), true);
        assertEq(NOUNS.isApprovedForAll(address(accounts[0]), NOUNS_WHALE), true);
        vm.stopPrank();
    }

    function test_batchApproveOperatorERC721_RevertIfNotVertexMsgSender() public {
        IERC721[] memory tokens = new IERC721[](2);
        address[] memory recipients = new address[](2);
        bool[] memory approvals = new bool[](2);

        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].batchApproveOperatorERC721(tokens, recipients, approvals);
    }

    function test_batchApproveOperatorERC721_RevertIfZeroInputLength() public {
        IERC721[] memory tokens = new IERC721[](0);
        address[] memory recipients = new address[](0);
        bool[] memory approvals = new bool[](0);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchApproveOperatorERC721(tokens, recipients, approvals);
        vm.stopPrank();
    }

    function test_batchApproveOperatorERC721_RevertIfInvalidInputLength() public {
        IERC721[] memory tokens = new IERC721[](1);
        address[] memory recipients = new address[](2);
        bool[] memory approvals = new bool[](2);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchApproveOperatorERC721(tokens, recipients, approvals);
        vm.stopPrank();
    }

    // transfer ERC1155 unit tests
    function test_transferERC1155_TransferRARI() public {
        _transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);

        uint256 accountNFTBalance = RARI.balanceOf(address(accounts[0]), RARI_ID_1);
        uint256 whaleNFTBalance = RARI.balanceOf(RARI_WHALE, RARI_ID_1);

        // Transfer NFT from account to whale
        vm.startPrank(address(vertex));
        accounts[0].transferERC1155(RARI, RARI_WHALE, RARI_ID_1, RARI_ID_1_AMOUNT, "");
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_1), 0);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_1), accountNFTBalance - RARI_ID_1_AMOUNT);
        assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_1), whaleNFTBalance + RARI_ID_1_AMOUNT);
        vm.stopPrank();
    }

    function test_transferERC1155_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].transferERC1155(RARI, RARI_WHALE, RARI_ID_1, RARI_ID_1_AMOUNT, "");
    }

    function test_transferERC1155_RevertIfToZeroAddress() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].transferERC1155(RARI, address(0), RARI_ID_1, RARI_ID_1_AMOUNT, "");
        vm.stopPrank();
    }

    // batch transfer single ERC1155 unit tests
    function test_batchTransferSingleERC1155_TransferRARI() public {
        _transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);
        _transferRARIToAccount(RARI_ID_2, RARI_ID_2_AMOUNT);

        uint256 accountNFTBalance1 = RARI.balanceOf(address(accounts[0]), RARI_ID_1);
        uint256 whaleNFTBalance1 = RARI.balanceOf(RARI_WHALE, RARI_ID_1);
        uint256 accountNFTBalance2 = RARI.balanceOf(address(accounts[0]), RARI_ID_2);
        uint256 whaleNFTBalance2 = RARI.balanceOf(RARI_WHALE, RARI_ID_2);

        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = RARI_ID_1;
        tokenIDs[1] = RARI_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = RARI_ID_1_AMOUNT;
        amounts[1] = RARI_ID_2_AMOUNT;

        // Transfer NFT from account to whale
        vm.startPrank(address(vertex));
        accounts[0].batchTransferSingleERC1155(RARI, RARI_WHALE, tokenIDs, amounts, "");
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_1), 0);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_1), accountNFTBalance1 - RARI_ID_1_AMOUNT);
        assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_1), whaleNFTBalance1 + RARI_ID_1_AMOUNT);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_2), 0);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_2), accountNFTBalance2 - RARI_ID_2_AMOUNT);
        assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_2), whaleNFTBalance2 + RARI_ID_2_AMOUNT);
        vm.stopPrank();
    }

    function test_batchTransferSingleERC1155_RevertIfNotVertexMsgSender() public {
        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = RARI_ID_1;
        tokenIDs[1] = RARI_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = RARI_ID_1_AMOUNT;
        amounts[1] = RARI_ID_2_AMOUNT;

        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].batchTransferSingleERC1155(RARI, RARI_WHALE, tokenIDs, amounts, "");
    }

    function test_batchTransferSingleERC1155_RevertIfToZeroAddress() public {
        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = RARI_ID_1;
        tokenIDs[1] = RARI_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = RARI_ID_1_AMOUNT;
        amounts[1] = RARI_ID_2_AMOUNT;

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].batchTransferSingleERC1155(RARI, address(0), tokenIDs, amounts, "");
        vm.stopPrank();
    }

    // batch transfer multiple ERC1155 unit tests
    function test_batchTransferMultipleERC1155_TransferRARIAndOPENSTORE() public {
        _transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);
        _transferRARIToAccount(RARI_ID_2, RARI_ID_2_AMOUNT);
        _transferOPENSTOREToAccount(OPENSTORE_ID_1, OPENSTORE_ID_1_AMOUNT);
        _transferOPENSTOREToAccount(OPENSTORE_ID_2, OPENSTORE_ID_2_AMOUNT);

        uint256 whaleRARIBalance1 = RARI.balanceOf(RARI_WHALE, RARI_ID_1);
        uint256 whaleRARIBalance2 = RARI.balanceOf(RARI_WHALE, RARI_ID_2);
        uint256 whaleOPENSTOREBalance1 = OPENSTORE.balanceOf(OPENSTORE_WHALE, OPENSTORE_ID_1);
        uint256 whaleOPENSTOREBalance2 = OPENSTORE.balanceOf(OPENSTORE_WHALE, OPENSTORE_ID_2);

        IERC1155[] memory tokens = new IERC1155[](2);
        tokens[0] = RARI;
        tokens[1] = OPENSTORE;

        address[] memory recipients = new address[](2);
        recipients[0] = RARI_WHALE;
        recipients[1] = OPENSTORE_WHALE;

        uint256[] memory tokenIDs1 = new uint256[](2);
        tokenIDs1[0] = RARI_ID_1;
        tokenIDs1[1] = RARI_ID_2;

        uint256[] memory tokenIDs2 = new uint256[](2);
        tokenIDs2[0] = OPENSTORE_ID_1;
        tokenIDs2[1] = OPENSTORE_ID_2;

        uint256[][] memory tokenIDs = new uint256[][](2);
        tokenIDs[0] = tokenIDs1;
        tokenIDs[1] = tokenIDs2;

        uint256[] memory amounts1 = new uint256[](2);
        amounts1[0] = RARI_ID_1_AMOUNT;
        amounts1[1] = RARI_ID_2_AMOUNT;

        uint256[] memory amounts2 = new uint256[](2);
        amounts2[0] = OPENSTORE_ID_1_AMOUNT;
        amounts2[1] = OPENSTORE_ID_2_AMOUNT;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = amounts1;
        amounts[1] = amounts2;

        bytes[] memory data = new bytes[](2);
        data[0] = "";
        data[1] = "";

        // Transfer NFT from account to whale
        vm.startPrank(address(vertex));
        accounts[0].batchTransferMultipleERC1155(tokens, recipients, tokenIDs, amounts, data);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_1), 0);
        assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_1), whaleRARIBalance1 + RARI_ID_1_AMOUNT);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_2), 0);
        assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_2), whaleRARIBalance2 + RARI_ID_2_AMOUNT);
        assertEq(OPENSTORE.balanceOf(address(accounts[0]), OPENSTORE_ID_1), 0);
        assertEq(OPENSTORE.balanceOf(OPENSTORE_WHALE, OPENSTORE_ID_1), whaleOPENSTOREBalance1 + OPENSTORE_ID_1_AMOUNT);
        assertEq(OPENSTORE.balanceOf(address(accounts[0]), OPENSTORE_ID_2), 0);
        assertEq(OPENSTORE.balanceOf(OPENSTORE_WHALE, OPENSTORE_ID_2), whaleOPENSTOREBalance2 + OPENSTORE_ID_2_AMOUNT);
        vm.stopPrank();
    }

    function test_batchTransferMultipleERC1155_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].batchTransferMultipleERC1155(new IERC1155[](0), new address[](0), new uint256[][](0), new uint256[][](0), new bytes[](0));
    }

    function test_batchTransferMultipleERC1155_RevertIfZeroInputLength() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchTransferMultipleERC1155(new IERC1155[](0), new address[](0), new uint256[][](0), new uint256[][](0), new bytes[](0));
        vm.stopPrank();
    }

    function test_batchTransferMultipleERC1155_RevertIfInvalidInputLength() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchTransferMultipleERC1155(new IERC1155[](1), new address[](2), new uint256[][](0), new uint256[][](0), new bytes[](0));
        vm.stopPrank();
    }

    function test_batchTransferMultipleERC1155_RevertIfToZeroAddress() public {
        address[] memory recipients = new address[](1);
        recipients[0] = address(0);

        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
        accounts[0].batchTransferMultipleERC1155(new IERC1155[](1), recipients, new uint256[][](1), new uint256[][](1), new bytes[](1));
        vm.stopPrank();
    }

    // approve operator ERC1155 unit tests
    function test_approveOperatorERC1155_ApproveRARI() public {
        _approveRARIToRecipient(true);
    }

    function test_approveOperatorERC1155_DisapproveRARI() public {
        _approveRARIToRecipient(false);
    }

    function test_approveOperatorERC1155_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].approveOperatorERC1155(RARI, RARI_WHALE, true);
    }

    // batch approve operator ERC1155 unit tests
    function test_batchApproveOperatorERC1155_ApproveRARIAndOPENSTORE() public {
        IERC1155[] memory tokens = new IERC1155[](2);
        tokens[0] = RARI;
        tokens[1] = OPENSTORE;

        address[] memory recipients = new address[](2);
        recipients[0] = RARI_WHALE;
        recipients[1] = OPENSTORE_WHALE;

        bool[] memory approvals = new bool[](2);
        approvals[0] = true;
        approvals[1] = true;

        vm.startPrank(address(vertex));
        accounts[0].batchApproveOperatorERC1155(tokens, recipients, approvals);
        assertEq(RARI.isApprovedForAll(address(accounts[0]), RARI_WHALE), true);
        assertEq(OPENSTORE.isApprovedForAll(address(accounts[0]), OPENSTORE_WHALE), true);
        vm.stopPrank();
    }

    function test_batchApproveOperatorERC1155_RevertIfNotVertexMsgSender() public {
        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].batchApproveOperatorERC1155(new IERC1155[](0), new address[](0), new bool[](0));
    }

    function test_batchApproveOperatorERC1155_RevertIfZeroInputLength() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchApproveOperatorERC1155(new IERC1155[](0), new address[](0), new bool[](0));
        vm.stopPrank();
    }

    function test_batchApproveOperatorERC1155_RevertIfInvalidInputLength() public {
        vm.startPrank(address(vertex));
        vm.expectRevert(VertexAccount.InvalidInput.selector);
        accounts[0].batchApproveOperatorERC1155(new IERC1155[](1), new address[](2), new bool[](1));
        vm.stopPrank();
    }

    // generic execute unit tests
    function test_execute_CallCryptoPunk() public {
        // Transfer Punk to Account to have it stuck in the Vertex Account
        _transferPUNKToAccount(PUNK_ID);

        uint256 accountNFTBalance = PUNK.balanceOf(address(accounts[0]));
        uint256 whaleNFTBalance = PUNK.balanceOf(PUNK_WHALE);

        // Rescue Punk by calling execute call
        vm.startPrank(address(vertex));
        accounts[0].execute(address(PUNK), abi.encodeWithSelector(ICryptoPunk.transferPunk.selector, PUNK_WHALE, PUNK_ID), false);
        assertEq(PUNK.balanceOf(address(accounts[0])), 0);
        assertEq(PUNK.balanceOf(address(accounts[0])), accountNFTBalance - 1);
        assertEq(PUNK.balanceOf(PUNK_WHALE), whaleNFTBalance + 1);
        assertEq(PUNK.punkIndexToAddress(PUNK_ID), PUNK_WHALE);
        vm.stopPrank();
    }

    function test_execute_DelegateCallTestScript() public {
        TestScript testScript = new TestScript();

        vm.startPrank(address(vertex));
        bytes memory result = accounts[0].execute(address(testScript), abi.encodePacked(TestScript.testFunction.selector, ""), true);
        assertEq(10, uint256(bytes32(result)));
        vm.stopPrank();
    }

    function test_execute_RevertIfNotVertexMsgSender() public {
        TestScript testScript = new TestScript();

        vm.expectRevert(VertexAccount.OnlyVertex.selector);
        accounts[0].execute(address(testScript), abi.encodePacked(TestScript.testFunction.selector, ""), true);
    }

    function test_execute_RevertIfNotSuccess() public {
        TestScript testScript = new TestScript();

        vm.startPrank(address(vertex));
        vm.expectRevert(abi.encodeWithSelector(VertexAccount.FailedExecution.selector, ""));
        accounts[0].execute(address(testScript), abi.encodePacked("", ""), true);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            Integration tests
    //////////////////////////////////////////////////////////////*/

    // Test that VertexAccount can receive ETH
    function test_ReceiveETH() public {
        _transferETHToAccount(ETH_AMOUNT);
    }

    // Test that VertexAccount can receive ERC20 tokens
    function test_ReceiveERC20() public {
        _transferUSDCToAccount(USDC_AMOUNT);
    }

    // Test that approved ERC20 tokens can be transferred from VertexAccount to a recipient
    function test_TransferApprovedERC20() public {
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

    // Test that VertexAccount can receive ERC721 tokens
    function test_ReceiveERC721() public {
        _transferBAYCToAccount(BAYC_ID);
    }

    // Test that VertexAccount can safe receive ERC721 tokens
    function test_SafeReceiveERC721() public {
        assertEq(BAYC.balanceOf(address(accounts[0])), 0);
        assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);

        vm.startPrank(BAYC_WHALE);
        BAYC.safeTransferFrom(BAYC_WHALE, address(accounts[0]), BAYC_ID);
        assertEq(BAYC.balanceOf(address(accounts[0])), 1);
        assertEq(BAYC.ownerOf(BAYC_ID), address(accounts[0]));
        vm.stopPrank();
    }

    // Test that approved ERC721 tokens can be transferred from VertexAccount to a recipient
    function test_TransferApprovedERC721() public {
        _transferBAYCToAccount(BAYC_ID);
        _approveBAYCToRecipient(BAYC_ID);

        uint256 accountNFTBalance = BAYC.balanceOf(address(accounts[0]));
        uint256 whaleNFTBalance = BAYC.balanceOf(BAYC_WHALE);

        // Transfer NFT from account to whale
        vm.startPrank(BAYC_WHALE);
        BAYC.transferFrom(address(accounts[0]), BAYC_WHALE, BAYC_ID);
        assertEq(BAYC.balanceOf(address(accounts[0])), 0);
        assertEq(BAYC.balanceOf(address(accounts[0])), accountNFTBalance - 1);
        assertEq(BAYC.balanceOf(BAYC_WHALE), whaleNFTBalance + 1);
        assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);
        vm.stopPrank();
    }

    // Test that approved Operator ERC721 tokens can be transferred from VertexAccount to a recipient
    function test_TransferApprovedOperatorERC721() public {
        vm.startPrank(BAYC_WHALE);
        BAYC.transferFrom(BAYC_WHALE, address(accounts[0]), BAYC_ID);
        BAYC.transferFrom(BAYC_WHALE, address(accounts[0]), BAYC_ID_2);
        vm.stopPrank();
        _approveOperatorBAYCToRecipient(true);

        uint256 accountNFTBalance = BAYC.balanceOf(address(accounts[0]));
        uint256 whaleNFTBalance = BAYC.balanceOf(BAYC_WHALE);

        // Transfer NFT from account to whale
        vm.startPrank(BAYC_WHALE);
        BAYC.transferFrom(address(accounts[0]), BAYC_WHALE, BAYC_ID);
        BAYC.transferFrom(address(accounts[0]), BAYC_WHALE, BAYC_ID_2);
        assertEq(BAYC.balanceOf(address(accounts[0])), 0);
        assertEq(BAYC.balanceOf(address(accounts[0])), accountNFTBalance - 2);
        assertEq(BAYC.balanceOf(BAYC_WHALE), whaleNFTBalance + 2);
        assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);
        assertEq(BAYC.ownerOf(BAYC_ID_2), BAYC_WHALE);
        vm.stopPrank();
    }

    // Test that VertexAccount can receive ERC1155 tokens
    function test_ReceiveERC1155() public {
        _transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);
    }

    // Test that approved ERC1155 tokens can be transferred from VertexAccount to a recipient
    function test_TransferApprovedERC1155() public {
        _transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);
        _transferRARIToAccount(RARI_ID_2, RARI_ID_2_AMOUNT);
        _approveRARIToRecipient(true);

        uint256 accountNFTBalance1 = RARI.balanceOf(address(accounts[0]), RARI_ID_1);
        uint256 whaleNFTBalance1 = RARI.balanceOf(RARI_WHALE, RARI_ID_1);
        uint256 accountNFTBalance2 = RARI.balanceOf(address(accounts[0]), RARI_ID_2);
        uint256 whaleNFTBalance2 = RARI.balanceOf(RARI_WHALE, RARI_ID_2);

        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = RARI_ID_1;
        tokenIDs[1] = RARI_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = RARI_ID_1_AMOUNT;
        amounts[1] = RARI_ID_2_AMOUNT;

        // Transfer NFT from account to whale
        vm.startPrank(address(RARI_WHALE));
        RARI.safeBatchTransferFrom(address(accounts[0]), RARI_WHALE, tokenIDs, amounts, "");
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_1), 0);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_1), accountNFTBalance1 - RARI_ID_1_AMOUNT);
        assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_1), whaleNFTBalance1 + RARI_ID_1_AMOUNT);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_2), 0);
        assertEq(RARI.balanceOf(address(accounts[0]), RARI_ID_2), accountNFTBalance2 - RARI_ID_2_AMOUNT);
        assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_2), whaleNFTBalance2 + RARI_ID_2_AMOUNT);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            Helpers
    //////////////////////////////////////////////////////////////*/

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

    function _approveUSDCToRecipient(uint256 amount) public {
        vm.startPrank(address(vertex));
        accounts[0].approveERC20(USDC, USDC_WHALE, amount);
        assertEq(USDC.allowance(address(accounts[0]), USDC_WHALE), amount);
        vm.stopPrank();
    }

    function _approveUSDTToRecipient(uint256 amount) public {
        vm.startPrank(address(vertex));
        accounts[0].approveERC20(USDT, USDT_WHALE, amount);
        assertEq(USDT.allowance(address(accounts[0]), USDT_WHALE), amount);
        vm.stopPrank();
    }

    function _transferUNIToAccount(uint256 amount) public {
        assertEq(UNI.balanceOf(address(accounts[0])), 0);

        vm.startPrank(UNI_WHALE);
        UNI.transfer(address(accounts[0]), amount);
        assertEq(UNI.balanceOf(address(accounts[0])), amount);
        vm.stopPrank();
    }

    function _transferBAYCToAccount(uint256 id) public {
        assertEq(BAYC.balanceOf(address(accounts[0])), 0);
        assertEq(BAYC.ownerOf(id), BAYC_WHALE);

        vm.startPrank(BAYC_WHALE);
        BAYC.transferFrom(BAYC_WHALE, address(accounts[0]), id);
        assertEq(BAYC.balanceOf(address(accounts[0])), 1);
        assertEq(BAYC.ownerOf(id), address(accounts[0]));
        vm.stopPrank();
    }

    function _approveBAYCToRecipient(uint256 id) public {
        vm.startPrank(address(vertex));
        accounts[0].approveERC721(BAYC, BAYC_WHALE, id);
        assertEq(BAYC.getApproved(id), BAYC_WHALE);
        vm.stopPrank();
    }

    function _approveOperatorBAYCToRecipient(bool approved) public {
        vm.startPrank(address(vertex));
        accounts[0].approveOperatorERC721(BAYC, BAYC_WHALE, approved);
        assertEq(BAYC.isApprovedForAll(address(accounts[0]), BAYC_WHALE), approved);
        vm.stopPrank();
    }

    function _transferNOUNSToAccount(uint256 id) public {
        assertEq(NOUNS.balanceOf(address(accounts[0])), 0);
        assertEq(NOUNS.ownerOf(id), NOUNS_WHALE);

        vm.startPrank(NOUNS_WHALE);
        NOUNS.transferFrom(NOUNS_WHALE, address(accounts[0]), id);
        assertEq(NOUNS.balanceOf(address(accounts[0])), 1);
        assertEq(NOUNS.ownerOf(id), address(accounts[0]));
        vm.stopPrank();
    }

    function _transferPUNKToAccount(uint256 id) public {
        assertEq(PUNK.balanceOf(address(accounts[0])), 0);
        assertEq(PUNK.punkIndexToAddress(id), PUNK_WHALE);

        vm.startPrank(PUNK_WHALE);
        PUNK.transferPunk(address(accounts[0]), id);
        assertEq(PUNK.balanceOf(address(accounts[0])), 1);
        assertEq(PUNK.punkIndexToAddress(id), address(accounts[0]));
        vm.stopPrank();
    }

    function _transferRARIToAccount(uint256 id, uint256 amount) public {
        assertEq(RARI.balanceOf(address(accounts[0]), id), 0);

        vm.startPrank(RARI_WHALE);
        RARI.safeTransferFrom(RARI_WHALE, address(accounts[0]), id, amount, "");
        assertEq(RARI.balanceOf(address(accounts[0]), id), amount);
        vm.stopPrank();
    }

    function _transferOPENSTOREToAccount(uint256 id, uint256 amount) public {
        assertEq(OPENSTORE.balanceOf(address(accounts[0]), id), 0);

        vm.startPrank(OPENSTORE_WHALE);
        OPENSTORE.safeTransferFrom(OPENSTORE_WHALE, address(accounts[0]), id, amount, "");
        assertEq(OPENSTORE.balanceOf(address(accounts[0]), id), amount);
        vm.stopPrank();
    }

    function _approveRARIToRecipient(bool approved) public {
        vm.startPrank(address(vertex));
        accounts[0].approveOperatorERC1155(RARI, RARI_WHALE, approved);
        assertEq(RARI.isApprovedForAll(address(accounts[0]), RARI_WHALE), approved);
        vm.stopPrank();
    }
}
