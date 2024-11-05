const hre = require("hardhat");

async function main() {
    const usdtTokenAddress = "0x37082adEC30886088C83f02A2537f2EA7DD31CbC";
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
