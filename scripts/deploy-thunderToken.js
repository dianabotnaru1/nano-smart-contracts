const hre = require("hardhat");

async function main() {
    const initialSupply = ethers.utils.parseUnits("100000000000", 6); // Adjust as needed
    const thunderContractFactory = await hre.ethers.getContractFactory("ThunderToken");
    const thunder = await thunderContractFactory.deploy(initialSupply);

    await thunder.deployed();

    console.log("Thunder deployed to:", thunder.address);

    await hre.run("verify:verify", {
        address: thunder.address,
        contract: "contracts/ThunderToken.sol:ThunderToken",
        constructorArguments: [hre.ethers.utils.parseUnits("100000000000", 6)],
    });

    console.log("Contract verified on BscScan");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
