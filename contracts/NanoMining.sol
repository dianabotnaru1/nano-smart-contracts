// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NanoMining is Ownable, ReentrancyGuard {
    IERC20 public usdtToken; // USDT token contract
    IERC20 public nanoToken; // NANO token contract

    mapping(address => uint256) public balances;
    mapping(address => address) public referrer;
    mapping(address => uint256) public totalNANOHarvested;
    mapping(address => uint256) public lastMinedAt; // Track last mined timestamp per miner

    struct MiningLog {
        uint256 amount;
        uint256 timestamp;
    }
    mapping(address => MiningLog[]) public miningLogs;

    uint256 public constant MIN_WITHDRAWAL = 15000 * 10**18; // Minimum withdrawal in NANO
    uint256 public constant ROI_RATE = 5; // 5% daily
    uint256 public constant REFERRAL_PERCENTAGE = 10; // 10% referral
    uint256 public constant DAILY_INTERVAL = 1 days; // 24-hour interval

    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 nanoReceived);
    event NANOMined(address indexed user, uint256 amount);
    event NANOHarvested(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Swapped(address indexed user, uint256 nanoAmount, uint256 usdtReceived);

    constructor(address _usdtToken, address _nanoToken) {
        usdtToken = IERC20(_usdtToken);
        nanoToken = IERC20(_nanoToken);
    }

    // Buy NANO tokens
    function buyTokens(uint256 usdtAmount, address _referrer) external nonReentrant {
        require(usdtAmount > 0, "Amount should be greater than zero");
        uint256 nanoToReceive = calculateNanoAmount(usdtAmount);

        // Transfer USDT from user to the contract
        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");

        // Transfer NANO tokens to the user
        balances[msg.sender] += nanoToReceive;

        // Handle referral
        if (_referrer != address(0) && _referrer != msg.sender) {
            // Check if the user already has a referrer
            require(referrer[msg.sender] == address(0), "Referrer is already set");

            uint256 referralReward = (usdtAmount * REFERRAL_PERCENTAGE) / 100;
            usdtToken.transfer(_referrer, referralReward);
            referrer[msg.sender] = _referrer;
        }

        emit TokensPurchased(msg.sender, usdtAmount, nanoToReceive);
    }

    // Calculate NANO amount based on USDT
    function calculateNanoAmount(uint256 usdtAmount) internal pure returns (uint256) {
        return usdtAmount * 156250 / 100; // Adjust as per requirement
    }

    function calculateUSDTAmount(uint256 nanoAmount) internal pure returns (uint256) {
        return nanoAmount * 100 / 156250; // Adjust as per requirement
    }

    // Mining function to earn NANO
    function mineNANO(address _miner) external onlyOwner {
        require(block.timestamp >= lastMinedAt[_miner] + DAILY_INTERVAL, "Mining can only be done once every 24 hours");

        uint256 earnedNANO = (balances[_miner] * ROI_RATE) / 100;
        totalNANOHarvested[msg.sender] += earnedNANO;
        lastMinedAt[_miner] = block.timestamp;

        miningLogs[_miner].push(MiningLog({
            amount: earnedNANO,
            timestamp: block.timestamp
        }));

        emit NANOMined(_miner, earnedNANO);
    }

    // Harvest NANO after reaching the minimum threshold
    function harvest() external nonReentrant {
        require(totalNANOHarvested[msg.sender] >= MIN_WITHDRAWAL, "Minimum withdrawal not reached");
        uint256 amountToWithdraw = totalNANOHarvested[msg.sender];
        totalNANOHarvested[msg.sender] = 0;

        // Transfer NANO to user
        nanoToken.transfer(msg.sender, amountToWithdraw);

        emit NANOHarvested(msg.sender, amountToWithdraw);
    }

    // Swap NANO for USDT with 10% admin fee
    function swapNanoForUSDT(uint256 nanoAmount) external nonReentrant {
        require(nanoAmount > 0, "Amount should be greater than zero");

        // Calculate USDT equivalent (assuming 15625 NANO = 10 USDT)
        uint256 usdtAmount = calculateUSDTAmount(nanoAmount);

        // Apply 10% admin fee
        uint256 adminFee = (usdtAmount * 10) / 100;
        uint256 netAmount = usdtAmount - adminFee;

        // Transfer NANO tokens from user to contract
        nanoToken.transferFrom(msg.sender, address(this), nanoAmount);

        // Transfer net USDT to user
        usdtToken.transfer(msg.sender, netAmount);

        emit Swapped(msg.sender, nanoAmount, netAmount);
    }

    // Get the current balance of the miner in NANO
    function getMinerBalance(address _miner) external view returns (uint256) {
        return balances[_miner];
    }

    // Get the total harvested NANO amount for the miner
    function getTotalHarvestedAmount(address _miner) external view returns (uint256) {
        return totalNANOHarvested[_miner];
    }

    // Get mining logs for a miner
    function getMiningLogs(address _miner) external view returns (MiningLog[] memory) {
        return miningLogs[_miner];
    }
}
