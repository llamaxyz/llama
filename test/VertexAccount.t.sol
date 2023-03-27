// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";
import {TestScript} from "test/mock/scripts/TestScript.sol";
import {ICryptoPunk} from "test/mock/external/ICryptoPunk.sol";
import {
  ERC20Data,
  ERC721Data,
  ERC721OperatorData,
  ERC1155Data,
  ERC1155BatchData,
  ERC1155OperatorData,
  Strategy
} from "src/lib/Structs.sol";
import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";

contract VertexAccountTest is VertexTestSetup {
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
  uint256 public constant RARI_ID_1 = 657_774;
  uint256 public constant RARI_ID_1_AMOUNT = 3;
  uint256 public constant RARI_ID_2 = 74_385;
  uint256 public constant RARI_ID_2_AMOUNT = 1;

  IERC1155 public constant OPENSTORE = IERC1155(0x495f947276749Ce646f68AC8c248420045cb7b5e);
  address public constant OPENSTORE_WHALE = 0xaBA7161A7fb69c88e16ED9f455CE62B791EE4D03;
  uint256 public constant OPENSTORE_ID_1 =
    50_227_944_111_491_829_717_518_767_573_293_673_148_720_215_112_283_513_814_059_266_953_762_918_367_332;
  uint256 public constant OPENSTORE_ID_1_AMOUNT = 20;
  uint256 public constant OPENSTORE_ID_2 =
    25_221_312_271_773_506_578_423_917_291_534_224_130_165_348_289_584_384_465_161_209_685_514_687_348_761;
  uint256 public constant OPENSTORE_ID_2_AMOUNT = 1;

  address mpAccount1Addr;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl("mainnet"), 16_573_464);
    VertexTestSetup.setUp();
    mpAccount1Addr = address(mpAccount1); // For convenience, to avoid tons of casting to address.
  }

  /*///////////////////////////////////////////////////////////////
                            Helpers
    //////////////////////////////////////////////////////////////*/

  function transferETHToAccount(uint256 amount) internal {
    assertEq(mpAccount1Addr.balance, 0);

    vm.startPrank(ETH_WHALE);
    (bool success,) = mpAccount1Addr.call{value: amount}("");
    assertTrue(success);
    assertEq(mpAccount1Addr.balance, amount);
    vm.stopPrank();
  }

  function transferUSDCToAccount(uint256 amount) internal {
    assertEq(USDC.balanceOf(mpAccount1Addr), 0);

    vm.startPrank(USDC_WHALE);
    USDC.transfer(mpAccount1Addr, amount);
    assertEq(USDC.balanceOf(mpAccount1Addr), amount);
    vm.stopPrank();
  }

  function approveUSDCToRecipient(uint256 amount) internal {
    vm.startPrank(address(mpCore));
    mpAccount1.approveERC20(ERC20Data(USDC, USDC_WHALE, amount));
    assertEq(USDC.allowance(mpAccount1Addr, USDC_WHALE), amount);
    vm.stopPrank();
  }

  function approveUSDTToRecipient(uint256 amount) internal {
    vm.startPrank(address(mpCore));
    mpAccount1.approveERC20(ERC20Data(USDT, USDT_WHALE, amount));
    assertEq(USDT.allowance(mpAccount1Addr, USDT_WHALE), amount);
    vm.stopPrank();
  }

  function transferUNIToAccount(uint256 amount) internal {
    assertEq(UNI.balanceOf(mpAccount1Addr), 0);

    vm.startPrank(UNI_WHALE);
    UNI.transfer(mpAccount1Addr, amount);
    assertEq(UNI.balanceOf(mpAccount1Addr), amount);
    vm.stopPrank();
  }

  function transferBAYCToAccount(uint256 id) public {
    assertEq(BAYC.balanceOf(mpAccount1Addr), 0);
    assertEq(BAYC.ownerOf(id), BAYC_WHALE);

    vm.startPrank(BAYC_WHALE);
    BAYC.transferFrom(BAYC_WHALE, mpAccount1Addr, id);
    assertEq(BAYC.balanceOf(mpAccount1Addr), 1);
    assertEq(BAYC.ownerOf(id), mpAccount1Addr);
    vm.stopPrank();
  }

  function approveBAYCToRecipient(uint256 id) internal {
    vm.startPrank(address(mpCore));
    mpAccount1.approveERC721(ERC721Data(BAYC, BAYC_WHALE, id));
    assertEq(BAYC.getApproved(id), BAYC_WHALE);
    vm.stopPrank();
  }

  function approveOperatorBAYCToRecipient(bool approved) internal {
    vm.startPrank(address(mpCore));
    mpAccount1.approveOperatorERC721(ERC721OperatorData(BAYC, BAYC_WHALE, approved));
    assertEq(BAYC.isApprovedForAll(mpAccount1Addr, BAYC_WHALE), approved);
    vm.stopPrank();
  }

  function transferNOUNSToAccount(uint256 id) internal {
    assertEq(NOUNS.balanceOf(mpAccount1Addr), 0);
    assertEq(NOUNS.ownerOf(id), NOUNS_WHALE);

    vm.startPrank(NOUNS_WHALE);
    NOUNS.transferFrom(NOUNS_WHALE, mpAccount1Addr, id);
    assertEq(NOUNS.balanceOf(mpAccount1Addr), 1);
    assertEq(NOUNS.ownerOf(id), mpAccount1Addr);
    vm.stopPrank();
  }

  function transferPUNKToAccount(uint256 id) internal {
    assertEq(PUNK.balanceOf(mpAccount1Addr), 0);
    assertEq(PUNK.punkIndexToAddress(id), PUNK_WHALE);

    vm.startPrank(PUNK_WHALE);
    PUNK.transferPunk(mpAccount1Addr, id);
    assertEq(PUNK.balanceOf(mpAccount1Addr), 1);
    assertEq(PUNK.punkIndexToAddress(id), mpAccount1Addr);
    vm.stopPrank();
  }

  function transferRARIToAccount(uint256 id, uint256 amount) internal {
    assertEq(RARI.balanceOf(mpAccount1Addr, id), 0);

    vm.startPrank(RARI_WHALE);
    RARI.safeTransferFrom(RARI_WHALE, mpAccount1Addr, id, amount, "");
    assertEq(RARI.balanceOf(mpAccount1Addr, id), amount);
    vm.stopPrank();
  }

  function transferOPENSTOREToAccount(uint256 id, uint256 amount) internal {
    assertEq(OPENSTORE.balanceOf(mpAccount1Addr, id), 0);

    vm.startPrank(OPENSTORE_WHALE);
    OPENSTORE.safeTransferFrom(OPENSTORE_WHALE, mpAccount1Addr, id, amount, "");
    assertEq(OPENSTORE.balanceOf(mpAccount1Addr, id), amount);
    vm.stopPrank();
  }

  function approveRARIToRecipient(bool approved) internal {
    vm.startPrank(address(mpCore));
    mpAccount1.approveOperatorERC1155(ERC1155OperatorData(RARI, RARI_WHALE, approved));
    assertEq(RARI.isApprovedForAll(mpAccount1Addr, RARI_WHALE), approved);
    vm.stopPrank();
  }
}

