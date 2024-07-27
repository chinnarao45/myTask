const NFTStakingSmartContract = artifacts.require("NFTStakingSmartContract");

module.exports = async function (deployer) {
 await deployer.deploy(NFTStakingSmartContract);
};
