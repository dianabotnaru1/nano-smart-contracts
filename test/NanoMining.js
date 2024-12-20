const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NanoMining Contract", function () {
    let NanoMining;
    let nanoMining;
    let USDT;
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let adminWallet;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, adminWallet] = await ethers.getSigners();

        // Deploy USDT mock token
        const MockToken = await ethers.getContractFactory("NanoToken");
        USDT = await MockToken.deploy(ethers.utils.parseUnits("1000000", 18));
        await USDT.deployed();

        console.log("USDT deployed to:", USDT.address);

        // Deploy NanoMining contract
        NanoMining = await ethers.getContractFactory("NanoMining");
        nanoMining = await NanoMining.deploy(USDT.address, adminWallet.address);
        await nanoMining.deployed();

        console.log("NanoMining deployed to:", nanoMining.address);

        // Transfer USDT to addr1 for testing
        await USDT.transfer(addr1.address, ethers.utils.parseUnits("1000", 18));
        await USDT.connect(addr1).approve(nanoMining.address, ethers.utils.parseUnits("1000", 18));
    });

    describe("Deployment", function () {
        it("Should set the correct USDT token address and fund wallet address", async function () {
            expect(await nanoMining.usdtToken()).to.equal(USDT.address);
            expect(await nanoMining.fundWalletAddress()).to.equal(adminWallet.address);
        });
    });

    describe("buyNano function", function() {
        it("should deposit the correct USDT", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("100", 18), '0x0000000000000000000000000000000000000000');

            const scBalance = await USDT.balanceOf(nanoMining.address);
            const fundWalletBalance = await USDT.balanceOf(adminWallet.address);

            expect(+ethers.utils.formatUnits(scBalance, 18)).to.equal(80);
            expect(+ethers.utils.formatUnits(fundWalletBalance, 18)).to.equal(20);
        })

        it("Should get the correct Nano if the referral address is zero address", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("100", 18), '0x0000000000000000000000000000000000000000');

            const nanoBalance = await nanoMining.getMinerBalance(addr1.address);

            expect(+ethers.utils.formatUnits(nanoBalance, 18)).to.equal(156250);
        })

        it("Should get the correct Nano if the referral address isn't zero address", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("100", 18), addr2.address);

            const nanoBalance1 = await nanoMining.getMinerBalance(addr1.address);

            expect(+ethers.utils.formatUnits(nanoBalance1, 18)).to.equal(156250);
        })
    })

    describe("harvest function", function() {
        it("Should harvest the correct Nano", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("1000", 18), addr2.address);
            await nanoMining.connect(addr1).harvest(ethers.utils.parseUnits("0.01", 18));

            const harvestAmount = await nanoMining.getTotalHarvestedAmount(addr1.address);

            expect(+ethers.utils.formatUnits(harvestAmount, 18)).to.equal(0.01);
        })
    })

    describe("mining function", function() {
        it("Should reward the correct Nano", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("1000", 18), addr2.address);
            await ethers.provider.send("evm_increaseTime", [86400]);
            await nanoMining.connect(addr1).harvest(ethers.utils.parseUnits("15625", 18));
            await nanoMining.connect(addr1).mining(ethers.utils.parseUnits("1000", 18));

            const nanoBalance = await nanoMining.getMinerBalance(addr1.address);

            expect(+ethers.utils.formatUnits(nanoBalance, 18)).to.equal(1563500);
        })
    })

    describe("swapNanoForUSDT function", function() {
        it("Should swap to the correct USDT", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("1000", 18), addr2.address);
            await ethers.provider.send("evm_increaseTime", [86400]);
            await nanoMining.connect(addr1).harvest(ethers.utils.parseUnits("15625", 18));
            await nanoMining.connect(addr1).swapNanoForUSDT(ethers.utils.parseUnits("15625", 18), addr3.address);

            const usdtAmount = await nanoMining.getLatestSwapAmount(addr1.address);
            const swappedAmount = await USDT.balanceOf(addr3.address);

            expect(+ethers.utils.formatUnits(usdtAmount, 18)).to.equal(10);
            expect(+ethers.utils.formatUnits(swappedAmount, 18)).to.equal(10);
        })
    })

    describe("calculateNanoAmount function", function() {
        it("Should get 5% reward for one day", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("200", 18), addr2.address);

            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine", []);

            const block = await ethers.provider.getBlock("latest");

            const currentTimestamp = block.timestamp;

            const totalRewards = await nanoMining.calculateRewards(addr1.address, currentTimestamp);

            expect(+ethers.utils.formatUnits(totalRewards, 18)).to.equal(15625);
        })

        it("Should limit to get the reward after 30 days", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("200", 18), addr2.address);

            await ethers.provider.send("evm_increaseTime", [86400 * 31]);
            await ethers.provider.send("evm_mine", []);

            const block = await ethers.provider.getBlock("latest");

            const currentTimestamp = block.timestamp;

            const totalRewards = await nanoMining.calculateRewards(addr1.address, currentTimestamp);

            expect(+ethers.utils.formatUnits(totalRewards, 18)).to.equal(15625 * 30);
        })

        it("should calculate the referral reward and shouldn't apply ROI", async function() {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("200", 18), addr2.address);

            await ethers.provider.send("evm_increaseTime", [86400 * 30]);
            await ethers.provider.send("evm_mine", []);
            const block = await ethers.provider.getBlock("latest");

            const currentTimestamp = block.timestamp;

            const totalRewards = await nanoMining.calculateRewards(addr2.address, currentTimestamp);

            expect(+ethers.utils.formatUnits(totalRewards, 18)).to.equal(31250);
        })

        it("Should get the correct reward if the users invest twice", async function () {
            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("200", 18), addr2.address);

            await ethers.provider.send("evm_increaseTime", [86400]);

            await nanoMining.connect(addr1).buyNano(ethers.utils.parseUnits("200", 18), addr2.address);

            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine", []);

            const block = await ethers.provider.getBlock("latest");

            const currentTimestamp = block.timestamp;

            const totalRewards = await nanoMining.calculateRewards(addr1.address, currentTimestamp);

            expect(+ethers.utils.formatUnits(totalRewards, 18)).to.equal(15625 * 3);
        })
    })
});

