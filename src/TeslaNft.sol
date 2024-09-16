//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

contract TeslaNFT is ERC721URIStorage {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DogeTicket__OnlyOwner(address account);
    error DogeTicket__ReferralCanNotBeUsedByReferralOwner();
    error DogeTicket__ReferralAlreadyCreated();
    error DogeTicket__ReentrencyCall();
    error DogeTicket__TransferFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    //Mappings
    mapping(uint256 => ListedToken) private idToListedToken;
    mapping(uint256 tokenId => bytes32 referral) private tokenIdToReferral;
    mapping(bytes32 referralCode => uint256 tokenId) private referralToTokenId;
    mapping(bytes32 referralCode => address ownerReferralCode)
        private referralToOwner;
    mapping(bytes32 referralCode => bool hasCreated) private referralHasCreated;

    Player[] private totalPlayers;
    Player[] private newplayers;

    //Counter Variables
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    //Initial Variables
    address public immutable dogeCoinToken;
    uint256 public nftToCarPecentage = 10;
    uint256 public betFeePercentage = 0;
    uint256 public totalDogeWinner;
    address payable owner;
    uint256 public betId = 1;
    address public team;
    address public futureProject;
    address public charity;
    uint256 public feePool;
    uint256 public feeTeam;
    uint256 public feeFutureProject;
    uint256 public feeCharity;
    uint256 public feeOwnerReferral;
    uint256 public feeSpenderReferral;
    uint256 public totalPool;

    //Getter variables
    address public recentTotalWinner;
    address public recentNewWinner;
    uint256 public lastTotalReward;
    uint256 public lastNewReward;

    //Reentrency Lock Variables
    bool private createLock = false;
    bool private winnerTotalLock = false;
    bool private winnerNewLock = false;

    struct ListedToken {
        string tokenURI;
        uint256 tokenId;
        uint256 betId;
        address payable owner;
        uint256 price;
        bytes32 refral;
        uint256 totalreferralUsed;
        bool listed;
        uint256 totalPriceUSD;
    }

    struct Player {
        uint256 bet_Id;
        uint256 nft_Id;
        uint256 amount;
        uint256 time;
        address payable nftAddress;
        uint256 totalPriceUSD;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert DogeTicket__OnlyOwner(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event CreateNft(
        uint256 indexed tokenId,
        address indexed _address,
        string _tokenURI,
        uint256 indexed _lotteryId,
        uint256 _timestamp,
        bytes32 _referralCode,
        uint256 _totalPriceUSD
    );
    event CreateBet(
        uint256 indexed _lotteryId,
        uint256 _totalPlayers,
        uint256 _nftIdWinner_Players,
        address indexed _winnerPlayers,
        uint256 _amount,
        uint256 _time
    );

    event CreateNewBet(
        uint256 indexed _lotteryId,
        uint256 _totalPlayers,
        uint256 _nftIdWinner_Players,
        address indexed _winnerPlayers,
        uint256 _amount,
        uint256 _time
    );

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _token,
        address _team,
        address _futureProject,
        address _charity,
        uint256 _feePool,
        uint256 _feeTeam,
        uint256 _feeFutureProject,
        uint256 _feeCharity,
        uint256 _feeOwnerRefral,
        uint256 _feeSpenderReferral,
        uint256 _totalDogeWinner
    ) ERC721("Tesla-DogeChance", "TDC") {
        owner = payable(msg.sender);
        team = _team;
        futureProject = _futureProject;
        charity = _charity;
        feePool = _feePool;
        feeTeam = _feeTeam;
        feeFutureProject = _feeFutureProject;
        feeCharity = _feeCharity;
        feeOwnerReferral = _feeOwnerRefral;
        feeSpenderReferral = _feeSpenderReferral;
        totalDogeWinner = _totalDogeWinner;
        dogeCoinToken = _token;
    }

    /*//////////////////////////////////////////////////////////////
                           ERC721 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        super.transferFrom(from, to, tokenId);
        bytes32 referral = tokenIdToReferral[tokenId];
        referralToOwner[referral] = to;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(ERC721, IERC721) {
        super.safeTransferFrom(from, to, tokenId, data);
        bytes32 referral = tokenIdToReferral[tokenId];
        referralToOwner[referral] = to;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createToken(
        string memory tokenURI,
        uint256 totalCarPrice,
        string memory _referralCode,
        bytes32 _upReferral,
        uint256 _totalPriceUSD
    ) external {
        if (createLock) {
            revert DogeTicket__ReentrencyCall();
        }
        createLock = true;

        bytes32 referralCode = generate_bytes_refral(_referralCode);
        if (referralHasCreated[referralCode]) {
            revert DogeTicket__ReferralAlreadyCreated();
        }
        referralHasCreated[referralCode] = true;

        _tokenIds.increment();
        uint256 currentTokenId = _tokenIds.current();
        _safeMint(msg.sender, currentTokenId);
        _setTokenURI(currentTokenId, tokenURI);

        uint256 mintPrice = (totalCarPrice * nftToCarPecentage) / 10000;
        mintPrice = ((mintPrice * (10000 + betFeePercentage)) / 10000);

        if (referralToOwner[_upReferral] != address(0)) {
            if (referralToOwner[_upReferral] == msg.sender) {
                revert DogeTicket__ReferralCanNotBeUsedByReferralOwner();
            }

            mintPrice = (mintPrice * (100 - feeSpenderReferral)) / 100;

            bool success = IERC20(dogeCoinToken).transferFrom(
                msg.sender,
                address(this),
                mintPrice
            );
            if (!success) {
                revert DogeTicket__TransferFailed();
            }

            uint256 referralReward = (mintPrice * feeOwnerReferral) / 100;
            transferToReferral(referralToOwner[_upReferral], referralReward);
            idToListedToken[referralToTokenId[_upReferral]].totalreferralUsed++;

            mintPrice = (mintPrice * (100 - feeOwnerReferral)) / 100;

            transferToMgmts(mintPrice);

            totalPool += (mintPrice * feePool) / 100;

            referralToOwner[referralCode] = msg.sender;
            tokenIdToReferral[currentTokenId] = referralCode;
            referralToTokenId[referralCode] = currentTokenId;

            idToListedToken[currentTokenId] = ListedToken(
                tokenURI,
                currentTokenId,
                betId,
                payable(msg.sender),
                mintPrice,
                referralCode,
                0,
                true,
                _totalPriceUSD
            );

            totalPlayers.push(
                Player({
                    bet_Id: betId,
                    nft_Id: currentTokenId,
                    amount: mintPrice,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceUSD: _totalPriceUSD
                })
            );
            newplayers.push(
                Player({
                    bet_Id: betId,
                    nft_Id: currentTokenId,
                    amount: mintPrice,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceUSD: _totalPriceUSD
                })
            );
            emit CreateNft(
                currentTokenId,
                msg.sender,
                tokenURI,
                betId,
                block.timestamp,
                referralCode,
                _totalPriceUSD
            );
        } else {
            bool success = IERC20(dogeCoinToken).transferFrom(
                msg.sender,
                address(this),
                mintPrice
            );
            if (!success) {
                revert DogeTicket__TransferFailed();
            }

            transferToMgmts(mintPrice);

            totalPool += (mintPrice * feePool) / 100;

            referralToOwner[referralCode] = msg.sender;
            tokenIdToReferral[currentTokenId] = referralCode;

            idToListedToken[currentTokenId] = ListedToken(
                tokenURI,
                currentTokenId,
                betId,
                payable(msg.sender),
                mintPrice,
                referralCode,
                0,
                true,
                _totalPriceUSD
            );

            totalPlayers.push(
                Player({
                    bet_Id: betId,
                    nft_Id: currentTokenId,
                    amount: mintPrice,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceUSD: _totalPriceUSD
                })
            );
            newplayers.push(
                Player({
                    bet_Id: betId,
                    nft_Id: currentTokenId,
                    amount: mintPrice,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceUSD: _totalPriceUSD
                })
            );
            emit CreateNft(
                currentTokenId,
                msg.sender,
                tokenURI,
                betId,
                block.timestamp,
                referralCode,
                _totalPriceUSD
            );
        }

        if (totalPool >= totalDogeWinner) {
            createWinnerTotalPlayers("code");
        }
        createLock = false;
    }

    /*//////////////////////////////////////////////////////////////
                          NTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createWinnerTotalPlayers(string memory _code) internal {
        if (createLock) {
            revert DogeTicket__ReentrencyCall();
        }
        winnerTotalLock = true;

        uint256 winnerTotalPlayer = _randomModulo(totalPlayers.length, _code);
        uint256 _tokenId = totalPlayers[winnerTotalPlayer].nft_Id;
        address winnerTotalPlayerAddress = totalPlayers[winnerTotalPlayer]
            .nftAddress == ownerOf(_tokenId)
            ? totalPlayers[winnerTotalPlayer].nftAddress
            : ownerOf(_tokenId);

        // uint256 p_winner=totalPlayers[winnerTotalPlayer].amount ;
        uint256 priceWinner = totalPool / 2;

        bool success = IERC20(dogeCoinToken).transfer(
            payable(winnerTotalPlayerAddress),
            priceWinner
        );

        if (!success) {
            revert DogeTicket__TransferFailed();
        }

        emit CreateBet(
            betId,
            totalPlayers.length,
            totalPlayers[winnerTotalPlayer].nft_Id,
            winnerTotalPlayerAddress,
            priceWinner,
            block.timestamp
        );
        deleteIndexArray(winnerTotalPlayer);
        totalPool -= priceWinner;
        lastTotalReward = priceWinner;
        recentTotalWinner = winnerTotalPlayerAddress;

        createWinnerNewPlayers("code");
        winnerTotalLock = false;
    }

    function createWinnerNewPlayers(string memory _code) internal {
        if (createLock) {
            revert DogeTicket__ReentrencyCall();
        }
        winnerNewLock = true;
        uint256 winnerNewPlayer = _randomModulo(newplayers.length, _code);
        uint256 _tokenId = newplayers[winnerNewPlayer].nft_Id;
        address winnerNewPlayerAddress = newplayers[winnerNewPlayer]
            .nftAddress == ownerOf(_tokenId)
            ? newplayers[winnerNewPlayer].nftAddress
            : ownerOf(_tokenId);

        // uint256 p_winner=totalPlayers[winnerNewPlayer].amount;
        uint256 priceWinner = totalPool;

        bool success = IERC20(dogeCoinToken).transfer(
            payable(winnerNewPlayerAddress),
            priceWinner
        );

        if (!success) {
            revert DogeTicket__TransferFailed();
        }

        emit CreateNewBet(
            betId,
            newplayers.length,
            newplayers[winnerNewPlayer].nft_Id,
            winnerNewPlayerAddress,
            priceWinner,
            block.timestamp
        );

        recentNewWinner = winnerNewPlayerAddress;
        lastNewReward = priceWinner;
        delete newplayers;
        totalPool = 0;
        betId++;
        betFeePercentage = betFeePercentage + 210;
        winnerNewLock = false;
    }

    function transferToMgmts(uint256 amount) internal {
        bool success1 = IERC20(dogeCoinToken).transfer(
            team,
            (amount * feeTeam) / 100
        );

        bool success2 = IERC20(dogeCoinToken).transfer(
            futureProject,
            (amount * feeFutureProject) / 100
        );

        bool success3 = IERC20(dogeCoinToken).transfer(
            charity,
            (amount * feeCharity) / 100
        );

        if (!success1 || !success2 || !success3) {
            revert DogeTicket__TransferFailed();
        }
    }

    function transferToReferral(
        address referralOwner,
        uint256 amount
    ) internal {
        bool success = IERC20(dogeCoinToken).transfer(referralOwner, amount);

        if (!success) {
            revert DogeTicket__TransferFailed();
        }
    }

    function generate_bytes_refral(
        string memory _pass
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_pass));
    }

    function _randomModulo(
        uint256 madulo,
        string memory code
    ) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, code))) %
            madulo;
    }

    function deleteIndexArray(uint256 index) internal {
        for (uint256 i = index; i < totalPlayers.length - 1; i++) {
            totalPlayers[i] = totalPlayers[i + 1];
        }
        totalPlayers.pop();
    }

    /*//////////////////////////////////////////////////////////////
                       VIEW AND PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (ownerOf(i + 1) == msg.sender) {
                itemCount += 1;
            }
        }

        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (ownerOf(i + 1) == msg.sender) {
                uint256 currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint256 nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);

        uint256 currentIndex = 0;
        for (uint256 i = 0; i < nftCount; i++) {
            uint256 currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return tokens;
    }

    function getTotalPlayers() public view returns (Player[] memory) {
        return totalPlayers;
    }

    function getNewPlayers() public view returns (Player[] memory) {
        return newplayers;
    }

    function getTotalPool() public view returns (uint256) {
        return totalPool;
    }

    function getTotalDogeWinner() public view returns (uint256) {
        return totalDogeWinner;
    }

    function getOwnerAddress() public view returns (address) {
        return owner;
    }

    function getRecentTotalWinner() public view returns (address) {
        return recentTotalWinner;
    }

    function getRecentNewWinner() public view returns (address) {
        return recentNewWinner;
    }

    function getReferralCodeById(
        uint256 tokenId
    ) public view returns (bytes32) {
        return tokenIdToReferral[tokenId];
    }

    function getReferralOwner(bytes32 referral) public view returns (address) {
        return referralToOwner[referral];
    }

    function getTokenIdByReferral(
        bytes32 referral
    ) public view returns (uint256) {
        return referralToTokenId[referral];
    }

    function getNftToCarPercentage() public view returns (uint256) {
        return nftToCarPecentage;
    }

    function getBetFeePercentage() public view returns (uint256) {
        return betFeePercentage;
    }

    function getListedTokenFromId(
        uint256 tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getBetId() public view returns (uint256) {
        return betId;
    }

    function getLastTotalReward() public view returns (uint256) {
        return lastTotalReward;
    }

    function getLastNewReward() public view returns (uint256) {
        return lastNewReward;
    }

    function getReferralHasCreated(
        string memory referralString
    ) public view returns (bool) {
        bytes32 referralBytes = keccak256(abi.encodePacked(referralString));
        return referralHasCreated[referralBytes];
    }
}