contract Initialize is VertexAccountTest {
  function test_SetsVertexCore() public {
    assertEq(mpAccount1.vertex(), address(mpCore));
  }

  function test_SetsAccountName() public {
    assertEq(mpAccount1.name(), "MP Treasury");
  }

  function test_RevertIf_AlreadyInitialized() public {
    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount1.initialize("MP Treasury");
  }
}

contract Transfer is VertexAccountTest {
  function test_TransferETH() public {
    transferETHToAccount(ETH_AMOUNT);

    uint256 accountETHBalance = mpAccount1Addr.balance;
    uint256 whaleETHBalance = ETH_WHALE.balance;

    // Transfer ETH from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.transfer(payable(ETH_WHALE), ETH_AMOUNT);
    assertEq(mpAccount1Addr.balance, 0);
    assertEq(mpAccount1Addr.balance, accountETHBalance - ETH_AMOUNT);
    assertEq(ETH_WHALE.balance, whaleETHBalance + ETH_AMOUNT);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.transfer(payable(ETH_WHALE), ETH_AMOUNT);
  }

  function test_RevertIf_ToZeroAddress() public {
    vm.startPrank(address(mpCore));
    vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
    mpAccount1.transfer(payable(address(0)), ETH_AMOUNT);
    vm.stopPrank();
  }
}

contract TransferERC20 is VertexAccountTest {
  function test_TransferUSDC() public {
    transferUSDCToAccount(USDC_AMOUNT);

    uint256 accountUSDCBalance = USDC.balanceOf(mpAccount1Addr);
    uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);

    // Transfer USDC from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.transferERC20(ERC20Data(USDC, USDC_WHALE, USDC_AMOUNT));
    assertEq(USDC.balanceOf(mpAccount1Addr), 0);
    assertEq(USDC.balanceOf(mpAccount1Addr), accountUSDCBalance - USDC_AMOUNT);
    assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + USDC_AMOUNT);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.transferERC20(ERC20Data(USDC, USDC_WHALE, USDC_AMOUNT));
  }

  function test_RevertIf_ToZeroAddress() public {
    vm.startPrank(address(mpCore));
    vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
    mpAccount1.transferERC20(ERC20Data(USDC, address(0), USDC_AMOUNT));
    vm.stopPrank();
  }
}

