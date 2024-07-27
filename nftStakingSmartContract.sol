// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; // Version of the Solidity

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";  
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// PausableUpgradeable smart contract is used to pause and unpause the contract

/* These modules are imported from the OpenZeppelin contracts for the NFT Staking Smart Contract */
contract NFTStakingSmartContract is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    ERC721Upgradeable public nft;
    ERC20Upgradeable public rewardToken;
    uint256 public xRewardsPerBlock;
    uint256 public unbondingPeriod;

    /*
      NFTStakingSmartContract (Name of our Contract) is inheriting from Initializable, UUPSUpgradeable, OwnableUpgradeable
      OwnableUpgradeable (Inheritance)
      IERC721 public nft ---> Stores the address of the NFT contract for Staking and Unstaking
      IERC20 public rewardToken ---> Stores the address of the ERC20 token for rewards
      uint256 public xRewardsPerBlock ---> Represents the number of rewards per block
      uint256 public unbondingPeriod ---> The required wait time after unstaking an NFT before it can be withdrawn
    */


    struct Stake {
        uint256 tokenId;
        uint256 stakedAt;
        uint256 unstakedAt;
    }

/*
 Stake ---> is a structre,it stores three values tokenId,stakeAt,unstakeAt,it is user defined datatype.
 tokenId ---> it represents the id of the token,it is integer.
 stakedAt ---> it represents that the at which time the token is stake,Basically it is the block number.
 unstakedAt ---> it represents that the at which time the user unStake the token for withDraw,Basically it is block number.
*/



    mapping(address => Stake[]) public stakes;
    mapping(uint256 => address) public tokenOwner;
    /*
address => Stake[] ---> Here we map the address to the Array of Stake Structurs, it means each Stake it contains the address of the owner,tokenId,stakedAt,unstakedAt
it means each address of the owner can Stake more than one tokens.
Here one Owner is represents one Index.
uint256 => address ---> Here the mapping is TokenId to address, it means is used to findout the onwer of the token.
*/


    event ContractInitialized(address nft, address rewardToken, uint256 xRewardsPerBlock, uint256 unbondingPeriod);
    event Staked(address indexed user, uint256 tokenId);
    event Unstaked(address indexed user, uint256 tokenId);
    event Withdrawn(address indexed user, uint256 tokenId);
/*
 Staked ---> it is an event whenever the token is Staked then the Stake function is emitted.
 Unstaked ---> is is an even whenever the token is Unstaked then the Unstake function is emitted.
*/


    function initialize(
        ERC721Upgradeable _nft,
        ERC20Upgradeable _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _unbondingPeriod
    ) public initializer {
        __Ownable_init(); 
        __Pausable_init(); 
        __UUPSUpgradeable_init(); 

        nft = _nft;
        rewardToken = _rewardToken;
        xRewardsPerBlock = _rewardPerBlock;
        unbondingPeriod = _unbondingPeriod;

        emit ContractInitialized(address(nft), address(rewardToken), xRewardsPerBlock, unbondingPeriod);
    }
