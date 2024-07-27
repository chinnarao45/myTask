const Web3 = require('web3'); // Importing the Web3 library
const TruffleContract = require('@truffle/contract'); // Importing the Truffle contract library

// Path to the contract artifact
const nftStakingArtifact = require('./build/contracts/NFTStakingSmartContract.json');

// Connect to Ganache
const web3 = new Web3('http://127.0.0.1:7545');

// Create a contract abstraction
const NFTStaking = TruffleContract(nftStakingArtifact);
NFTStaking.setProvider(web3.currentProvider);

const main = async () => {
  try {
    // Get accounts from web3
    const accounts = await web3.eth.getAccounts();

    // Deploy the contract
    const instance = await NFTStaking.deployed();

    // Example of initializing the contract
    const nftAddress = "0xEbFe221c26AEF330cf8A4A24f315Fd59F82dd29E";
    const rewardTokenAddress = "0xC779ae7e77239BD2d16AB5f095db35d00cb4ee01";
    const rewardPerBlock = web3.utils.toWei("1", "ether");
    const unbondingPeriod = 100;

    await instance.initialize(nftAddress, rewardTokenAddress, rewardPerBlock, unbondingPeriod, { from: accounts[0] });
    console.log("Contract initialized");

    // Example of staking an NFT
    const tokenId = 1;
    await instance.stake(tokenId, { from: accounts[0] });
    console.log("NFT staked");

    // Example of unstaking an NFT
    await instance.unstake(tokenId, { from: accounts[0] });
    console.log("NFT unstaked");

    // Example of withdrawing an NFT
    await instance.withdraw(tokenId, { from: accounts[0] });
    console.log("NFT withdrawn");

  } catch (error) {
    console.error(error);
    process.exit(1);
  }
};

main();
