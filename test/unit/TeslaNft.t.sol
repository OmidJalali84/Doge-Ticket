// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TeslaNFT, ListedToken} from "../../src/TeslaNft.sol";
import {DogeCoin} from "../../src/Token.sol";

contract testTeslaNft is Test {
    TeslaNFT tesla;
    DogeCoin dogeCoin;

    address team = address(1);
    address futureProject = address(2);
    address charity = address(3);
    address user1 = address(4);
    address user2 = address(5);
    address user3 = address(6);
    address user4 = address(7);
    address user5 = address(8);
    address user6 = address(9);

    uint256 constant FEE_POOL = 50;
    uint256 constant FEE_TEAM = 21;
    uint256 constant FEE_FUTURE_PROJECT = 21;
    uint256 constant FEE_CHARITY = 8;
    uint256 constant FEE_SPENDER_REFERRAL = 10;
    uint256 constant FEE_OWNER_REFERRAL = 21;
    uint256 constant TOTAL_DOGE_WINNER = 10e20;

    uint256 constant ENTRY_AMOUNT = 8e23;

    function setUp() public {
        dogeCoin = new DogeCoin();
        tesla = new TeslaNFT(
            address(dogeCoin),
            team,
            futureProject,
            charity,
            FEE_POOL,
            FEE_TEAM,
            FEE_FUTURE_PROJECT,
            FEE_CHARITY,
            FEE_OWNER_REFERRAL,
            FEE_SPENDER_REFERRAL,
            TOTAL_DOGE_WINNER
        );
    }

    function createNft(
        address user,
        string memory referralcode,
        bytes32 referralOld
    ) public {
        uint256 nftToCarPercentage = tesla.getNftToCarPercentage();
        uint256 betFeePercentage = tesla.getBetFeePercentage();
        dogeCoin.transfer(
            user,
            (((ENTRY_AMOUNT * nftToCarPercentage) *
                (10000 + betFeePercentage)) / 1e8)
        );
        vm.startPrank(user);
        dogeCoin.approve(
            address(tesla),
            (((ENTRY_AMOUNT * nftToCarPercentage) *
                (10000 + betFeePercentage)) / 1e8)
        );
        tesla.createToken(
            "kshfvbksnvklwnj",
            ENTRY_AMOUNT,
            referralcode,
            referralOld,
            ENTRY_AMOUNT
        );
        vm.stopPrank();
    }

    function testSendsWinningAmountToWinner() public {
        createNft(user1, "jdchjgyfh", "wlksgnkwsgnwklg");
        createNft(user2, "ksjbvskjbvf", "alejbfakjfn");
        createNft(user3, "akeufbhikf", "askefjbakjsf");
        vm.assertEq(dogeCoin.balanceOf(user1), 12000e17);

        createNft(user4, "skejfbh", "skaefbuwksjefb");
        createNft(user5, "slefngsjk", "askejfb");
        createNft(user6, "aeskfhvbes", "amkbfskfj");
        vm.assertEq(dogeCoin.balanceOf(user2), 6126e17);
        vm.assertEq(dogeCoin.balanceOf(user4), 6126e17);
    }

    function testIfTransfersAmountToReferralOwner() public {
        createNft(user1, "referral1", "wlksgnkwsgnw");
        vm.assertEq(dogeCoin.balanceOf(user1), 0);
        bytes32 referral = tesla.getReferralCodeById(1);
        dogeCoin.transfer(user2, (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10);
        vm.startPrank(user2);
        dogeCoin.approve(
            address(tesla),
            (((ENTRY_AMOUNT * 10) / 10000) * 9) / 10
        );
        tesla.createToken("", ENTRY_AMOUNT, "jgtvujh", referral, ENTRY_AMOUNT);
        vm.stopPrank();
        uint256 tokenId = tesla.getTokenIdByReferral(referral);
        ListedToken memory token = tesla.getListedTokenFromId(tokenId);
        vm.assertEq(token.totalreferralUsed, 1);
        vm.assertEq(dogeCoin.balanceOf(user2), 0);
        vm.assertEq(dogeCoin.balanceOf(user1), 1512e17);
    }

    function testReferralOwnerChangesIfNftSales() public {
        createNft(user1, "referral1", "wlksgnkwsgnw");
        vm.prank(user1);
        tesla.transferFrom(user1, user2, 1);
        bytes32 referral = tesla.getReferralCodeById(1);

        createNft(user3, "referral2", referral);

        uint256 tokenId = tesla.getTokenIdByReferral(referral);
        ListedToken memory token = tesla.getListedTokenFromId(tokenId);
        vm.assertEq(token.totalreferralUsed, 1);
        vm.assertEq(dogeCoin.balanceOf(user1), 0);
        vm.assertEq(dogeCoin.balanceOf(user2), 1512e17);
    }

    function testTransfersAmountToOwnersOfContract() public {
        createNft(user1, "jdchjgyfh", "wlksgnkwsgnwklg");
        vm.assertEq(dogeCoin.balanceOf(team), 168e18);
        vm.assertEq(dogeCoin.balanceOf(futureProject), 168e18);
        vm.assertEq(dogeCoin.balanceOf(charity), 64e18);
    }

    function testRevertIfSomeOneUseHisOwnReferral() public {
        createNft(user1, "referral1", "wlksgnkwsgnw");
        vm.prank(user1);
        bytes32 referral = tesla.getReferralCodeById(1);
        address owner = tesla.getReferralOwner(referral);
        vm.assertEq(owner, user1);

        uint256 nftToCarPercentage = tesla.getNftToCarPercentage();
        uint256 betFeePercentage = tesla.getBetFeePercentage();
        dogeCoin.transfer(
            user1,
            (((ENTRY_AMOUNT * nftToCarPercentage) *
                (10000 + betFeePercentage)) / 1e8)
        );
        vm.startPrank(user1);
        dogeCoin.approve(
            address(tesla),
            (((ENTRY_AMOUNT * nftToCarPercentage) *
                (10000 + betFeePercentage)) / 1e8)
        );

        vm.expectRevert();
        tesla.createToken(
            "kshfvbksnvklwnj",
            ENTRY_AMOUNT,
            "referral2",
            referral,
            ENTRY_AMOUNT
        );
        vm.stopPrank();
    }
}