contract BatchTransferERC20 is VertexAccountTest {
  function test_TransferUSDCAndUNI() public {
    transferUSDCToAccount(USDC_AMOUNT);
    transferUNIToAccount(UNI_AMOUNT);

    uint256 accountUSDCBalance = USDC.balanceOf(mpAccount1Addr);
    uint256 accountUNIBalance = UNI.balanceOf(mpAccount1Addr);
    uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);
    uint256 whaleUSDTBalance = UNI.balanceOf(UNI_WHALE);

    ERC20Data[] memory erc20Data = new ERC20Data[](2);
    erc20Data[0] = ERC20Data(USDC, USDC_WHALE, USDC_AMOUNT);
    erc20Data[1] = ERC20Data(UNI, UNI_WHALE, UNI_AMOUNT);

    // Transfer USDC and USDT from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.batchTransferERC20(erc20Data);
    assertEq(USDC.balanceOf(mpAccount1Addr), 0);
    assertEq(UNI.balanceOf(mpAccount1Addr), 0);
    assertEq(USDC.balanceOf(mpAccount1Addr), accountUSDCBalance - USDC_AMOUNT);
    assertEq(UNI.balanceOf(mpAccount1Addr), accountUNIBalance - UNI_AMOUNT);
    assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + USDC_AMOUNT);
    assertEq(UNI.balanceOf(UNI_WHALE), whaleUSDTBalance + UNI_AMOUNT);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    ERC20Data[] memory erc20Data = new ERC20Data[](2);

    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.batchTransferERC20(erc20Data);
  }

  function test_RevertIf_ToZeroAddress() public {
    ERC20Data[] memory erc20Data = new ERC20Data[](1);
    erc20Data[0] = ERC20Data(USDC, address(0), USDC_AMOUNT);

    vm.startPrank(address(mpCore));
    vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
    mpAccount1.batchTransferERC20(erc20Data);
    vm.stopPrank();
  }
}

contract ApproveERC20 is VertexAccountTest {
  function test_ApproveUSDC() public {
    approveUSDCToRecipient(USDC_AMOUNT);
  }

  function test_IncreaseUSDCAllowance() public {
    approveUSDCToRecipient(USDC_AMOUNT);
    approveUSDCToRecipient(0);
    approveUSDCToRecipient(USDC_AMOUNT + 1);
  }

  function test_DecreaseUSDCAllowance() public {
    approveUSDCToRecipient(USDC_AMOUNT);
    approveUSDCToRecipient(0);
    approveUSDCToRecipient(USDC_AMOUNT - 1);
  }

  function test_IncreaseUSDTAllowance() public {
    approveUSDTToRecipient(USDT_AMOUNT);
    approveUSDTToRecipient(0);
    approveUSDTToRecipient(USDT_AMOUNT + 1);
  }

  function test_DecreaseUSDTAllowance() public {
    approveUSDTToRecipient(USDT_AMOUNT);
    approveUSDTToRecipient(0);
    approveUSDTToRecipient(USDT_AMOUNT - 1);
  }

  function test_RevertIf_NotVertexMsgSender() public {
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.approveERC20(ERC20Data(USDC, USDC_WHALE, USDC_AMOUNT));
  }
}

contract BatchApproveERC20 is VertexAccountTest {
  function test_ApproveUSDCAndUNI() public {
    ERC20Data[] memory erc20Data = new ERC20Data[](2);
    erc20Data[0] = ERC20Data(USDC, USDC_WHALE, USDC_AMOUNT);
    erc20Data[1] = ERC20Data(UNI, UNI_WHALE, UNI_AMOUNT);

    // Approve USDC and UNI to whale
    vm.startPrank(address(mpCore));
    mpAccount1.batchApproveERC20(erc20Data);
    assertEq(USDC.allowance(mpAccount1Addr, USDC_WHALE), USDC_AMOUNT);
    assertEq(UNI.allowance(mpAccount1Addr, UNI_WHALE), UNI_AMOUNT);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    ERC20Data[] memory erc20Data = new ERC20Data[](2);

    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.batchApproveERC20(erc20Data);
  }
}

