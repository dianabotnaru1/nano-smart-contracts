// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NanoMining is Ownable, ReentrancyGuard {
    IERC20 public usdtToken; // USDT token contract
    IERC20 public nanoToken; // NANO token contract
    address public fundWalletAddress;
    uint256 public roi;
    uint256 public fundRate;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public totalHarvestAmount;
    mapping(address => uint256) public latestSwapAmount;
    mapping(address => address) public referrer;

    enum BalanceType { Deposit, ReferralReward }

    struct BalanceLog {
        uint256 amount;
        uint256 timestamp;
        BalanceType balanceType;
    }
    mapping(address => BalanceLog[]) public balanceLogs;

    struct HarvestLog {
        uint256 amount;
        uint256 timestamp;
    }
    mapping(address => HarvestLog[]) public harvestLogs;

    struct SwapLog {
        uint256 amount;
        uint256 timestamp;
    }
    mapping(address => SwapLog[]) public swapLogs;

    uint256 public constant MIN_WITHDRAWAL = 15000 * 10**18; // Minimum withdrawal in NANO
    uint256 public constant REFERRAL_PERCENTAGE = 10; // 10% referral

    event NanoPurchased(address indexed buyer, uint256 usdtAmount, uint256 nanoReceived);
    event NANOHarvested(address indexed user, uint256 amount);
    event Swapped(address indexed user, uint256 nanoAmount, uint256 usdtReceived);
    event NanoTokenUpdated(address indexed newTokenAddress);
    event FundWalletUpdate(address indexed fundWalletAddress);
    event FundWalletRateUpdate(uint256 fundRate);
    event ROIUpdate(uint256 roi);
    event USDTWithdrawn(address indexed admin, address indexed to, uint256 amount);

    constructor(address _usdtToken) Ownable(msg.sender) {
        usdtToken = IERC20(_usdtToken);
        roi = 5;
        fundRate = 40;
    }

    // Method to set the NANO token address (only owner can call this)
    function setNanoTokenAddress(address _nanoToken) external onlyOwner {
        require(_nanoToken != address(0), "Invalid address: cannot be zero");
        nanoToken = IERC20(_nanoToken); // Update the NANO token address
        emit NanoTokenUpdated(_nanoToken); // Emit an event for logging
    }

    // Method to set the fund wallet address (only owner can call this)
    function setFundWalletAddress(address _fundWalletAddress) external onlyOwner {
        require(_fundWalletAddress != address(0), "Invalid address: cannot be zero");
        fundWalletAddress = _fundWalletAddress; // Update the fund wallet address
        emit FundWalletUpdate(_fundWalletAddress); // Emit an event for logging
    }

    // Method to set the ratio for fund wallet (only owner can call this)
    function setFundWalletRate(uint256 _fundRate) external onlyOwner {
        require(_fundRate > 0, "Ratio for the fund wallet should be greater than zero");
        fundRate = _fundRate; // Update the fund wallet rate
        emit FundWalletRateUpdate(_fundRate); // Emit an event for logging
    }

    // Method to set the ROI (only owner can call this)
    function setRoi(uint256 _roi) external onlyOwner {
        require(_roi > 0, "ROI should be greater than zero");
        roi = _roi; // Update the ROI
        emit ROIUpdate(_roi); // Emit an event for logging
    }

    // Admin function to withdraw USDT to an external address
    function withdrawUSDT(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address: cannot be zero");
        require(amount > 0, "Amount should be greater than zero");
        require(amount <= usdtToken.balanceOf(address(this)), "Insufficient contract balance");

        // Transfer USDT to the specified address
        usdtToken.transfer(to, amount);

        emit USDTWithdrawn(msg.sender, to, amount); // Emit event for logging
    }

    // Buy NANO
    function buyNano(uint256 usdtAmount, address _referrer) external nonReentrant {
        require(usdtAmount > 0, "Amount should be greater than zero");
        require(_referrer != msg.sender, "Referrer cannot be the buyer");

        // Check if the buyer already has a referrer set and only allow the same one


        uint256 scUsdtAmount = usdtAmount;
        uint256 fundWalletAmount = 0;

        if (fundWalletAddress != address(0)) {
            fundWalletAmount = (usdtAmount * fundRate) / 100;
            scUsdtAmount -= fundWalletAmount;
        }

        // Transfer USDT from the buyer to the contract
        usdtToken.transferFrom(msg.sender, address(this), scUsdtAmount);
        if (fundWalletAmount > 0) {
            usdtToken.transferFrom(msg.sender, fundWalletAddress, fundWalletAmount);
        }

        uint256 nanoToReceive = calculateNanoAmount(usdtAmount);
        uint256 currentTime = block.timestamp;

        uint256 nanoForBuyer = nanoToReceive;
        if (_referrer == address(0)) {
            balances[msg.sender] += nanoForBuyer;

            balanceLogs[msg.sender].push(BalanceLog({
                amount: nanoToReceive,
                timestamp: currentTime,
                balanceType: BalanceType.Deposit
            }));
        } else {
            uint256 referralReward = (nanoToReceive * REFERRAL_PERCENTAGE) / 100;

            // Deduct referral percentage if referrer exists and add balance to buyer
            nanoForBuyer = nanoToReceive - referralReward;
            balances[msg.sender] += nanoForBuyer;

            // Log deposit for buyer
            balanceLogs[msg.sender].push(BalanceLog({
                amount: nanoForBuyer,
                timestamp: currentTime,
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
                timestamp: currentTime,
                balanceType: BalanceType.ReferralReward
            }));
        }

        emit NanoPurchased(msg.sender, usdtAmount, nanoForBuyer);
    }

    // Calculate NANO amount based on USDT
    function calculateNanoAmount(uint256 usdtAmount) internal pure returns (uint256) {
        return usdtAmount * 156250 / 100; // Adjust as per requirement
    }

    function calculateUSDTAmount(uint256 nanoAmount) internal pure returns (uint256) {
        return nanoAmount * 100 / 156250; // Adjust as per requirement
    }

    // Calculate current left rewards for the user
    function calculateRewards(address _user, uint256 currentTime) internal view returns (uint256) {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < balanceLogs[_user].length; i++) {
            BalanceLog memory log = balanceLogs[_user][i];

            // Calculate seconds elapsed since each log's timestamp
            uint256 secondsElapsed = currentTime - log.timestamp;
            if (secondsElapsed > 30 days) secondsElapsed = 30 days;
            uint256 reward = (secondsElapsed * roi * log.amount) / (100 * 1 days);

            totalRewards += reward;
        }

        uint256 totalHarvestedAmount = 0;
        for (uint256 i = 0; i < harvestLogs[msg.sender].length; i++) {
            HarvestLog memory log = harvestLogs[msg.sender][i];

            totalHarvestedAmount += log.amount;
        }

        return totalRewards - totalHarvestedAmount;
    }

    function harvest(uint256 nanoAmount) external nonReentrant {
        require(nanoAmount > 0, "Nano Amount to harvest should be greater than zero");

        uint256 currentTime = block.timestamp;

        // Calculate current left rewards for the user
        uint256 currentRewards = calculateRewards(msg.sender, currentTime);

        require(currentRewards >= nanoAmount, "Nano Amount to harvest should be less than the current left rewards");

        harvestLogs[msg.sender].push(HarvestLog({
            amount: nanoAmount,
            timestamp: block.timestamp
        }));

        totalHarvestAmount[msg.sender] += nanoAmount;

        emit NANOHarvested(msg.sender, nanoAmount);
    }

    // Swap NANO for USDT with 10% admin fee
    function swapNanoForUSDT(uint256 nanoAmount) external nonReentrant {
        require(nanoAmount > MIN_WITHDRAWAL, "Amount should be greater than minimal withdrawal");
        require(nanoAmount <= totalHarvestAmount[msg.sender], "Amount exceeds total harvested amount");

        // Calculate USDT equivalent (assuming 15625 NANO = 10 USDT)
        uint256 usdtAmount = calculateUSDTAmount(nanoAmount);

        // Transfer net USDT to user
        usdtToken.transfer(msg.sender, usdtAmount);

        // Deduct the swapped amount from total harvested amount
        totalHarvestAmount[msg.sender] -= nanoAmount;

        latestSwapAmount[msg.sender] = usdtAmount;

        swapLogs[msg.sender].push(SwapLog({
            amount: usdtAmount,
            timestamp: block.timestamp
        }));

        emit Swapped(msg.sender, nanoAmount, usdtAmount);
    }

    function getLatestSwapAmount(address _miner) external view returns (uint256) {
        return latestSwapAmount[_miner];
    }

    // Get the current balance of the miner in NANO
    function getMinerBalance(address _miner) external view returns (uint256) {
        return balances[_miner];
    }

    // Get the total harvested NANO amount for the miner
    function getTotalHarvestedAmount(address _miner) external view returns (uint256) {
        return totalHarvestAmount[_miner];
    }

    // Get harvest logs for a miner
    function getHarvestLogs(address _miner) external view returns (HarvestLog[] memory) {
        return harvestLogs[_miner];
    }

    // Get balance logs for a miner
    function getBalanceLogs(address _miner) external view returns (BalanceLog[] memory) {
        return balanceLogs[_miner];
    }
}
