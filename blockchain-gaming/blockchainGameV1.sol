pragma solidity ^0.8.9;

import "./VerifySignature.sol";
import "./StringConversions.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Game_Operator is VerifySignature, StringConversions, Ownable{ 
//    Token public erc20;
//    address public treasury;
      address hashingAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    uint256 public currentNonce = 0;
    uint256 public timeBuffer = 120; //120 seconds = 2 minutes
    uint256[] public openGames;
    mapping(uint256 => address) public openAddresses;
    mapping(uint256 => bool) public gameStarted;
    mapping(uint256 => uint256) public bets;
    mapping(uint256 => address[]) public players;
    mapping(uint256 => address) public winners;
    mapping(uint256 => uint256) public prizeTimer;

    //gameNonce -> playerAddress -> data
    mapping(uint256 => mapping(address => bytes32)) internal nextMove; 
    mapping(uint256 => mapping(address => bytes)) internal finishedMove; 
    mapping(uint256 => uint256) public gameStartTime; 

	constructor() {//Resources _resources, ERC721 _erc721, Token _erc20, address _treasury) { 
//		resources = _resources;
//        erc721 = _erc721;
//        erc20 = _erc20;
//        treasury = _treasury;
	}

    function searchForOpponent(uint256 bet) external {
//        require(erc721.tokenOfOwnerByIndex(msg.sender, 1) > 0, "Don't own a NFT");
//        erc20.transferFrom(msg.sender, address(this), bet);
        openGames.push(currentNonce);
        bets[currentNonce] = bet;
        gameStarted[currentNonce] = false;
        nextMove[currentNonce][msg.sender] = keccak256(abi.encodePacked("Search"));
        players[currentNonce][0] = msg.sender; 
        gameStartTime[currentNonce] = block.timestamp;
        openAddresses[currentNonce] = msg.sender;
        currentNonce++;
    }

    function endSearch(uint256 gameNonce) public {
        require(msg.sender == openAddresses[gameNonce] || gameStarted[gameNonce]);
        for (uint32 i=0; i < openGames.length; i++) {
            if (openGames[i] == gameNonce) {
                openGames[i] = openGames[openGames.length - 1];
                openGames.pop();
                delete openAddresses[gameNonce]; 
            }
        }
        if (msg.sender == players[gameNonce][0]) {
//            erc20.transfer(msg.sender, bets[gameNonce]);
        }
    }

    function startGame(uint256 gameNonce) external { //bytes memory signature, address opponent, 
        require(gameStarted[gameNonce] == false, "Game already started");
        require(players[gameNonce][0] != msg.sender, "Can't Play Against Yourself");
        gameStarted[gameNonce] = true;
//        erc20.transferFrom(msg.sender, address(this), bets[gameNonce]);
        endSearch(gameNonce);
        nextMove[gameNonce][msg.sender] = keccak256(abi.encodePacked("Start"));
        players[gameNonce][1] = msg.sender;
        gameStartTime[gameNonce] = block.timestamp;
    }

    function finishGame(uint256 gameNonce, string[] memory gameStates, bytes[] memory signedHashes) external {
        require(players[gameNonce].length > 0, "No Players");
        uint8 i = 0;
        uint8 j = 1;
        if (players[gameNonce][i] == msg.sender) {
            i = 1;
            j = 0;
        }
        require(players[gameNonce][j] == msg.sender, "Invalid Claim");
        require(winners[gameNonce] == address(0), "Tokens already claimed");
        require(prizeTimer[gameNonce] == 0);

        //verify previous gamestate, gamestate[0]
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signedHashes[0]); 
        string memory hashString = gameStates[0];
        bytes32 msgHash = keccak256(abi.encodePacked(hashString));
        require(players[gameNonce][i] == ecrecover(getEthSignedHash(msgHash), v, r, s), "Wrong Signature Hash 1");

        //verify your own move decision, gamestate[1]
        (r, s, v) = splitSignature(signedHashes[1]); 
        hashString = concat(string(signedHashes[0]), gameStates[1]);
        msgHash = keccak256(abi.encodePacked(hashString));
        require(players[gameNonce][j] == ecrecover(getEthSignedHash(msgHash), v, r, s), "Wrong Signature Hash 2");

        //verify opponent's aknowledgement of your move
        (r, s, v) = splitSignature(signedHashes[2]); 
        hashString = string(signedHashes[1]);
        msgHash = keccak256(abi.encodePacked(hashString));
        require(players[gameNonce][i] == ecrecover(getEthSignedHash(msgHash), v, r, s), "Wrong Signature Hash 3");

        if (gameStates.length > 2) {
            //if you have opponents move data verify it's legitimate
            //your confirmation fo gamestate to the opponent
            (r, s, v) = splitSignature(signedHashes[3]); 
            hashString = gameStates[0];
            msgHash = keccak256(abi.encodePacked(hashString));
            require(players[gameNonce][j] == ecrecover(getEthSignedHash(msgHash), v, r, s), "Wrong Signature Hash 4");

            //opponent's signature of their moves, gamestate[2]
            (r, s, v) = splitSignature(signedHashes[4]); 
            hashString = concat(string(signedHashes[3]), gameStates[2]);
            msgHash = keccak256(abi.encodePacked(hashString));
            require(players[gameNonce][i] == ecrecover(getEthSignedHash(msgHash), v, r, s), "Wrong Signature Hash 5");

            if (isWinner(players[gameNonce][j], gameStates)) { //determine if a player won
                winners[gameNonce] = players[gameNonce][j];
            }

        }

        //require game has been going long enough to claim or you can prove you're the winner
        require(gameStartTime[gameNonce] + timeBuffer < block.timestamp || winners[gameNonce] == players[gameNonce][j], "Invalid Claim");


        if (winners[gameNonce] != address(0)) {

//            erc20.transfer(winners[gameNonce], bets[gameNonce]*180/100); 
            /*
            Distribute Prizes from bet and other tokens
            */
        }
        else {
            prizeTimer[gameNonce] = block.timestamp; //start timer for afk opponent
            /*
            Distribute Prizes from bet and other tokens
            */
        }
        //10% cut of bet from both players goes to treasury
