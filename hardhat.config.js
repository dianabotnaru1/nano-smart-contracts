require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.27",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    binanceTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: [process.env.PRIVATE_KEY],
    },
    bsc: {
      url: 'https://bsc-dataseed.binance.org/', // BSC Mainnet RPC URL
      accounts: [process.env.PRIVATE_KEY],
      chainId: 56, // BSC Mainnet Chain ID
      gasPrice: 20000000000, // Gas price in wei (20 Gwei)
    }
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY,
  },
};