contract TransferERC721 is VertexAccountTest {
  function test_TransferBAYC() public {
    transferBAYCToAccount(BAYC_ID);

    uint256 accountNFTBalance = BAYC.balanceOf(mpAccount1Addr);
    uint256 whaleNFTBalance = BAYC.balanceOf(BAYC_WHALE);

    // Transfer NFT from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.transferERC721(ERC721Data(BAYC, BAYC_WHALE, BAYC_ID));
    assertEq(BAYC.balanceOf(mpAccount1Addr), 0);
    assertEq(BAYC.balanceOf(mpAccount1Addr), accountNFTBalance - 1);
    assertEq(BAYC.balanceOf(BAYC_WHALE), whaleNFTBalance + 1);
    assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.transferERC721(ERC721Data(BAYC, BAYC_WHALE, BAYC_ID));
  }

  function test_RevertIf_ToZeroAddress() public {
    vm.startPrank(address(mpCore));
    vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
    mpAccount1.transferERC721(ERC721Data(BAYC, address(0), BAYC_ID));
    vm.stopPrank();
  }
}

contract BatchTransferERC721 is VertexAccountTest {
  function test_TransferBAYCAndNOUNS() public {
    transferBAYCToAccount(BAYC_ID);
    transferNOUNSToAccount(NOUNS_ID);

    uint256 accountBAYCBalance = BAYC.balanceOf(mpAccount1Addr);
    uint256 whaleBAYCBalance = BAYC.balanceOf(BAYC_WHALE);
    uint256 accountNOUNSBalance = NOUNS.balanceOf(mpAccount1Addr);
    uint256 whaleNOUNSBalance = NOUNS.balanceOf(NOUNS_WHALE);

    ERC721Data[] memory erc721Data = new ERC721Data[](2);
    erc721Data[0] = ERC721Data(BAYC, BAYC_WHALE, BAYC_ID);
    erc721Data[1] = ERC721Data(NOUNS, NOUNS_WHALE, NOUNS_ID);

    // Transfer NFTs from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.batchTransferERC721(erc721Data);
    assertEq(BAYC.balanceOf(mpAccount1Addr), accountBAYCBalance - 1);
    assertEq(BAYC.balanceOf(BAYC_WHALE), whaleBAYCBalance + 1);
    assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);
    assertEq(NOUNS.balanceOf(mpAccount1Addr), accountNOUNSBalance - 1);
    assertEq(NOUNS.balanceOf(NOUNS_WHALE), whaleNOUNSBalance + 1);
    assertEq(NOUNS.ownerOf(NOUNS_ID), NOUNS_WHALE);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    ERC721Data[] memory erc721Data = new ERC721Data[](2);

    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.batchTransferERC721(erc721Data);
  }

  function test_RevertIf_ToZeroAddress() public {
    ERC721Data[] memory erc721Data = new ERC721Data[](1);
    erc721Data[0] = ERC721Data(BAYC, address(0), BAYC_ID);

    vm.startPrank(address(mpCore));
    vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
    mpAccount1.batchTransferERC721(erc721Data);
    vm.stopPrank();
  }
}

contract ApproveERC721 is VertexAccountTest {
  function test_ApproveBAYC() public {
    transferBAYCToAccount(BAYC_ID);
    approveBAYCToRecipient(BAYC_ID);
  }

  function test_RevertIf_NotVertexMsgSender() public {
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.approveERC721(ERC721Data(BAYC, BAYC_WHALE, BAYC_ID));
  }
}

contract BatchApproveERC721 is VertexAccountTest {
  function test_ApproveBAYCAndNOUNS() public {
    transferBAYCToAccount(BAYC_ID);
    transferNOUNSToAccount(NOUNS_ID);

    ERC721Data[] memory erc721Data = new ERC721Data[](2);
    erc721Data[0] = ERC721Data(BAYC, BAYC_WHALE, BAYC_ID);
    erc721Data[1] = ERC721Data(NOUNS, NOUNS_WHALE, NOUNS_ID);

    // Approve NFTs from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.batchApproveERC721(erc721Data);
    assertEq(BAYC.getApproved(BAYC_ID), BAYC_WHALE);
    assertEq(NOUNS.getApproved(NOUNS_ID), NOUNS_WHALE);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    ERC721Data[] memory erc721Data = new ERC721Data[](2);

    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.batchApproveERC721(erc721Data);
  }
}

contract ApproveOperatorERC721 is VertexAccountTest {
  function test_ApproveBAYC() public {
    approveOperatorBAYCToRecipient(true);
  }

  function test_DisapproveBAYC() public {
    approveOperatorBAYCToRecipient(false);
  }

  function test_RevertIf_NotVertexMsgSender() public {
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.approveOperatorERC721(ERC721OperatorData(BAYC, BAYC_WHALE, true));
  }
}

