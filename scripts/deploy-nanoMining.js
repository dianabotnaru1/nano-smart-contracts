const hre = require("hardhat");

async function main() {
    const usdtTokenAddress = "0x55d398326f99059fF775485246999027B3197955";
    const adminWalletAddress = "0xe69Ae7eEd3221E80D792a26d65888b2343F19CF1";
    const NanoMining = await hre.ethers.getContractFactory("NanoMining");

    const nanoMining = await NanoMining.deploy(usdtTokenAddress, adminWalletAddress);
    await nanoMining.deployed();

    console.log("NanoMining deployed to: ", nanoMining.address);

    // Optional: Verify the contract on the blockchain explorer
    await hre.run("verify:verify", {
        address: nanoMining.address,
        constructorArguments: [usdtTokenAddress, adminWalletAddress],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
