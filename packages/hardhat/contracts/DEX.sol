// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this branch/repo. Also return variable names that may need to be specified exactly may be referenced (if you are confused, see solutions folder in this repo and/or cross reference with front-end code).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(
        address indexed swapper,
        string tradeType,
        uint256 ethInput,
        uint256 tokenReceived
    );

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(
        address indexed swapper,
        string tradeType,
        uint256 ethReceived,
        uint256 tokensold
    );

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(
        address indexed provider,
        uint256 lpMinted,
        uint256 ethProvided,
        uint256 tokenProvided
    );

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(
        address indexed provider,
        uint256 lpRemoved,
        uint256 ethRemoved,
        uint256 tokenRemoved
    );

    /* ========== CONSTRUCTOR ========== */

    constructor(address _token_addr) {
        token = IERC20(_token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "Already initialize");
        require(tokens > 0 && msg.value > 0, "Not enough token or ETH sent");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        bool success = token.transferFrom(msg.sender, address(this), tokens);
        require(success, "Transfer Failed");
        return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        //formula with .3% fee on xInput
        // (x + dX * (997/1000)) * (y - dY) = x*y;
        // (x*1000 + dX*997) * (y - dY) = x*y*1000;
        // x*y*1000 + y*dX*997 - x*dY*1000 - dX*dY*997 = x*Y*1000;
        // y*dX*997 - x*dY*1000 - dX*dY*997 = 0;
        // dY*(x*1000 + dX*997) = y*dX*997;
        // dY = (y * dX *997) / (x*1000 + dX*997);
        require(xInput > 0, "Not enough input");
        //xInputWithFee = xInput * 997/1000;
        uint256 numerator = (xInput * 997) * yReserves;
        uint256 denominator = (xInput * 997) + (xReserves * 1000);
        return (numerator / denominator);
        //return yOutput;
    }

    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     *
     */
    function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL (Buying $BAL)
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "Not enough ether");
        uint256 ethInput = msg.value;
        uint256 ethReserve = address(this).balance - ethInput;
        uint256 balReserve = token.balanceOf(address(this));
        tokenOutput = price(ethInput, ethReserve, balReserve);
        bool success = token.transfer(msg.sender, tokenOutput);
        // bool success = token.transferFrom(
        //     address(this),
        //     msg.sender,
        //     tokenOutput
        // );
        require(success, "Failed to transfer token");
        emit EthToTokenSwap(
            msg.sender,
            "Buying BAL Token",
            ethInput,
            tokenOutput
        );
        return tokenOutput;
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether (Selling $BAL)
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(
            tokenInput > 0 && token.balanceOf(msg.sender) >= tokenInput,
            "Not enough BAL token"
        );
        uint256 ethReserve = address(this).balance;
        uint256 balReserve = token.balanceOf(address(this));
        ethOutput = price(tokenInput, balReserve, ethReserve);
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            tokenInput
        );
        require(success, "Can't transfer token to pool");
        (bool sent, ) = payable(msg.sender).call{value: ethOutput}("");
        require(sent, "Eth transfer failed");
        emit TokenToEthSwap(
            msg.sender,
            "Selling BAL token",
            ethOutput,
            tokenInput
        );
        return ethOutput;
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
        require(totalLiquidity > 0, "The pool is not yet initialize");
        require(msg.value > 0, "Not enough token or ETH sent");
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance - msg.value;
        tokensDeposited = (tokenReserve * msg.value) / ethReserve;
        require(
            tokensDeposited <= token.balanceOf(msg.sender),
            "You don't have enough token"
        );
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            tokensDeposited
        );
        require(success, "Transfer Failed");
        // liquidityMinted / totalLiquidty = ethProvided / etheReserve;
        uint256 liquidityMinted = (totalLiquidity * msg.value) / ethReserve;
        totalLiquidity += liquidityMinted;
        liquidity[msg.sender] += msg.value;

        emit LiquidityProvided(
            msg.sender,
            liquidityMinted,
            msg.value,
            tokensDeposited
        );

        return tokensDeposited;
    }

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount)
        public
        returns (uint256 eth_amount, uint256 token_amount)
    {
        require(liquidity[msg.sender] >= amount, "Not enough liquidity");

        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));

        eth_amount = (ethReserve * amount) / totalLiquidity;
        token_amount = (tokenReserve * amount) / totalLiquidity;

        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;
        bool success = token.transfer(msg.sender, token_amount);
        // bool success = token.transferFrom(
        //     address(this),
        //     msg.sender,
        //     token_amount
        // );
        require(success, "Failed to trasfer BAL token");
        (bool sent, ) = payable(msg.sender).call{value: eth_amount}("");
        require(sent, "Failed to transfer ETH");
        emit LiquidityRemoved(msg.sender, amount, eth_amount, token_amount);
        return (eth_amount, token_amount);
    }
}