contract BatchApproveOperatorERC721 is VertexAccountTest {
  function test_ApproveBAYCAndNOUNS() public {
    ERC721OperatorData[] memory erc721OperatorData = new ERC721OperatorData[](2);
    erc721OperatorData[0] = ERC721OperatorData(BAYC, BAYC_WHALE, true);
    erc721OperatorData[1] = ERC721OperatorData(NOUNS, NOUNS_WHALE, true);

    // Approve NFTs from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.batchApproveOperatorERC721(erc721OperatorData);
    assertEq(BAYC.isApprovedForAll(mpAccount1Addr, BAYC_WHALE), true);
    assertEq(NOUNS.isApprovedForAll(mpAccount1Addr, NOUNS_WHALE), true);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    ERC721OperatorData[] memory erc721OperatorData = new ERC721OperatorData[](2);

    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.batchApproveOperatorERC721(erc721OperatorData);
  }
}

contract TransferERC1155 is VertexAccountTest {
  function test_TransferRARI() public {
    transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);

    uint256 accountNFTBalance = RARI.balanceOf(mpAccount1Addr, RARI_ID_1);
    uint256 whaleNFTBalance = RARI.balanceOf(RARI_WHALE, RARI_ID_1);

    // Transfer NFT from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.transferERC1155(ERC1155Data(RARI, RARI_WHALE, RARI_ID_1, RARI_ID_1_AMOUNT, ""));
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_1), 0);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_1), accountNFTBalance - RARI_ID_1_AMOUNT);
    assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_1), whaleNFTBalance + RARI_ID_1_AMOUNT);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.transferERC1155(ERC1155Data(RARI, RARI_WHALE, RARI_ID_1, RARI_ID_1_AMOUNT, ""));
  }

  function test_RevertIf_ToZeroAddress() public {
    vm.startPrank(address(mpCore));
    vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
    mpAccount1.transferERC1155(ERC1155Data(RARI, address(0), RARI_ID_1, RARI_ID_1_AMOUNT, ""));
    vm.stopPrank();
  }
}

contract BatchTransferSingleERC1155 is VertexAccountTest {
  function test_TransferRARI() public {
    transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);
    transferRARIToAccount(RARI_ID_2, RARI_ID_2_AMOUNT);

    uint256 accountNFTBalance1 = RARI.balanceOf(mpAccount1Addr, RARI_ID_1);
    uint256 whaleNFTBalance1 = RARI.balanceOf(RARI_WHALE, RARI_ID_1);
    uint256 accountNFTBalance2 = RARI.balanceOf(mpAccount1Addr, RARI_ID_2);
    uint256 whaleNFTBalance2 = RARI.balanceOf(RARI_WHALE, RARI_ID_2);

    uint256[] memory tokenIDs = new uint256[](2);
    tokenIDs[0] = RARI_ID_1;
    tokenIDs[1] = RARI_ID_2;

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = RARI_ID_1_AMOUNT;
    amounts[1] = RARI_ID_2_AMOUNT;

    // Transfer NFT from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.batchTransferSingleERC1155(ERC1155BatchData(RARI, RARI_WHALE, tokenIDs, amounts, ""));
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_1), 0);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_1), accountNFTBalance1 - RARI_ID_1_AMOUNT);
    assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_1), whaleNFTBalance1 + RARI_ID_1_AMOUNT);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_2), 0);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_2), accountNFTBalance2 - RARI_ID_2_AMOUNT);
    assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_2), whaleNFTBalance2 + RARI_ID_2_AMOUNT);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    uint256[] memory tokenIDs = new uint256[](2);
    tokenIDs[0] = RARI_ID_1;
    tokenIDs[1] = RARI_ID_2;

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = RARI_ID_1_AMOUNT;
    amounts[1] = RARI_ID_2_AMOUNT;

    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.batchTransferSingleERC1155(ERC1155BatchData(RARI, RARI_WHALE, tokenIDs, amounts, ""));
  }

  function test_RevertIf_ToZeroAddress() public {
    uint256[] memory tokenIDs = new uint256[](2);
    tokenIDs[0] = RARI_ID_1;
    tokenIDs[1] = RARI_ID_2;

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = RARI_ID_1_AMOUNT;
    amounts[1] = RARI_ID_2_AMOUNT;

    vm.startPrank(address(mpCore));
    vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
    mpAccount1.batchTransferSingleERC1155(ERC1155BatchData(RARI, address(0), tokenIDs, amounts, ""));
    vm.stopPrank();
  }
}