//        erc20.transfer(treasury, bets[gameNonce]*20/100); 
        
    }


    function claimPrize(uint256 gameNonce) external {
        uint8 i = 0;
        uint8 j = 1;
        if (players[gameNonce][i] == msg.sender) {
            i = 1;
            j = 0;
        }
        require(players[gameNonce][j] == msg.sender, "Invalid Claim");
        require(winners[gameNonce] == address(0), "Tokens already claimed");

        if (prizeTimer[gameNonce] + 600 < block.timestamp) { //600 seconds, 10 minutes
            winners[gameNonce] = msg.sender;
            /*
            Distribute Prizes from bet and other tokens
            */
            //erc20.transfer(winners[gameNonce], bets[gameNonce]*180/100);
        }
    }

    function protestCompletion(uint256 gameNonce) external {
        //prevent cheating by pretending opponent is afk
        //player has 10 minutes to prevent opponent from claiming they win and taking prizes
        uint8 i = 0;
        uint8 j = 1;
        if (players[gameNonce][i] == msg.sender) {
            i = 1;
            j = 0;
        }
        require(players[gameNonce][j] == msg.sender, "Invalid Claim");
        require(winners[gameNonce] == address(0), "Tokens already claimed");

        if (prizeTimer[gameNonce] + 600 >= block.timestamp) { //600 seconds, 10 minutes
            delete prizeTimer[gameNonce]; // prevent opponent from being able to claim prize
        }
    }

    function isWinner(address player, string[] memory gameStates) public view returns (bool) {
        //determine game winner
        //game logic goes here
        return true;
    }
}




