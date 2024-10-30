const hre = require("hardhat");

async function main() {
    const contractAddress = "0x3743EE58694c8BAFE978f4dF1e61F9d0396a2aca"; // Replace with your deployed contract address
    const initialSupply = "1000000"; // Replace with the constructor argument used in deployment

    await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: [hre.ethers.utils.parseUnits(initialSupply, 18)],
    });

    console.log("Contract verified on BscScan");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