contract BatchTransferMultipleERC1155 is VertexAccountTest {
  function test_TransferRARIAndOPENSTORE() public {
    transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);
    transferRARIToAccount(RARI_ID_2, RARI_ID_2_AMOUNT);
    transferOPENSTOREToAccount(OPENSTORE_ID_1, OPENSTORE_ID_1_AMOUNT);
    transferOPENSTOREToAccount(OPENSTORE_ID_2, OPENSTORE_ID_2_AMOUNT);

    uint256 whaleRARIBalance1 = RARI.balanceOf(RARI_WHALE, RARI_ID_1);
    uint256 whaleRARIBalance2 = RARI.balanceOf(RARI_WHALE, RARI_ID_2);
    uint256 whaleOPENSTOREBalance1 = OPENSTORE.balanceOf(OPENSTORE_WHALE, OPENSTORE_ID_1);
    uint256 whaleOPENSTOREBalance2 = OPENSTORE.balanceOf(OPENSTORE_WHALE, OPENSTORE_ID_2);

    uint256[] memory tokenIDs1 = new uint256[](2);
    tokenIDs1[0] = RARI_ID_1;
    tokenIDs1[1] = RARI_ID_2;

    uint256[] memory tokenIDs2 = new uint256[](2);
    tokenIDs2[0] = OPENSTORE_ID_1;
    tokenIDs2[1] = OPENSTORE_ID_2;

    uint256[] memory amounts1 = new uint256[](2);
    amounts1[0] = RARI_ID_1_AMOUNT;
    amounts1[1] = RARI_ID_2_AMOUNT;

    uint256[] memory amounts2 = new uint256[](2);
    amounts2[0] = OPENSTORE_ID_1_AMOUNT;
    amounts2[1] = OPENSTORE_ID_2_AMOUNT;

    ERC1155BatchData[] memory erc1155BatchData = new ERC1155BatchData[](2);
    erc1155BatchData[0] = ERC1155BatchData(RARI, RARI_WHALE, tokenIDs1, amounts1, "");
    erc1155BatchData[1] = ERC1155BatchData(OPENSTORE, OPENSTORE_WHALE, tokenIDs2, amounts2, "");

    // Transfer NFT from account to whale
    vm.startPrank(address(mpCore));
    mpAccount1.batchTransferMultipleERC1155(erc1155BatchData);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_1), 0);
    assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_1), whaleRARIBalance1 + RARI_ID_1_AMOUNT);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_2), 0);
    assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_2), whaleRARIBalance2 + RARI_ID_2_AMOUNT);
    assertEq(OPENSTORE.balanceOf(mpAccount1Addr, OPENSTORE_ID_1), 0);
    assertEq(OPENSTORE.balanceOf(OPENSTORE_WHALE, OPENSTORE_ID_1), whaleOPENSTOREBalance1 + OPENSTORE_ID_1_AMOUNT);
    assertEq(OPENSTORE.balanceOf(mpAccount1Addr, OPENSTORE_ID_2), 0);
    assertEq(OPENSTORE.balanceOf(OPENSTORE_WHALE, OPENSTORE_ID_2), whaleOPENSTOREBalance2 + OPENSTORE_ID_2_AMOUNT);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    ERC1155BatchData[] memory erc1155BatchData = new ERC1155BatchData[](2);
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.batchTransferMultipleERC1155(erc1155BatchData);
  }

  function test_RevertIf_ToZeroAddress() public {
    uint256[] memory tokenIDs = new uint256[](1);
    uint256[] memory amounts = new uint256[](1);
    ERC1155BatchData[] memory erc1155BatchData = new ERC1155BatchData[](1);
    erc1155BatchData[0] = ERC1155BatchData(RARI, address(0), tokenIDs, amounts, "");

    vm.startPrank(address(mpCore));
    vm.expectRevert(VertexAccount.Invalid0xRecipient.selector);
    mpAccount1.batchTransferMultipleERC1155(erc1155BatchData);
    vm.stopPrank();
  }
}

contract ApproveOperatorERC1155 is VertexAccountTest {
  function test_ApproveRARI() public {
    approveRARIToRecipient(true);
  }

  function test_DisapproveRARI() public {
    approveRARIToRecipient(false);
  }

  function test_RevertIf_NotVertexMsgSender() public {
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.approveOperatorERC1155(ERC1155OperatorData(RARI, RARI_WHALE, true));
  }
}