/*
  Initializing the function which takes the parameter, those are address of the nftToken,address of the rewardsToken
  rewards for the block,unboindPeriod.
  By using there parameters we assign these values  to the  global variables.
*/

   
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
//This function for there is any modification are there, then the owner can change. Like pause,unpause etc....

    function stake(uint256 tokenId) external whenNotPaused {
        require(nft.ownerOf(tokenId) == msg.sender, "You are not the owner of this token");
        //Checking the ownership, if the onwer of the token is incorrect it revert this function.
        nft.transferFrom(msg.sender, address(this), tokenId);
       //transfer the token to the contract address

        bool alreadyStaked = false;
        for (uint256 i = 0; i < stakes[msg.sender].length; i++) {
            if (stakes[msg.sender][i].tokenId == tokenId) {
                alreadyStaked = true;
                break;
            }
        }
        require(!alreadyStaked, "Token is already staked");
        //This function is executed whenever the contract is not paused.
        stakes[msg.sender].push(Stake({
            tokenId: tokenId,
            stakedAt: block.number,
            unstakedAt: 0
        }));
        /*Here mapping is done. Storing the tokenId,stackedAt(at which time the owner stake
           the token),unstakeAt,These all stored in the address of the token owner.*/
        tokenOwner[tokenId] = msg.sender;//Assign the Owner to the tokenId.
        emit Staked(msg.sender, tokenId);//Event when the token is Stake.
    }
  
    function unstake(uint256 tokenId) external whenNotPaused {
        require(tokenOwner[tokenId] == msg.sender, "You are not the owner of this token");
         //It checks the owner of the token if the owner is incorrect then the function is reverted.
        uint256 reward = calculateReward(msg.sender, tokenId);//calculating the rewards.
        require(rewardToken.balanceOf(address(this)) >= reward, "Insufficient reward funds");
        //The calculated reqrd is transferred to the owner address from the rewardToken contract.
        rewardToken.transfer(msg.sender, reward);

        bool tokenFound = false;
        for (uint256 i = 0; i < stakes[msg.sender].length; i++) {
            if (stakes[msg.sender][i].tokenId == tokenId) {
                stakes[msg.sender][i].unstakedAt = block.number;
                tokenFound = true;
                break;
            }
        }
    /* this loop runs in the stakes array for the owner and check the every ith tokenId with the given tokenId(Want to unstaked Token)
     if it is matches then then updated blockNumber where it is Unstaked, then break the loop and come outside the function by emit the event. 
    */
        require(tokenFound, "Stake not found");

        emit Unstaked(msg.sender, tokenId);
    }

    function withdraw(uint256 tokenId) external whenNotPaused {
        require(tokenOwner[tokenId] == msg.sender, "You are not the owner of this token");
  // check if the owner of this token is incorrect the revert the function.
        bool tokenFound = false;
        for (uint256 i = 0; i < stakes[msg.sender].length; i++) {
            if (stakes[msg.sender][i].tokenId == tokenId) {
                require(stakes[msg.sender][i].unstakedAt > 0, "Token is not unstaked yet");
                require(block.number >= stakes[msg.sender][i].unstakedAt + unbondingPeriod, "Unbonding period not finished");

                nft.transferFrom(address(this), msg.sender, tokenId);

                // Remove stake
                stakes[msg.sender][i] = stakes[msg.sender][stakes[msg.sender].length - 1];
                stakes[msg.sender].pop();

                delete tokenOwner[tokenId];
                emit Withdrawn(msg.sender, tokenId);
                tokenFound = true;
                break;
            }
        }
        /*
        1)Checks the owner of the token,if incorrect then Stop the execution of this functon.
        2)Iterate through the loop for search the which token is withdraw for rewards.
        3)It checks the the block number of the token if it is >0 then continue else stop the function execution.
        4)It checks the block number of the current block should be greater than or equal to the sum of block
         numbers of where the token is staked and where the token is unstakes.
          if is true then the owner is able to withdraw the result,else the unbonding period is not reached.
        5)If it is true then the rewards are transfered to the onwer from the contract address safely.
        6)So the owner is withdraw the rewards,so remove the token from the owners staked tokens.
        7)After this the function is emitted.        
     */

        require(tokenFound, "Stake not found");
    }

    function calculateReward(address user, uint256 tokenId) internal view returns (uint256) {
        for (uint256 i = 0; i < stakes[user].length; i++) {
            if (stakes[user][i].tokenId == tokenId) {
                uint256 stakedAt = stakes[user][i].stakedAt;
                uint256 unstakedAt = stakes[user][i].unstakedAt > 0 ? stakes[user][i].unstakedAt : block.number;
                uint256 totalRewards = (unstakedAt - stakedAt) * xRewardsPerBlock;
                return totalRewards;
            }
        }
        return 0;
        /*
  1)calculateReward function take address of the owner and tokenId as parameters to calculate the rewards.
  2)Iterate through the loop for search the tokenId for claiming.
  3)If the tokenId is matches with one of the users tokenIds then,
    3.1) Calculate the Number of blocks the token is stacked.
    3.2) Then return the rewards as the number of blocks*xRewardsPerBlock as rewards.
*/
    }

    function pause() external onlyOwner {
        //This function is used for pause the Contract execution,this is only the Owner of the contract will do.
        _pause();
    }

    function unpause() external onlyOwner {
    //This function is used for unpause the Contract execution,this is only the owner of the contract will do.
        _unpause();
    }
}
