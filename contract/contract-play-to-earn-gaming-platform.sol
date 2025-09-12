// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Play-to-Earn Gaming Platform Smart Contract
 * @dev A comprehensive gaming platform where players earn tokens through gameplay
 * @author Play-to-Earn Gaming Team
 */
contract Project {
    // State variables
    address public owner;
    string public platformName;
    uint256 public totalGameTokens;
    uint256 public totalPlayersRegistered;
    uint256 public gameSessionCounter;
    bool public platformActive;
    
    // Game economics
    uint256 public baseRewardPerWin;
    uint256 public streakBonusMultiplier;
    uint256 public dailyPlayLimit;
    uint256 public minimumGameDuration; // in seconds
    
    // Structs
    struct Player {
        string username;
        uint256 tokenBalance;
        uint256 totalGamesPlayed;
        uint256 totalWins;
        uint256 currentWinStreak;
        uint256 highestWinStreak;
        uint256 lastPlayTime;
        uint256 dailyGamesPlayed;
        bool isRegistered;
        bool isActive;
    }
    
    struct GameSession {
        uint256 sessionId;
        address player;
        uint256 startTime;
        uint256 endTime;
        uint256 score;
        bool isWin;
        uint256 tokensEarned;
        bool isCompleted;
    }
    
    struct Tournament {
        uint256 tournamentId;
        string name;
        uint256 entryFee;
        uint256 prizePool;
        uint256 startTime;
        uint256 endTime;
        address[] participants;
        address winner;
        bool isActive;
        bool isCompleted;
    }
    
    // Mappings
    mapping(address => Player) public players;
    mapping(uint256 => GameSession) public gameSessions;
    mapping(address => uint256[]) public playerGameHistory;
    mapping(uint256 => Tournament) public tournaments;
    mapping(address => mapping(uint256 => bool)) public tournamentParticipation;
    
    // Arrays
    address[] public registeredPlayers;
    uint256[] public activeTournaments;
    
    // Events
    event PlayerRegistered(address indexed player, string username);
    event GameSessionStarted(uint256 indexed sessionId, address indexed player);
    event GameSessionCompleted(uint256 indexed sessionId, address indexed player, uint256 tokensEarned);
    event TokensEarned(address indexed player, uint256 amount, string reason);
    event TokensSpent(address indexed player, uint256 amount, string reason);
    event TournamentCreated(uint256 indexed tournamentId, string name, uint256 prizePool);
    event TournamentJoined(uint256 indexed tournamentId, address indexed player);
    event TournamentCompleted(uint256 indexed tournamentId, address indexed winner, uint256 prize);
    event DailyResetOccurred(address indexed player);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredPlayer() {
        require(players[msg.sender].isRegistered, "Player must be registered");
        require(players[msg.sender].isActive, "Player account is not active");
        _;
    }
    
    modifier platformIsActive() {
        require(platformActive, "Platform is currently inactive");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }
    
    /**
     * @dev Constructor to initialize the gaming platform
     */
    constructor(string memory _platformName) {
        owner = msg.sender;
        platformName = _platformName;
        platformActive = true;
        baseRewardPerWin = 100; // 100 tokens per win
        streakBonusMultiplier = 10; // 10% bonus per streak
        dailyPlayLimit = 50; // Maximum 50 games per day
        minimumGameDuration = 60; // Minimum 1 minute game duration
        gameSessionCounter = 1;
    }
    
    /**
     * @dev Core Function 1: Register new player and start earning tokens
     * @param _username Unique username for the player
     */
    function registerPlayer(string memory _username) 
        public 
        platformIsActive 
        returns (bool success) 
    {
        require(!players[msg.sender].isRegistered, "Player already registered");
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(bytes(_username).length <= 20, "Username too long");
        
        // Create new player profile
        players[msg.sender] = Player({
            username: _username,
            tokenBalance: 0,
            totalGamesPlayed: 0,
            totalWins: 0,
            currentWinStreak: 0,
            highestWinStreak: 0,
            lastPlayTime: 0,
            dailyGamesPlayed: 0,
            isRegistered: true,
            isActive: true
        });
        
        registeredPlayers.push(msg.sender);
        totalPlayersRegistered++;
        
        // Give welcome bonus
        uint256 welcomeBonus = 500; // 500 welcome tokens
        players[msg.sender].tokenBalance += welcomeBonus;
        totalGameTokens += welcomeBonus;
        
        emit PlayerRegistered(msg.sender, _username);
        emit TokensEarned(msg.sender, welcomeBonus, "Welcome Bonus");
        
        return true;
    }
    
    /**
     * @dev Core Function 2: Play game and earn tokens based on performance
     * @param _gameDuration Duration of the game session in seconds
     * @param _score Player's score in the game
     * @param _isWin Whether the player won the game
     */
    function playGame(uint256 _gameDuration, uint256 _score, bool _isWin) 
        public 
        onlyRegisteredPlayer 
        platformIsActive 
        returns (uint256 tokensEarned) 
    {
        require(_gameDuration >= minimumGameDuration, "Game session too short");
        require(_score > 0, "Score must be greater than zero");
        
        Player storage player = players[msg.sender];
        
        // Check daily play limit
        _checkDailyReset(msg.sender);
        require(player.dailyGamesPlayed < dailyPlayLimit, "Daily play limit reached");
        
        // Create game session
        uint256 sessionId = gameSessionCounter++;
        gameSessions[sessionId] = GameSession({
            sessionId: sessionId,
            player: msg.sender,
            startTime: block.timestamp - _gameDuration,
            endTime: block.timestamp,
            score: _score,
            isWin: _isWin,
            tokensEarned: 0,
            isCompleted: false
        });
        
        emit GameSessionStarted(sessionId, msg.sender);
        
        // Calculate tokens earned
        tokensEarned = _calculateGameRewards(msg.sender, _score, _isWin);
        
        // Update player stats
        player.totalGamesPlayed++;
        player.dailyGamesPlayed++;
        player.lastPlayTime = block.timestamp;
        player.tokenBalance += tokensEarned;
        
        if (_isWin) {
            player.totalWins++;
            player.currentWinStreak++;
            if (player.currentWinStreak > player.highestWinStreak) {
                player.highestWinStreak = player.currentWinStreak;
            }
        } else {
            player.currentWinStreak = 0;
        }
        
        // Update game session
        gameSessions[sessionId].tokensEarned = tokensEarned;
        gameSessions[sessionId].isCompleted = true;
        playerGameHistory[msg.sender].push(sessionId);
        
        totalGameTokens += tokensEarned;
        
        emit GameSessionCompleted(sessionId, msg.sender, tokensEarned);
        emit TokensEarned(msg.sender, tokensEarned, _isWin ? "Game Victory" : "Game Participation");
        
        return tokensEarned;
    }
    
    /**
     * @dev Core Function 3: Spend tokens on in-game purchases and upgrades
     * @param _amount Amount of tokens to spend
     * @param _itemName Name of item or upgrade being purchased
     */
    function spendTokens(uint256 _amount, string memory _itemName) 
        public 
        onlyRegisteredPlayer 
        platformIsActive 
        returns (bool success) 
    {
        require(_amount > 0, "Amount must be greater than zero");
        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        
        Player storage player = players[msg.sender];
        require(player.tokenBalance >= _amount, "Insufficient token balance");
        
        player.tokenBalance -= _amount;
        
        emit TokensSpent(msg.sender, _amount, _itemName);
        
        return true;
    }
    
    /**
     * @dev Create tournament with entry fee and prize pool
     * @param _name Tournament name
     * @param _entryFee Entry fee in tokens
     * @param _duration Tournament duration in seconds
     */
    function createTournament(
        string memory _name, 
        uint256 _entryFee, 
        uint256 _duration
    ) public onlyOwner returns (uint256 tournamentId) {
        require(bytes(_name).length > 0, "Tournament name cannot be empty");
        require(_duration > 0, "Duration must be positive");
        
        tournamentId = activeTournaments.length + 1;
        
        tournaments[tournamentId] = Tournament({
            tournamentId: tournamentId,
            name: _name,
            entryFee: _entryFee,
            prizePool: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            participants: new address[](0),
            winner: address(0),
            isActive: true,
            isCompleted: false
        });
        
        activeTournaments.push(tournamentId);
        
        emit TournamentCreated(tournamentId, _name, 0);
        
        return tournamentId;
    }
    
    /**
     * @dev Join tournament by paying entry fee
     * @param _tournamentId Tournament ID to join
     */
    function joinTournament(uint256 _tournamentId) 
        public 
        onlyRegisteredPlayer 
        platformIsActive 
    {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active");
        require(!tournament.isCompleted, "Tournament already completed");
        require(block.timestamp < tournament.endTime, "Tournament registration closed");
        require(!tournamentParticipation[msg.sender][_tournamentId], "Already joined tournament");
        
        Player storage player = players[msg.sender];
        require(player.tokenBalance >= tournament.entryFee, "Insufficient tokens for entry fee");
        
        // Pay entry fee
        if (tournament.entryFee > 0) {
            player.tokenBalance -= tournament.entryFee;
            tournament.prizePool += tournament.entryFee;
            emit TokensSpent(msg.sender, tournament.entryFee, "Tournament Entry");
        }
        
        tournament.participants.push(msg.sender);
        tournamentParticipation[msg.sender][_tournamentId] = true;
        
        emit TournamentJoined(_tournamentId, msg.sender);
    }
    
    /**
     * @dev Calculate game rewards based on performance and streaks
     */
    function _calculateGameRewards(address _player, uint256 _score, bool _isWin) 
        private 
        view 
        returns (uint256 reward) 
    {
        Player memory player = players[_player];
        
        // Base participation reward
        reward = baseRewardPerWin / 4; // 25 tokens for participation
        
        if (_isWin) {
            reward += baseRewardPerWin; // Additional 100 tokens for winning
            
            // Streak bonus
            if (player.currentWinStreak > 0) {
                uint256 streakBonus = (baseRewardPerWin * player.currentWinStreak * streakBonusMultiplier) / 100;
                reward += streakBonus;
            }
        }
        
        // Score-based bonus (1 token per 100 score points)
        uint256 scoreBonus = _score / 100;
        reward += scoreBonus;
        
        return reward;
    }
    
    /**
     * @dev Check and reset daily play counter if needed
     */
    function _checkDailyReset(address _player) private {
        Player storage player = players[_player];
        
        // Reset daily counter if it's a new day (simplified to 24 hours)
        if (block.timestamp > player.lastPlayTime + 24 hours) {
            player.dailyGamesPlayed = 0;
            emit DailyResetOccurred(_player);
        }
    }
    
    /**
     * @dev Get player statistics
     */
    function getPlayerStats(address _player) public view returns (
        string memory username,
        uint256 tokenBalance,
        uint256 totalGamesPlayed,
        uint256 totalWins,
        uint256 currentWinStreak,
        uint256 highestWinStreak,
        bool isActive
    ) {
        Player memory player = players[_player];
        return (
            player.username,
            player.tokenBalance,
            player.totalGamesPlayed,
            player.totalWins,
            player.currentWinStreak,
            player.highestWinStreak,
            player.isActive
        );
    }
    
    /**
     * @dev Get platform statistics
     */
    function getPlatformStats() public view returns (
        uint256 totalPlayers,
        uint256 totalTokensInCirculation,
        uint256 totalGameSessions,
        bool isActive
    ) {
        return (
            totalPlayersRegistered,
            totalGameTokens,
            gameSessionCounter - 1,
            platformActive
        );
    }
    
    /**
     * @dev Get player's game history
     */
    function getPlayerGameHistory(address _player) public view returns (uint256[] memory) {
        return playerGameHistory[_player];
    }
    
    /**
     * @dev Update game parameters (owner only)
     */
    function updateGameParameters(
        uint256 _baseReward,
        uint256 _streakMultiplier,
        uint256 _dailyLimit
    ) public onlyOwner {
        baseRewardPerWin = _baseReward;
        streakBonusMultiplier = _streakMultiplier;
        dailyPlayLimit = _dailyLimit;
    }
    
    /**
     * @dev Toggle platform active status
     */
    function togglePlatformStatus() public onlyOwner {
        platformActive = !platformActive;
    }
    
    /**
     * @dev Emergency function to pause player account
     */
    function pausePlayerAccount(address _player) public onlyOwner validAddress(_player) {
        players[_player].isActive = false;
    }
    
    /**
     * @dev Emergency function to resume player account
     */
    function resumePlayerAccount(address _player) public onlyOwner validAddress(_player) {
        players[_player].isActive = true;
    }
}
