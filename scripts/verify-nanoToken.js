const hre = require("hardhat");

async function main() {
    const contractAddress = "0xC9b1bC59Bbe8266D335bFfD2191f3638cA896C3c"; // Replace with your deployed contract address
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
