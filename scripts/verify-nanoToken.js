const hre = require("hardhat");

async function main() {
    const contractAddress = "0x37082adEC30886088C83f02A2537f2EA7DD31CbC"; // Replace with your deployed contract address
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
