const hre = require("hardhat");

async function main() {
    const initialSupply = ethers.utils.parseUnits("1000000", 18); // Adjust as needed
    const USDT = await hre.ethers.getContractFactory("USDT");
    const nano = await USDT.deploy(initialSupply);

    await nano.deployed();

    console.log("USDT deployed to:", nano.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
