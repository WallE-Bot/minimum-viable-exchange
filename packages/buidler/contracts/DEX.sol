pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEX {

  using SafeMath for uint256;
  IERC20 token;

  uint256 public totalLiquidity;
  mapping (address => uint256) public liquidity;

  constructor(address token_addr) public {
    token = IERC20(token_addr);
  }

  function init(uint256 tokens) public payable returns (uint256) {
    require(totalLiquidity == 0, "DEX:init - already has liquidity");
    totalLiquidity = address(this).balance;
    liquidity[msg.sender] = totalLiquidity;
    require(token.transferFrom(msg.sender, address(this), tokens));
    return totalLiquidity;
  }

  function convertedOutput(
    uint256 input_amount,
    uint256 input_reserve,
    uint256 output_reserve
  ) public view returns (uint256) {
    uint256 input_amount_minus_fee = input_amount.mul(997);
    uint256 numerator = input_amount_minus_fee.mul(output_reserve);
    uint256 denominator = input_reserve.mul(1000).add(input_amount_minus_fee);

    return numerator / denominator;
  }

  function ethToToken() public payable returns (uint256) {
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 tokens_bought = convertedOutput(
      msg.value,
      address(this).balance.sub(msg.value),
      token_reserve
    );
    require(token.transfer(msg.sender, tokens_bought));
    return tokens_bought;
  }

  function tokenToEth(uint256 tokenAmount) public returns (uint256){
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_converted_to = convertedOutput(
      tokenAmount,
      token_reserve,
      address(this).balance
    );
    msg.sender.transfer(eth_converted_to);
    require(token.transferFrom(msg.sender, address(this), tokenAmount));
    return eth_converted_to;
  }

  function deposit() public payable returns (uint256){
    // get reserves
    uint256 eth_reserve = address(this).balance.sub(msg.value);
    uint256 token_reserve = token.balanceOf(address(this));

    // set token amount
    uint256 token_amount = (msg.value.mul(token_reserve) / eth_reserve).add(1);

    // liquidity minted for specific token
    uint256 liquidity_minted = msg.value.mul(totalLiquidity) / eth_reserve;

    // add liquidity to sender
    uint256 senderLiquidity = liquidity[msg.sender];
    liquidity[msg.sender] = senderLiquidity.add(liquidity_minted);

    // update total liquidity
    totalLiquidity = totalLiquidity.add(liquidity_minted);

    // require transferFrom
    require(token.transferFrom(msg.sender, address(this), token_amount));

    // return liquidity minted
    return liquidity_minted;
  }

  function withdraw(uint256 amount) public returns (uint256, uint256) {
    // get reserves
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_amount = amount.mul(address(this).balance)
      / totalLiquidity;
    uint256 token_amount = amount.mul(token_reserve);

    // update sender portions
    uint256 senderLiquidity = liquidity[msg.sender];
    liquidity[msg.sender] = senderLiquidity.sub(eth_amount);

    // update liquidity
    totalLiquidity = totalLiquidity.sub(eth_amount);

    // transfer amounts
    msg.sender.transfer(eth_amount);
    require(token.transfer(msg.sender, token_amount));

    return (eth_amount, token_amount);
  }
}
