const hre = require("hardhat");

async function main() {
    const usdtTokenAddress = "0x221c5B1a293aAc1187ED3a7D7d2d9aD7fE1F3FB0";
    const NanoMining = await hre.ethers.getContractFactory("NanoMining");

    const nanoMining = await NanoMining.deploy(usdtTokenAddress);
    await nanoMining.deployed();

    console.log("NanoMining deployed to: ", nanoMining.address);

    // Optional: Verify the contract on the blockchain explorer
    await hre.run("verify:verify", {
        address: nanoMining.address,
        constructorArguments: [usdtTokenAddress],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
