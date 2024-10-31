// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NanoMining is Ownable, ReentrancyGuard {
    IERC20 public usdtToken; // USDT token contract
    IERC20 public nanoToken; // NANO token contract
    address public fundWallet;
    uint256 public roiRate;
    uint256 public fundRate;

    mapping(address => uint256) public balances;
    mapping(address => address) public referrer;

    enum BalanceType { Deposit, ReferralReward }

    struct BalanceLog {
        uint256 amount;
        uint256 timestamp;
        BalanceType balanceType;
    }
    mapping(address => BalanceLog[]) public balanceLogs;

    uint256 public constant MIN_WITHDRAWAL = 15000 * 10**18; // Minimum withdrawal in NANO
    uint256 public constant REFERRAL_PERCENTAGE = 10; // 10% referral

    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 nanoReceived);
    event NANOMined(address indexed user, uint256 amount);
    event NANOHarvested(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Swapped(address indexed user, uint256 nanoAmount, uint256 usdtReceived);

    constructor(address _usdtToken, address _nanoToken) {
        usdtToken = IERC20(_usdtToken);
        roiRate = 5;
        fundRate = 40;
    }

    // Buy NANO tokens
    function buyTokens(uint256 usdtAmount, address _referrer) external nonReentrant {
        require(usdtAmount > 0, "Amount should be greater than zero");
        require(_referrer != msg.sender, "Referrer cannot be the buyer");

        // Check if the buyer already has a referrer set and only allow the same one
        require(
            referrer[msg.sender] == address(0) || referrer[msg.sender] == _referrer,
            "Referrer is already set and cannot be changed"
        );

        uint256 nanoToReceive = calculateNanoAmount(usdtAmount);
        uint256 referralReward = (nanoToReceive * REFERRAL_PERCENTAGE) / 100;

        // Deduct referral percentage if referrer exists and add balance to buyer
        uint256 nanoForBuyer = nanoToReceive - referralReward;
        balances[msg.sender] += nanoForBuyer;

        // Log deposit for buyer
        balanceLogs[msg.sender].push(BalanceLog({
            amount: nanoForBuyer,
            timestamp: block.timestamp,
            balanceType: BalanceType.Deposit
        }));

        // Set referrer if it’s the first time setting it
        if (referrer[msg.sender] == address(0)) {
            referrer[msg.sender] = _referrer;
        }

        // Add referral reward to referrer's balance and log it
        balances[_referrer] += referralReward;
        balanceLogs[_referrer].push(BalanceLog({
            amount: referralReward,
            timestamp: block.timestamp,
            balanceType: BalanceType.ReferralReward
        }));

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