contract BatchApproveOperatorERC1155 is VertexAccountTest {
  function test_ApproveRARIAndOPENSTORE() public {
    ERC1155OperatorData[] memory erc1155OperatorData = new ERC1155OperatorData[](2);
    erc1155OperatorData[0] = ERC1155OperatorData(RARI, RARI_WHALE, true);
    erc1155OperatorData[1] = ERC1155OperatorData(OPENSTORE, OPENSTORE_WHALE, true);

    vm.startPrank(address(mpCore));
    mpAccount1.batchApproveOperatorERC1155(erc1155OperatorData);
    assertEq(RARI.isApprovedForAll(mpAccount1Addr, RARI_WHALE), true);
    assertEq(OPENSTORE.isApprovedForAll(mpAccount1Addr, OPENSTORE_WHALE), true);
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    ERC1155OperatorData[] memory erc1155OperatorData = new ERC1155OperatorData[](2);
    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.batchApproveOperatorERC1155(erc1155OperatorData);
  }
}

contract Execute is VertexAccountTest {
  function test_CallCryptoPunk() public {
    // Transfer Punk to Account to have it stuck in the Vertex Account
    transferPUNKToAccount(PUNK_ID);

    uint256 accountNFTBalance = PUNK.balanceOf(mpAccount1Addr);
    uint256 whaleNFTBalance = PUNK.balanceOf(PUNK_WHALE);

    // Rescue Punk by calling execute call
    vm.startPrank(address(mpCore));
    mpAccount1.execute(
      address(PUNK), abi.encodeWithSelector(ICryptoPunk.transferPunk.selector, PUNK_WHALE, PUNK_ID), false
    );
    assertEq(PUNK.balanceOf(mpAccount1Addr), 0);
    assertEq(PUNK.balanceOf(mpAccount1Addr), accountNFTBalance - 1);
    assertEq(PUNK.balanceOf(PUNK_WHALE), whaleNFTBalance + 1);
    assertEq(PUNK.punkIndexToAddress(PUNK_ID), PUNK_WHALE);
    vm.stopPrank();
  }

  function test_DelegateCallTestScript() public {
    TestScript testScript = new TestScript();

    vm.startPrank(address(mpCore));
    bytes memory result =
      mpAccount1.execute(address(testScript), abi.encodePacked(TestScript.testFunction.selector, ""), true);
    assertEq(10, uint256(bytes32(result)));
    vm.stopPrank();
  }

  function test_RevertIf_NotVertexMsgSender() public {
    TestScript testScript = new TestScript();

    vm.expectRevert(VertexAccount.OnlyVertex.selector);
    mpAccount1.execute(address(testScript), abi.encodePacked(TestScript.testFunction.selector, ""), true);
  }

  function test_RevertIf_NotSuccess() public {
    TestScript testScript = new TestScript();

    vm.startPrank(address(mpCore));
    vm.expectRevert(abi.encodeWithSelector(VertexAccount.FailedExecution.selector, ""));
    mpAccount1.execute(address(testScript), abi.encodePacked("", ""), true);
    vm.stopPrank();
  }
}

