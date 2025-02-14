// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Casino {

    address public owner;

    
    // Game metrics
    uint256 public minBet; // minimum bet amount allowed
    uint256 public maxBet; //maximum bet allowed

    uint256 public totalBets;  //total bets placed
    uint256 public totalWagered; //total amout wagered
    uint256 public totalPayouts; // total winings paid out
    uint256 public houseEdge; // house edge


    // user specific
    mapping(address => uint256) public userBets; //number of bets per user
    mapping(address => uint256) public userWagered; //total amount wagered per user
    mapping(address => uint256) public userWinnings; //total winnings received per user
    
    // game tracking
    uint8[] public games;
    mapping(uint8 => uint256) public gameBets;
    uint8 public mostPlayedGame;

    // Daily metrics
    struct DailyStats {
        uint256 bets;
        uint256 revenue;
        uint256 uniquePlayers;
    }
    DailyStats public todayStats;
    mapping(address => bool) private hasBetToday;

    uint256 public lastResetTimestamp;

    // leaderboard
    struct PlayerStats {
        address player;
        uint256 amount;
        uint8 gameId;
    }
    PlayerStats[10] public topWinners;
    PlayerStats[10] public topLosers;


    constructor() {
        owner = msg.sender;
        minBet = 1000000000000000;
        maxBet = 100000000000000000000; 
        games = [1,2,3,4,5,6];
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    function _getRandomNumber() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1), 
            block.prevrandao, 
            msg.sender
        )));
    }


    function playGame1() external payable returns(uint256) {
        require(msg.value >= minBet && msg.value <= maxBet, "bet out of range");

        uint256 amountPaid = msg.value; 

        uint256 scaledRandomValue = (_getRandomNumber()) % 100;
        uint256 reward;
        if (scaledRandomValue <80) {
            // 80% chance for a smaller reward
            reward = amountPaid * (25 + (scaledRandomValue % 75)) / 100; 
        } else {
            // 20% chance for a larger reward
            reward = amountPaid * (100 + (scaledRandomValue % 100)) / 100;
        }
        uint8 gameId = 1;

        recordGamePlay(gameId, amountPaid, msg.sender, reward);

        return reward;
    }


    // this is just for testing
    function playGame2() external payable {
        require(msg.value >= minBet && msg.value <= maxBet, "bet out of range");

        uint256 amountPaid = msg.value; 

        uint256 scaledRandomValue = (_getRandomNumber()) % 100;
        uint256 reward;
        if (scaledRandomValue <80) {
            // 80% chance for a smaller reward
            reward = amountPaid * (25 + (scaledRandomValue % 75)) / 100; 
        } else {
            // 20% chance for a larger reward
            reward = amountPaid * (100 + (scaledRandomValue % 100)) / 100;
        }
        uint8 gameId = 2;

        recordGamePlay(gameId, amountPaid, msg.sender, reward);


    }



    function recordGamePlay(uint8 _gameId, uint256 _amountPaid, address _playeraddress, uint256 reward ) internal {
        totalBets += 1;
        totalWagered += _amountPaid;
        gameBets[_gameId] += 1;
        userBets[_playeraddress] += 1;
        userWinnings[_playeraddress] = reward;

        // most played game track
        if (gameBets[_gameId] > gameBets[mostPlayedGame]) {
            mostPlayedGame = _gameId;
        }

        // update daily stats

        if (block.timestamp > lastResetTimestamp + 1 days) {
            todayStats = DailyStats(0,0,0);
            lastResetTimestamp = block.timestamp;
            // reset daily player tracking
            for (uint8 i = 0; i < 10; i++) {
                delete hasBetToday[topWinners[i].player];
                delete hasBetToday[topLosers[i].player];
            }
        }

        todayStats.bets += 1;
        todayStats.revenue += (_amountPaid - reward);

        if(!hasBetToday[_playeraddress]) {
            hasBetToday[_playeraddress] = true;
            todayStats.uniquePlayers += 1;
        }


        // update leaderboard

        if (reward > _amountPaid) {
            for (uint8 i = 0; i < 10; i++) {
                if (reward > topWinners[i].amount) {
                    // Shift lower-ranked players down
                    for (uint8 j = 9; j > i; j--) {
                        topWinners[j] = topWinners[j - 1];  // Corrected shift
                }
                // Insert the new winner
                topWinners[i] = PlayerStats(_playeraddress, reward, _gameId);
                break;  // Important: Stop after inserting
            }
        }
        } else {
            for (uint8 i = 0; i < 10; i++) {
                if (_amountPaid > topLosers[i].amount) {
                    // Shift lower-ranked losers down
                    for (uint8 j = 9; j > i; j--) {
                    topLosers[j] = topLosers[j - 1];  // Corrected shift
                }
                // Insert the new loser
                topLosers[i] = PlayerStats(_playeraddress, _amountPaid - reward, _gameId);
                break;  // Stop after inserting
            }
        }
        }

     
        
    }




}