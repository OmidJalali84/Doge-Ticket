//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TeslaNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;
    Counters.Counter private _itemsSold;

    address private TokenDoge = 0x50dA1888a5e65F387FFC13d2624b3551397FF757;
    uint public percentPrice = 30;
    uint private totalDogeWinner;
    address payable ownerContract;
    uint public BetId = 1;
    address private mgmt1;
    address private mgmt2;
    uint private totalBalance;
    uint private feePool;
    uint private feeMgmt;
    uint private feeRefral;
    uint private totalPool;
    uint private totalMgmt;
    uint private totalRefral;

    enum State {
        IDLE,
        BETTING,
        WINNER
    }

    State public currentState = State.IDLE;

    struct ListedToken {
        string tokenURI;
        uint256 tokenId;
        uint256 betId;
        address payable owner;
        uint256 price;
        bytes32 refral;
        bool listed;
        uint totalPriceDoge;
    }

    struct Player {
        uint bet_Id;
        uint nft_Id;
        uint amount;
        uint time;
        address payable nftAddress;
        uint totalPriceDoge;
    }
    struct BetPlayer {
        address[] players;
        uint amountRefral;
    }

    struct Refral {
        bytes32 refralCode;
    }

    struct OwnerRefral {
        bool add;
    }

    mapping(string => Refral) private refralList;
    mapping(string => BetPlayer) private betPlayers;
    mapping(uint256 => ListedToken) private idToListedToken;
    mapping(bytes32 => string) private HashToRefral;
    mapping(string => mapping(address => mapping(uint => OwnerRefral)))
        private ownerRefral;
    Player[] private Totalplayers;
    Player[] private newplayers;

    modifier onlyAdmin() {
        require(msg.sender == ownerContract, "Only Admin");
        _;
    }
    modifier inState(State state) {
        require(currentState == state, "current state does not allow this");
        _;
    }

    event createNft(
        uint indexed tokenId,
        address indexed _address,
        string _tokenURI,
        uint indexed _lotteryId,
        uint _timestamp,
        bytes32 _refralcode,
        uint _totalPriceDoge
    );
    event createProgram(
        uint _betId,
        address indexed mgmt1,
        address indexed mgmt2,
        uint feePool,
        uint feeMgmt,
        uint feeRefral,
        uint _totalDogeWinner,
        uint _time
    );

    event CreateBet(
        uint indexed _lotteryId,
        uint _totalPlayers,
        uint _nftIdWinner_Players,
        address indexed _winnerPlayers,
        uint _amount,
        uint _time
    );

    event CreateNewBet(
        uint indexed _lotteryId,
        uint _totalPlayers,
        uint _nftIdWinner_Players,
        address indexed _winnerPlayers,
        uint _amount,
        uint _time
    );

    constructor() ERC721("Tesla-DogeChance", "TDC") {
        ownerContract = payable(msg.sender);
    }

    function createBet(
        address _mgmt1,
        address _mgmt2,
        uint _feePool,
        uint _feeMgmt,
        uint _feeRefral,
        uint _totalDogeWinner
    ) public onlyAdmin inState(State.IDLE) {
        mgmt1 = _mgmt1;
        mgmt2 = _mgmt2;
        feePool = _feePool;
        feeMgmt = _feeMgmt;
        feeRefral = _feeRefral;
        currentState = State.BETTING;
        totalDogeWinner = _totalDogeWinner;

        emit createProgram(
            BetId,
            _mgmt1,
            _mgmt2,
            feePool,
            feeMgmt,
            feeRefral,
            totalDogeWinner,
            block.timestamp
        );
    }

    function createToken(
        string memory tokenURI,
        uint256 _price,
        string memory _refralCode,
        string memory _refralOld,
        uint _totalPriceDoge
    ) public inState(State.BETTING) {
        require(
            _price <= (IERC20(TokenDoge).allowance(msg.sender, address(this))),
            "not Enough price"
        );
        bytes32 refralCode = generate_bytes_refral(_refralOld);
        _tokenIds.increment();
        uint256 currentTokenId = _tokenIds.current();
        _safeMint(msg.sender, currentTokenId);
        _setTokenURI(currentTokenId, tokenURI);

        if (refralCode == refralList[_refralOld].refralCode) {
            uint price = ((_price * (100 - (100 - feeRefral))) / 100);
            uint amount = _price - price;
            IERC20(TokenDoge).transferFrom(msg.sender, address(this), amount);
            totalPool += ((amount * (100 - (100 - feePool))) / 100);
            totalMgmt += ((amount * (100 - (100 - feeMgmt))) / 100);
            totalRefral += ((amount * (100 - (100 - feeRefral))) / 100);
            totalBalance += amount;
            betPlayers[_refralOld].players.push(msg.sender);
            betPlayers[_refralOld].amountRefral += price;
            refralList[_refralCode].refralCode = generate_bytes_refral(
                _refralCode
            );
            idToListedToken[currentTokenId] = ListedToken(
                tokenURI,
                currentTokenId,
                BetId,
                payable(msg.sender),
                amount,
                generate_bytes_refral(_refralCode),
                true,
                _totalPriceDoge
            );

            ownerRefral[_refralCode][msg.sender][currentTokenId].add = true;
            refralList[_refralCode].refralCode = generate_bytes_refral(
                _refralCode
            );
            Totalplayers.push(
                Player({
                    bet_Id: BetId,
                    nft_Id: currentTokenId,
                    amount: amount,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceDoge: _totalPriceDoge
                })
            );
            newplayers.push(
                Player({
                    bet_Id: BetId,
                    nft_Id: currentTokenId,
                    amount: amount,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceDoge: _totalPriceDoge
                })
            );
            HashToRefral[generate_bytes_refral(_refralCode)] = _refralCode;
            emit createNft(
                currentTokenId,
                msg.sender,
                tokenURI,
                BetId,
                block.timestamp,
                generate_bytes_refral(_refralCode),
                _totalPriceDoge
            );
        } else {
            IERC20(TokenDoge).transferFrom(msg.sender, address(this), _price);
            totalPool += ((_price * (100 - (100 - feePool))) / 100);
            totalMgmt += ((_price * (100 - (100 - feeMgmt))) / 100);
            totalRefral += ((_price * (100 - (100 - feeRefral))) / 100);
            totalBalance += _price;

            idToListedToken[currentTokenId] = ListedToken(
                tokenURI,
                currentTokenId,
                BetId,
                payable(msg.sender),
                _price,
                generate_bytes_refral(_refralCode),
                true,
                _totalPriceDoge
            );
            ownerRefral[_refralCode][msg.sender][currentTokenId].add = true;
            refralList[_refralCode].refralCode = generate_bytes_refral(
                _refralCode
            );
            Totalplayers.push(
                Player({
                    bet_Id: BetId,
                    nft_Id: currentTokenId,
                    amount: _price,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceDoge: _totalPriceDoge
                })
            );
            newplayers.push(
                Player({
                    bet_Id: BetId,
                    nft_Id: currentTokenId,
                    amount: _price,
                    time: block.timestamp,
                    nftAddress: payable(msg.sender),
                    totalPriceDoge: _totalPriceDoge
                })
            );
            HashToRefral[generate_bytes_refral(_refralCode)] = _refralCode;
            emit createNft(
                currentTokenId,
                msg.sender,
                tokenURI,
                BetId,
                block.timestamp,
                generate_bytes_refral(_refralCode),
                _totalPriceDoge
            );
        }
    }

    function createWinnerTotalPlayers(string memory _code) public onlyAdmin {
        require(
            totalDogeWinner <= totalPool,
            "Not Enough Pool for Found winner"
        );
        uint winnerTotalPlayer = _randomModulo(Totalplayers.length, _code);
        uint _tokenId = Totalplayers[winnerTotalPlayer].nft_Id;
        address winnerTotalPlayerAddress = Totalplayers[winnerTotalPlayer]
            .nftAddress == ownerOf(_tokenId)
            ? Totalplayers[winnerTotalPlayer].nftAddress
            : ownerOf(_tokenId);

        // uint p_winner=Totalplayers[winnerTotalPlayer].amount ;
        uint priceWinner = totalDogeWinner / 2;

        IERC20(TokenDoge).transfer(
            payable(winnerTotalPlayerAddress),
            priceWinner
        );

        emit CreateBet(
            BetId,
            Totalplayers.length,
            Totalplayers[winnerTotalPlayer].nft_Id,
            winnerTotalPlayerAddress,
            priceWinner,
            block.timestamp
        );
        deleteIndexArray(winnerTotalPlayer);
        totalPool -= priceWinner;
        totalDogeWinner -= priceWinner;
        currentState = State.WINNER;
    }

    function createWinnerNewPlayers(
        string memory _code
    ) public onlyAdmin inState(State.WINNER) {
        uint winnerNewPlayer = _randomModulo(newplayers.length, _code);
        uint _tokenId = newplayers[winnerNewPlayer].nft_Id;
        address winnerwinnerNewPlayerAddress = newplayers[winnerNewPlayer]
            .nftAddress == ownerOf(_tokenId)
            ? newplayers[winnerNewPlayer].nftAddress
            : ownerOf(_tokenId);

        // uint p_winner=Totalplayers[winnerNewPlayer].amount;
        uint priceWinner = totalDogeWinner;

        IERC20(TokenDoge).transfer(
            payable(winnerwinnerNewPlayerAddress),
            priceWinner
        );

        emit CreateNewBet(
            BetId,
            newplayers.length,
            newplayers[winnerNewPlayer].nft_Id,
            winnerwinnerNewPlayerAddress,
            priceWinner,
            block.timestamp
        );

        delete newplayers;
        totalPool -= priceWinner;
        BetId++;
        percentPrice += 3;
        totalDogeWinner = 0;
        currentState = State.IDLE;
    }

    function clamRefralCode(string memory _code, uint _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Not all");
        uint amount = betPlayers[_code].amountRefral;
        address RedralAddress = ownerOf(_tokenId);
        IERC20(TokenDoge).transfer(RedralAddress, amount);
        betPlayers[_code].amountRefral -= amount;
        totalRefral -= amount;
        delete betPlayers[_code].players;
    }

    function whitdraw_Mgmt1() public onlyAdmin {
        uint amount = totalMgmt / 2;
        IERC20(TokenDoge).transfer(mgmt1, amount);
        totalMgmt = amount;
    }

    function whitdraw_Mgmt2() public onlyAdmin {
        IERC20(TokenDoge).transfer(mgmt2, totalMgmt);
        totalMgmt = 0;
    }

    function getCount(address account) public view returns (uint256) {
        return IERC20(TokenDoge).balanceOf(account);
    }

    function Approvetokens(uint256 _tokenamount) public returns (bool) {
        IERC20(TokenDoge).approve(address(this), _tokenamount);
        return true;
    }

    function generate_bytes_refral(
        string memory _pass
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_pass));
    }

    function generate_hash_refral(
        bytes32 hash,
        uint tokenId
    ) public view returns (string memory) {
        require(ownerOf(tokenId) == msg.sender, "Not all");
        return HashToRefral[hash];
    }

    function showRefralUsers(
        string memory refral,
        uint tokenId
    ) public view returns (address[] memory) {
        require(ownerOf(tokenId) == msg.sender, "Not all");
        return betPlayers[refral].players;
    }

    function showRefralUserAmount(
        string memory refral,
        uint tokenId
    ) public view returns (uint) {
        require(ownerOf(tokenId) == msg.sender, "Not all");
        return betPlayers[refral].amountRefral;
    }

    function VerifyRefralCode(string memory refral) public view returns (bool) {
        if (generate_bytes_refral(refral) == refralList[refral].refralCode) {
            return true;
        } else {
            return false;
        }
    }

    function veriftyRefralWithAddressAndTokenId(
        string memory _code,
        address _add,
        uint _tokenId
    ) public view returns (bool) {
        return ownerRefral[_code][_add][_tokenId].add;
    }

    function _randomModulo(
        uint madulo,
        string memory code
    ) internal view returns (uint) {
        return
            uint(keccak256(abi.encodePacked(block.timestamp, code))) % madulo;
    }

    function showTotalPlayers() public view returns (Player[] memory) {
        return Totalplayers;
    }

    function showNewPlayers() public view returns (Player[] memory) {
        return newplayers;
    }

    function deleteIndexArray(uint index) public {
        for (uint i = index; i < Totalplayers.length - 1; i++) {
            Totalplayers[i] = Totalplayers[i + 1];
        }
        Totalplayers.pop();
    }

    function totalNewPlayers() public view returns (Player[] memory) {
        return newplayers;
    }

    function showTotalBalance() public view returns (uint) {
        return address(this).balance;
    }

    function showTotalBalanceDoge() public view returns (uint) {
        return IERC20(TokenDoge).balanceOf(address(this));
    }

    function showTotalPool() public view returns (uint) {
        return totalPool;
    }

    function showTotalMgmt() public view returns (uint) {
        return totalMgmt;
    }

    function showTotalRefral() public view returns (uint) {
        return totalRefral;
    }

    function showOwnerAddress() public view returns (address) {
        return ownerContract;
    }

    function getPriceDogeToUsd() public pure returns (uint) {
        uint price = 1596;
        return price;
    }

    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (ownerOf(i + 1) == msg.sender) {
                itemCount += 1;
            }
        }

        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (ownerOf(i + 1) == msg.sender) {
                uint currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    function getListedForTokenId(
        uint256 tokenId
    ) public view returns (ListedToken memory) {
        require(ownerOf(tokenId) == msg.sender, "Not all");
        return idToListedToken[tokenId];
    }

    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);

        uint currentIndex = 0;
        for (uint i = 0; i < nftCount; i++) {
            uint currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return tokens;
    }
}
