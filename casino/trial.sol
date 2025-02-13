// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Minigames {
    // Owner of the contract
    address public owner;
    
    // Modifier to restrict access to owner-only functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Track total winnings and losses for each user
    mapping(address => uint256) public totalWon;
    mapping(address => uint256) public totalLost;

    // Constructor sets the contract deployer as the owner
    constructor() {
        owner = msg.sender;
    }

    // --------------------- Contract Funding ---------------------

    // Event emitted when the owner deposits funds into the contract
    event FundsDeposited(address indexed sender, uint256 amount);

    /**
     * @notice Allows the owner to deposit funds into the contract.
     * These funds are used for payouts in games.
     */
    function depositFunds() external payable onlyOwner {
        emit FundsDeposited(msg.sender, msg.value);
    }

    // --------------------- Random Number Generator ---------------------

    /**
     * @dev Generates a pseudo-random number. This is used in both games.
     * Uses block data and the sender's address for randomness.
     * Note: Not secure for critical applications due to potential predictability.
     */
    function _getRandomNumber() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1), 
            block.prevrandao, 
            msg.sender
        )));
    }

    // --------------------- Slots Game ---------------------

    // Symbols for the slots game reels
    string[6] public symbols = ["1", "2", "3", "4", "5", "6"];

    // Minimum bet amount for the slots game
    uint256 public minimumBet = 0.01 ether;

    // Track individual user's winnings and losses in the slots game
    mapping(address => uint256) public slotsWon;
    mapping(address => uint256) public slotsLost;

    // Event emitted after each spin of the slots
    event SpinResult(address indexed player, string[3] result, bool isWinner, uint256 payout);

    /**
     * @notice Allows a user to play the slots game.
     * The user places a bet, and the outcome of the spin determines whether they win or lose.
     */
    function playSlotsGame() public payable {
        require(msg.value >= minimumBet, "Bet amount too low");

        uint256 randomness = _getRandomNumber();

        // Determine the result for each reel
        uint256 reel1 = randomness % symbols.length;
        uint256 reel2 = (randomness / symbols.length) % symbols.length;
        uint256 reel3 = (randomness / symbols.length**2) % symbols.length;

        string[3] memory result = [symbols[reel1], symbols[reel2], symbols[reel3]];
        bool isWinner = (reel1 == reel2 && reel2 == reel3);
        uint256 payout = isWinner ? msg.value * 10 : 0;

        // Handle win or loss scenarios
        if (isWinner) {
            require(address(this).balance >= payout, "Insufficient contract balance");
            slotsWon[msg.sender] += payout;
            totalWon[msg.sender] += payout;
            payable(msg.sender).transfer(payout);
        } else {
            slotsLost[msg.sender] += msg.value;
            totalLost[msg.sender] += msg.value;
        }

        emit SpinResult(msg.sender, result, isWinner, payout);
    }

    /**
     * @notice Retrieves a user's statistics for the slots game.
     * @param user The address of the user.
     * @return won The total amount won by the user in slots.
     * @return lost The total amount lost by the user in slots.
     */
    function getUserStatsForSlots(address user) public view returns (uint256 won, uint256 lost) {
        return (slotsWon[user], slotsLost[user]);
    }

    // --------------------- Mystery Box Game ---------------------

    // Track rewards and amounts spent by each user in the mystery box game
    mapping(address => uint256) public mysteryRewards;
    mapping(address => uint256) public mysterySpent;

    // Event emitted after a mystery box game is played
    event BoxPlayed(address indexed player, uint256 amountPaid, uint256 reward);
    
    /**
     * @notice Allows a user to play the mystery box game.
     * The user pays an amount and receives a reward based on randomness.
     */
    function playMysteryBox() external payable {
        require(msg.value > 0, "Amount must be greater than zero");

        uint256 amountPaid = msg.value;
        mysterySpent[msg.sender] += amountPaid;
        uint256 randomValue = _getRandomNumber();

        // Determine reward based on randomness
        uint256 scaledRandom = randomValue % 100;
        uint256 reward;
        if (scaledRandom < 80) {
            // 80% chance for a smaller reward
            reward = amountPaid * (25 + (scaledRandom % 75)) / 100; 
        } else {
            // 20% chance for a larger reward
            reward = amountPaid * (100 + (scaledRandom % 100)) / 100;
        }

        require(address(this).balance >= reward, "Contract out of funds");

        mysteryRewards[msg.sender] += reward;
        totalWon[msg.sender] += reward;

        // Update losses if the reward is less than the amount paid
        if (reward < amountPaid) {
            totalLost[msg.sender] += (amountPaid - reward);
        }

        payable(msg.sender).transfer(reward);

        emit BoxPlayed(msg.sender, amountPaid, reward);
    }

    /**
     * @notice Retrieves a user's statistics for the mystery box game.
     * @param player The address of the player.
     * @return mysteryWon Total rewards won by the user in the mystery box game.
     * @return mysteryLost Total losses incurred by the user in the mystery box game.
     */
    function getUserStatsForMystery(address player) external view returns (uint256 mysteryWon, uint256 mysteryLost) {
        mysteryWon = mysteryRewards[player];
        mysteryLost = mysterySpent[player] > mysteryRewards[player] ? mysterySpent[player] - mysteryRewards[player] : 0;
        return (mysteryWon, mysteryLost);
    }


    // --------------------- Lotto Game ---------------------


    uint256 public gameFee = 0.01 ether;

    mapping(address => uint256) public LottoRewards;
    mapping(address => uint256) public LottoSpent;

    event LottoPlayed(address indexed player, uint8[6] userNumbers, uint8[6] winningNumbers, uint256 reward);
    /**
     * @dev Function to play the lotto game.
     * The player provides 6 chosen numbers and pays the game fee.
     * The contract generates 6 random winning numbers and calculates rewards.
     * 
     * @param userNumbers The array of 6 numbers chosen by the player (values between 1-49).
     */
    function playLotto(uint8[6] memory userNumbers) external payable {
        require(msg.value == gameFee, "Incorrect game fee");

        uint256 randomness = _getRandomNumber();

        uint8[6] memory winningNumbers;
        winningNumbers[0] = uint8(randomness % 49) + 1;
        winningNumbers[1] = uint8((randomness / 49) % 49) + 1;
        winningNumbers[2] = uint8((randomness / 49**2) % 49) + 1;
        winningNumbers[3] = uint8((randomness / 49**3) % 49) + 1;
        winningNumbers[4] = uint8((randomness / 49**4) % 49) + 1;
        winningNumbers[5] = uint8((randomness / 49**5) % 49) + 1;

        uint256 matches = _countMatches(userNumbers, winningNumbers);

        uint256 reward = 0;

        if (matches == 6) {
            reward = msg.value * 10;  // Jackpot: 10x reward
        } else if (matches == 4) {
            reward = msg.value * 5;   // 4 matches: 5x reward
        } else if (matches == 2) {
            reward = msg.value * 2;   // 2 matches: 2x reward
        }

        if (reward > 0) {
            require(address(this).balance >= reward, "Insufficient contract balance");
            totalWon[msg.sender] += reward;
            LottoRewards[msg.sender] += reward;
            payable(msg.sender).transfer(reward);
        } else {
            totalLost[msg.sender] += msg.value;
            LottoSpent[msg.sender] += msg.value;
        }

        emit LottoPlayed(msg.sender, userNumbers, winningNumbers, reward);


    }


    function _countMatches(uint8[6] memory userNumbers, uint8[6] memory winningNumbers) 
        private 
        pure 
        returns (uint256 count) 
    {
        for (uint8 i = 0; i < 6; i++) {
            for (uint8 j = 0; j < 6; j++) {
                if (userNumbers[i] == winningNumbers[j]) {
                    count++;
                    break;  // Avoid duplicate counting
                }
            }
        }
    }

    function getUserStatsForLotto(address player) external view returns (uint256 LottoWon, uint256 LottoLost) {
        LottoWon = LottoRewards[player];
        LottoLost = LottoSpent[player] > LottoRewards[player] ? LottoSpent[player] - mysteryRewards[player] : 0;
        return (LottoWon, LottoLost);
    }




    /**
     * @notice Retrieves a user's overall statistics across all games.
     * @param user The address of the user.
     * @return won Total amount won by the user.
     * @return lost Total amount lost by the user.
     */
    function getUserStats(address user) public view returns (uint256 won, uint256 lost) {
        return (totalWon[user], totalLost[user]);
    }

}
