const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    const contractAddress = "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512";
    const NanoMining = await ethers.getContractFactory("NanoMining");
    const nanoMining = await NanoMining.attach(contractAddress);

    const usdtAmount = ethers.utils.parseUnits("100", 18); // Amount of USDT
    const referrer = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"; // Set this as needed

    const gasEstimate = await nanoMining.estimateGas.buyNano(usdtAmount, referrer);
    console.log("Estimated gas for buyNano:", gasEstimate.toString());
}

main();
