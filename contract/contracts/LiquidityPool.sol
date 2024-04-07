// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "./LuckyToken.sol";
// import "./MikiToken.sol";

contract LiquidityPool {
    address private tokenA;
    address private tokenB;
    uint256 private fee = 100; // 1% 手续费，以百分比为单位
    uint256 public totalSupply; // 总供应量

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token address");
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    // 获取手续费
    function getFee(uint256 amount) public view returns (uint256) {
        return (amount * fee) / 10000; // 计算手续费，以百分比为单位，需要除以10000
    }

    // 添加流动性
    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 || amountB > 0, "Invalid amounts: both cannot be zero");

        uint256 poolBalanceTokenA = ERC20(tokenA).balanceOf(address(this));
        uint256 poolBalanceTokenB = ERC20(tokenB).balanceOf(address(this));

        if (poolBalanceTokenA > 0 && poolBalanceTokenB > 0) {
            require(amountA * poolBalanceTokenB == amountB * poolBalanceTokenA, "Unbalanced amounts: must be in current ratio");
        }

        require(ERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer failed for tokenA");
        require(ERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer failed for tokenB");

        totalSupply += amountA + amountB;
    }

       // 移除流动性
    function removeLiquidity(uint256 poolTokens) external returns (uint256, uint256) {
        require(poolTokens <= totalSupply, "Insufficient pool tokens");
        uint256 amountA = (poolTokens * ERC20(tokenA).balanceOf(address(this))) / totalSupply;
        uint256 amountB = (poolTokens * ERC20(tokenB).balanceOf(address(this))) / totalSupply;

        if (tokenA != address(0)) {
            require(ERC20(tokenA).transfer(msg.sender, amountA), "Transfer failed for tokenA");
        }
        if (tokenB != address(0)) {
            require(ERC20(tokenB).transfer(msg.sender, amountB), "Transfer failed for tokenB");
        }

        totalSupply -= poolTokens;

        return (amountA, amountB);
    }

    function calculateSwapAmount(string memory tokenType, uint256 inputAmount) public view returns (uint256) {
        require(inputAmount > 0, "Input amount must be greater than 0");

        uint256 poolBalanceTokenA = ERC20(tokenA).balanceOf(address(this));
        uint256 poolBalanceTokenB = ERC20(tokenB).balanceOf(address(this));
        require(poolBalanceTokenA > 0 && poolBalanceTokenB > 0, "Insufficient liquidity");

        uint256 outputAmount;

        if (keccak256(abi.encodePacked(tokenType)) == keccak256(abi.encodePacked("tokenA"))) {
            // 用户提供tokenA，计算tokenB的数量
            uint256 feeAmount = getFee(inputAmount);
            uint256 inputAmountAfterFee = inputAmount - feeAmount;
            outputAmount = (inputAmountAfterFee * poolBalanceTokenB) / poolBalanceTokenA;
        } else {
            // 用户提供tokenB，计算tokenA的数量
            uint256 feeAmount = getFee(inputAmount);
            uint256 inputAmountAfterFee = inputAmount - feeAmount;
            outputAmount = (inputAmountAfterFee * poolBalanceTokenA) / poolBalanceTokenB;
        }

    return outputAmount;
}

    function swap(address userWallet, string memory tokenFrom, string memory tokenTo, uint256 amount) external returns (uint256) {
        address fromAddress;
        address toAddress;

        if (keccak256(abi.encodePacked(tokenFrom)) == keccak256(abi.encodePacked("tokenA"))) {
            fromAddress = tokenA;
            toAddress = tokenB;
        } else {
            fromAddress = tokenB;
            toAddress = tokenA;
        }

        // 检查代币余额是否足够，并转移代币
        require(ERC20(fromAddress).balanceOf(userWallet) >= amount, "Insufficient balance");
        require(ERC20(fromAddress).transferFrom(userWallet, address(this), amount), "Transfer failed for tokenFrom");

        // 计算交换后的代币数量，考虑手续费
        uint256 feeAmount = getFee(amount);
        uint256 amountOut = calculateSwapAmount(tokenFrom, amount);

        require(ERC20(toAddress).transfer(userWallet, amountOut), "Transfer failed for tokenTo");

        if (feeAmount > 0) {
            if (fromAddress != address(0)) {
                require(ERC20(fromAddress).transfer(address(this), feeAmount), "Transfer failed for fee");
            }
        }

        return amountOut;
    }

}