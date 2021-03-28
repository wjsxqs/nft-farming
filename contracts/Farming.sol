// contracts/Farming.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Farming is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct UserInfo {
        uint256 amount;           // current staked LP
        uint256 lastUpdateTime;   // unix timestamp for last details update (when pointsDebt calculated)
        uint256 pointsDebt;       // total points collected before latest deposit
    }
    
    struct NFTInfo {
        address contractAddress;
        uint256 id;             // NFT id
        uint256 remaining;      // NFTs remaining to farm
        uint256 price;          // points required to claim NFT
    }
    
    uint256 public emissionRate;       // points generated per LP token per second staked
    IERC20 public lpToken;             // token being staked
    
    NFTInfo[] public nfts;
    mapping(address => UserInfo) public users;

    event NFTAdded(address indexed contractAddress, uint256 id, uint256 total, uint256 price);
    event Staked(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 nftId, uint256 quantity);
    event Withdrawn(address indexed user, uint256 amount);
    
    constructor(uint256 _emissionRate, IERC20 _lpToken) public {
        emissionRate = _emissionRate;
        lpToken = _lpToken;
    }
    
    function addNFT(
        address contractAddress,    // Only ERC-1155 NFT Supported!
        uint256 id,
        uint256 total,              // amount of NFTs deposited to farm (need to approve before)
        uint256 price
    ) external onlyOwner {
        IERC1155(contractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            id,
            total,
            ""
        );
        nfts.push(NFTInfo({
            contractAddress: contractAddress,
            id: id,
            remaining: total,
            price: price
        }));

        emit NFTAdded(contractAddress, id, total, price);
    }

    function stake(uint256 amount) external {
        lpToken.safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        
        UserInfo storage user = users[msg.sender];
        
        // already deposited before
        if(user.amount != 0) {
            user.pointsDebt = pointsBalance(msg.sender);
        }
        user.amount = user.amount.add(amount);
        user.lastUpdateTime = block.timestamp;

        emit Staked(msg.sender, amount);
    }
    
    // claim nft if points threshold reached
    function claim(uint256 nftId, uint256 quantity) public {
        NFTInfo storage nft = nfts[nftId];
        require(nft.remaining > 0, "All NFTs farmed");
        require(pointsBalance(msg.sender) >= nft.price.mul(quantity), "Insufficient Points");
        UserInfo storage user = users[msg.sender];
        
        // deduct points
        user.pointsDebt = pointsBalance(msg.sender).sub(nft.price.mul(quantity));
        user.lastUpdateTime = block.timestamp;
        
        // transfer nft
        IERC1155(nft.contractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            nft.id,
            quantity,
            ""
        );
        
        nft.remaining = nft.remaining.sub(quantity);

        emit Claim(msg.sender, nftId, quantity);
    }
    
    function claimBatch(uint256[] calldata nftIds, uint256[] calldata quantity) external {
        require(nftIds.length == quantity.length, "Incorrect array length");
        for(uint64 i=0; i< nftIds.length; i++) {
            claim(nftIds[i], quantity[i]);
        }
    }
    
    function withdraw(uint256 amount) public {
        UserInfo storage user = users[msg.sender];
        require(user.amount >= amount, "Insufficient staked");
        
        // update users
        user.pointsDebt = pointsBalance(msg.sender);
        user.amount = user.amount.sub(amount);
        user.lastUpdateTime = block.timestamp;
        
        lpToken.safeTransfer(
            msg.sender,
            amount
        );

        emit Withdrawn(msg.sender, amount);
    }
    
    function exit() external {
        withdraw(users[msg.sender].amount);
    }
    
    function pointsBalance(address account) public view returns (uint256) {
        UserInfo memory user = users[account];
        return user.pointsDebt.add(_unDebitedPoints(user));
    }
    
    function _unDebitedPoints(UserInfo memory user) internal view returns (uint256) {
        uint256 blockTime = block.timestamp;
        return blockTime.sub(user.lastUpdateTime).mul(emissionRate).mul(user.amount);
    }
    
    function nftCount() public view returns (uint256) {
        return nfts.length;
    }
    
    // Required function to allow receiving ERC-1155
    function onERC1155Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*id*/,
        uint256 /*value*/,
        bytes calldata /*data*/
    )
        external
        pure
        returns(bytes4)
    {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }
}
