const hre = require("hardhat");

async function main() {
    const initialSupply = hre.ethers.utils.parseUnits("1000000", 18); // Adjust as needed
    const NanoToken = await hre.ethers.getContractFactory("NanoToken");
    const nano = await NanoToken.deploy(initialSupply);

    await nano.deployed();

    console.log("NanoToken deployed to:", nano.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
