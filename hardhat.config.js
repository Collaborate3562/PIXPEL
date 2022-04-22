/**
* @type import('hardhat/config').HardhatUserConfig
*/
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
const { API_URL, PRIVATE_KEY, INFURA_ID } = process.env;
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
module.exports = {
   defaultNetwork: "rinkeby",
   networks: {
      hardhat: {},
      // binance: {
      //    url: API_URL,
      //    accounts: [`0x${PRIVATE_KEY}`]
      // },
      ropsten: {
         url: "https://ropsten.infura.io/v3/" + INFURA_ID,
         chainId: 3,
         gasPrice: 20000000000000,
         accounts: [`0x${PRIVATE_KEY}`]
      },
      rinkeby: {
         url: "https://rinkeby.infura.io/v3/" + INFURA_ID,
         chainId: 4,
         gasPrice: 20000000000,
         accounts: [`0x${PRIVATE_KEY}`]
      }
   },
   etherscan: {
      // Your API key for Etherscan
      // Obtain one at https://etherscan.io/
      // apiKey: "ZDNE9AKXQ1KIWA3VK6RQGTAB25AHTQ8NPC"
      apiKey: "S1VH5HN4RW22314GI9APVKVFIJ36IH5SXV"
   },
   solidity: {
      version: "0.8.7",
      settings: {
         optimizer: {
            enabled: true
         }
      }
   },
   paths: {
     sources: "./contracts",
     tests: "./test",
     cache: "./cache",
     artifacts: "./artifacts"
   },
   mocha: {
     timeout: 20000
   }
}