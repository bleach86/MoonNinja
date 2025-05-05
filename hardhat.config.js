require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");
//require("@foundry-rs/hardhat-anvil");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: `0.8.26`,
        settings: {
          optimizer: {
            enabled: true,
            runs: 1500,
          },
          evmVersion: `cancun`,
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: 137,
      forking: {
        url: "https://polygon-mainnet.chainnodes.org/1ad29aaa-6a86-4194-911c-0b912f880913",
        blockNumber: 71139986,
      },
    },
  },
};
