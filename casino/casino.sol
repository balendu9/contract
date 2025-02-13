// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Casino is Ownable {
    using SafeMath for uint256;
    address public owner;

    // Game metrics
    uint256 public totalBets;  //total bets placed
    uint256 public totalWagered; //total amout wagered
    uint256 public totalPayouts; // total winings paid out
    uint256 public houseEdge; // house edge

    // user specific metrics
    mapping(address => uint256) public userBets; //number of bets per user
    mapping(address => uint256) public userWagered; //total amount wagered per user
    mapping(address => uint256) public userWinnings; //total winnings received per user


    // casino balance and payout handling
    uint256 public casinoBalance; //total amount available for payouts
    uint256 public minBet; // minimum bet amount allowed
    uint256 public maxBet; //maximum bet allowed
    uint256 public maxPayout; //max payout limit per user

    // randomness
    bytes32 public randomSeed;
    uint256 public lastRandomNumber;

    // Game tracking
    uint8[] public games;
    mapping(uint8 => uint256) public gameBets; //tracks bet per game
    uint8 public mostPlayedGame;


    // High rist bets tracking
    uint256 public biggestWin;
    uint256 public biggestLoss;
    address public topWinner;
    address public topLoser;


    // Daily Metrics
    struct DailyStats {
        uint256 bets;
        uint256 revenue;
        uint256 uniquePlayers;
    }
    DailyStats public todayStats;
    mapping(address => bool) private hasBetToday;

    uint256 public lastResetTimestamp;

    // LeaderBoards
    struct PlayerStats {
        address player;
        uint256 amount;
    }
    PlayerStats[10] public topWinners;
    PlayerStats[10] public topLosers;



    // events
    event BetPlaced(address indexed user, uint256 amount);
    event WinningsPaid(address indexed user, uint256 amount);
    event HouseEdgeUpdated(uint256 newHouseEdge);

    event CasinoFunded(uint256 amount);
    event FundsWithdraw(uint256 amount);
    event MinBetUpdated(uint256 newMinBet);
    event MaxBetUpdated(uint256 newMaxBet);
    event MaxPayoutUpdated(uint256 newMaxPayout);
    event RandomSeedUpdated(bytes32 newSeed);
    event GamePlayed(uint8 gameId, address player, uint256 betAmount, uint256 payout);
    event NewBiggestWin(address player, uint256 amount);
    event NewBiggestLoss(address player, uint256 amount);
    event MostPlayedGameUpdated(uint8 gameId);

    event DailyStatsReset();
    event LeaderboardUpdated(string category, address player, uint256 amount);

    // contructor
    constructor() {
        houseEdge= 500;
        owner = msg.sender;
        minBet = 1000000000000000;
        maxBet = 100000000000000000000; 
        games = [1,2,3,4,5,6];

    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }





    /*

    -----------------------------------
    Here the Game Stats and data contract functions
    -----------------------------------

    */

    function recordGamePlay(uint8 gameId, address player, uint256 betAmount, uint256 payout) internal {
        require(betAmount >= minBet && betAmount <= maxBet, "Bet out of range");

        totalBets += 1;
        totalWagered += betAmount;
        gameBets[gameId] += 1;

        //tracks most played game
        if (gameBets[gameId] > gameBets[mostPlayedGame]) {
            mostPlayedGame = gameId;
            emit MostPlayedGameUpdated(gameId);
        }

        // update daily metrics
        _updateDailyStats(player, betAmount, payout);

        // track leaderboards
        if(payout > 0) {
            _updateLeaderboard(topWinners, player, payout, "winners");
        } else {
            _updateLeaderboard(topLosers, player, betAmount, "losers");
        }

        emit GamePlayed(gameId, player, betAmount, payout); 

    }

    function _updateDailyStats(address player, uint256 betAmount, uint256 payout) internal {
        if (block.timestamp > lastResetTimestamp + 1 days) {
            _resetDailyStats();
        }

        todayStats.bets += 1;
        todayStats.revenue += (betAmount - payout);

        if(!hasBetToday[player]) {
            hasBetToday[player] = true;
            todayStats.uniquePlayers +=1;
        }
    }

    function _resetDailyStats() internal {
        todayStats = DailyStats(0,0,0);
        lastResetTimestamp = block.timestamp;

        // reset daily player tracking
        for (uint8 i =0; i < 10; i++) {
            delete hasBetToday[topWinners[i].player];
            delete hasBetToday[topLosers[i].player];
        }
        emit DailyStatsReset();
    }


    function _updateLeaderboard(PlayerStats[10] storage leaderboard, address player, uint256 amount, string memory category) internal {
        for (uint8 i=0; i < 10; i++) {
            if (amount > leaderboard[i].amount) {
                for (uint8 j = 9; j>i; j--) {
                    leaderboard[j] = leaderboard[j-i];
                }

                // insert new player
                leaderboard[i] = PlayerStats(player, amount);
                emit LeaderboardUpdated(category, player, amount);
                break;
            }
        }
    }


    function getTopWinners() external view returns (PlayerStats[10] memory) {
        return topWinners;
    }

    function getTopLosers() external view returns (PlayerStats[10] memory) {
        return topLosers;
    }

    function getDailyStats() external view returns (uint256 bets, uint256 revenue, uint256 uniquePlayers) {
        return (todayStats.bets, todayStats.revenue, todayStats.uniquePlayers);
    }




    /*

    -----------------------------------
    Here the contract's only owner functions
    -----------------------------------

    */

    // fund the casino contract - only owner
    function fundCasino() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        casinoBalance = casinoBalance.add(msg.value);
        emit CasinoFunded(msg.value);
    }

    // withdraw funds - only owner
    function withdrawFunds(uint256 amount) external onlyOwner {
        require(amount <= casinoBalance, "Not enough Funds");
        casinoBalance = casinoBalance.sub(amount);
        payable(owner()).transfer(amount);
        emit FundsWithdraw(amount);
    }

    // Update min bet amount (owner-only)
    function setMinBet(uint256 _minBet) external onlyOwner {
        require(_minBet > 0, "Min bet must be greater than zero");
        minBet = _minBet;
        emit MinBetUpdated(_minBet);
    }

    // Update max bet amount (owner-only)
    function setMaxBet(uint256 _maxBet) external onlyOwner {
        require(_maxBet > minBet, "Max bet must be greater than min bet");
        maxBet = _maxBet;
        emit MaxBetUpdated(_maxBet);
    }

    // Update max payout limit (owner-only)
    function setMaxPayout(uint256 _maxPayout) external onlyOwner {
        maxPayout = _maxPayout;
        emit MaxPayoutUpdated(_maxPayout);
    }

    function withdraw( uint256 payoutAmount) external onlyOwner {
        require(payoutAmount <= casinoBalance, "Not enough funds to pay out");
        casinoBalance = casinoBalance.sub(payoutAmount);
        payable(owner).transfer(payoutAmount);
    }



    /**  
     -----------------------------------
    Here the gaming functions
    -----------------------------------

    */

    


    // randomness
    function _getRandomNumber() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1), 
            block.prevrandao, 
            msg.sender
        )));
    }



    /**  
     first game

    */

    function playGame1() external payable {
        require(msg.value >= minBet && msg.value <= maxBet, "Bet out of range");
        uint256 betAmount = msg.value;

        uint256 randomValue = _getRandomNumber();

        uint256 scaledRandomValue = randomValue % 99;

        uint256 calculateReward;

        if (scaledRandomValue > 55 && scaledRandomValue < 65) {
            calculateReward = betAmount * (25 + (scaledRandom % 75)) / 100;
        } else {
            calculateReward = betAmount * (100 + (scaledRandom % 100)) / 100;
        }

        // Update casino balance
        casinoBalance += betAmount;
        totalPayouts += calculateReward;

        // Record the game play
        recordGamePlay(1, msg.sender, betAmount, CalculateReward);
    }




}