contract Integration is VertexAccountTest {
  // Test that VertexAccount can receive ETH
  function test_ReceiveETH() public {
    transferETHToAccount(ETH_AMOUNT);
  }

  // Test that VertexAccount can receive ERC20 tokens
  function test_ReceiveERC20() public {
    transferUSDCToAccount(USDC_AMOUNT);
  }

  // Test that approved ERC20 tokens can be transferred from VertexAccount to a recipient
  function test_TransferApprovedERC20() public {
    transferUSDCToAccount(USDC_AMOUNT);
    approveUSDCToRecipient(USDC_AMOUNT);

    uint256 accountUSDCBalance = USDC.balanceOf(mpAccount1Addr);
    uint256 whaleUSDCBalance = USDC.balanceOf(USDC_WHALE);

    // Transfer USDC from account to whale
    vm.startPrank(USDC_WHALE);
    USDC.transferFrom(mpAccount1Addr, USDC_WHALE, USDC_AMOUNT);
    assertEq(USDC.balanceOf(mpAccount1Addr), 0);
    assertEq(USDC.balanceOf(mpAccount1Addr), accountUSDCBalance - USDC_AMOUNT);
    assertEq(USDC.balanceOf(USDC_WHALE), whaleUSDCBalance + USDC_AMOUNT);
    vm.stopPrank();
  }

  // Test that VertexAccount can receive ERC721 tokens
  function test_ReceiveERC721() public {
    transferBAYCToAccount(BAYC_ID);
  }

  // Test that VertexAccount can safe receive ERC721 tokens
  function test_SafeReceiveERC721() public {
    assertEq(BAYC.balanceOf(mpAccount1Addr), 0);
    assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);

    vm.startPrank(BAYC_WHALE);
    BAYC.safeTransferFrom(BAYC_WHALE, mpAccount1Addr, BAYC_ID);
    assertEq(BAYC.balanceOf(mpAccount1Addr), 1);
    assertEq(BAYC.ownerOf(BAYC_ID), mpAccount1Addr);
    vm.stopPrank();
  }

  // Test that approved ERC721 tokens can be transferred from VertexAccount to a recipient
  function test_TransferApprovedERC721() public {
    transferBAYCToAccount(BAYC_ID);
    approveBAYCToRecipient(BAYC_ID);

    uint256 accountNFTBalance = BAYC.balanceOf(mpAccount1Addr);
    uint256 whaleNFTBalance = BAYC.balanceOf(BAYC_WHALE);

    // Transfer NFT from account to whale
    vm.startPrank(BAYC_WHALE);
    BAYC.transferFrom(mpAccount1Addr, BAYC_WHALE, BAYC_ID);
    assertEq(BAYC.balanceOf(mpAccount1Addr), 0);
    assertEq(BAYC.balanceOf(mpAccount1Addr), accountNFTBalance - 1);
    assertEq(BAYC.balanceOf(BAYC_WHALE), whaleNFTBalance + 1);
    assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);
    vm.stopPrank();
  }

  // Test that approved Operator ERC721 tokens can be transferred from VertexAccount to a recipient
  function test_TransferApprovedOperatorERC721() public {
    vm.startPrank(BAYC_WHALE);
    BAYC.transferFrom(BAYC_WHALE, mpAccount1Addr, BAYC_ID);
    BAYC.transferFrom(BAYC_WHALE, mpAccount1Addr, BAYC_ID_2);
    vm.stopPrank();
    approveOperatorBAYCToRecipient(true);

    uint256 accountNFTBalance = BAYC.balanceOf(mpAccount1Addr);
    uint256 whaleNFTBalance = BAYC.balanceOf(BAYC_WHALE);

    // Transfer NFT from account to whale
    vm.startPrank(BAYC_WHALE);
    BAYC.transferFrom(mpAccount1Addr, BAYC_WHALE, BAYC_ID);
    BAYC.transferFrom(mpAccount1Addr, BAYC_WHALE, BAYC_ID_2);
    assertEq(BAYC.balanceOf(mpAccount1Addr), 0);
    assertEq(BAYC.balanceOf(mpAccount1Addr), accountNFTBalance - 2);
    assertEq(BAYC.balanceOf(BAYC_WHALE), whaleNFTBalance + 2);
    assertEq(BAYC.ownerOf(BAYC_ID), BAYC_WHALE);
    assertEq(BAYC.ownerOf(BAYC_ID_2), BAYC_WHALE);
    vm.stopPrank();
  }

  // Test that VertexAccount can receive ERC1155 tokens
  function test_ReceiveERC1155() public {
    transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);
  }

  // Test that approved ERC1155 tokens can be transferred from VertexAccount to a recipient
  function test_TransferApprovedERC1155() public {
    transferRARIToAccount(RARI_ID_1, RARI_ID_1_AMOUNT);
    transferRARIToAccount(RARI_ID_2, RARI_ID_2_AMOUNT);
    approveRARIToRecipient(true);

    uint256 accountNFTBalance1 = RARI.balanceOf(mpAccount1Addr, RARI_ID_1);
    uint256 whaleNFTBalance1 = RARI.balanceOf(RARI_WHALE, RARI_ID_1);
    uint256 accountNFTBalance2 = RARI.balanceOf(mpAccount1Addr, RARI_ID_2);
    uint256 whaleNFTBalance2 = RARI.balanceOf(RARI_WHALE, RARI_ID_2);

    uint256[] memory tokenIDs = new uint256[](2);
    tokenIDs[0] = RARI_ID_1;
    tokenIDs[1] = RARI_ID_2;

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = RARI_ID_1_AMOUNT;
    amounts[1] = RARI_ID_2_AMOUNT;

    // Transfer NFT from account to whale
    vm.startPrank(address(RARI_WHALE));
    RARI.safeBatchTransferFrom(mpAccount1Addr, RARI_WHALE, tokenIDs, amounts, "");
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_1), 0);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_1), accountNFTBalance1 - RARI_ID_1_AMOUNT);
    assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_1), whaleNFTBalance1 + RARI_ID_1_AMOUNT);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_2), 0);
    assertEq(RARI.balanceOf(mpAccount1Addr, RARI_ID_2), accountNFTBalance2 - RARI_ID_2_AMOUNT);
    assertEq(RARI.balanceOf(RARI_WHALE, RARI_ID_2), whaleNFTBalance2 + RARI_ID_2_AMOUNT);
    vm.stopPrank();
  }
}
