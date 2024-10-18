// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint _amount) external;
}

contract NFTMarketplace is Ownable {
    struct Sale {
       address tokenAddress;
       uint256 tokenId;
       address erc20Token;
       uint256 price;
       bool isERC721;
    }

    IERC20 public immutable token;
    IWETH public immutable weth;
    uint256 public constant FEE_PERCENTAGE = 55; 
    uint256 ownersEtherAmount;
    uint256 ownersERC20TokenAmount;
    
    mapping(address tokenOwner => Sale) public sales;
    mapping(address => uint256) public tokensSold;

    constructor(
        IERC20 _token,
        IWETH _weth
        )
        Ownable(msg.sender){
            token = _token;
            weth = _weth;
        }       

        function saleForERC721(address _token721,uint256 _tokenId721,address _erc20Token,uint256 _price) external {
            require(IERC721(_token721).getApproved(_tokenId721) == address(this) || IERC721(_token721).isApprovedForAll(msg.sender, address(this)),"not approved the ERC20tokens");
            require(IERC721(_token721).ownerOf(_tokenId721) == msg.sender, "ERC721 : not the owner");
            _createSale(_token721, _tokenId721, _erc20Token, _price , true);
        }

        function saleForERC1155(address _token1155,uint256 _tokenId1155,address _erc20Token,uint256 _price) external {
            require(IERC1155(_token1155).isApprovedForAll(msg.sender, address(this)),"not approved the ERC721tokens");
           _createSale(_token1155, _tokenId1155, _erc20Token, _price, false);
        }

        function buy(address _seller , bool _paymentInWeth) external payable {
          Sale memory sale = sales[_seller];
          
          require(IERC20(sale.erc20Token).allowance(msg.sender, address(this)) >= sale.price, "erc20 allowance too low");
          require(sale.price > 0, "price not set in the sale");
          uint256 fee = (sale.price  * FEE_PERCENTAGE) / 10000; // 0.55% fee
          
          tokensSold[msg.sender] += 1;
          if(sale.erc20Token == address(0)){
            ownersEtherAmount += fee;
            if(_paymentInWeth){
               IWETH(weth).deposit{value: msg.value}();
               require(IWETH(weth).transfer(_seller, sale.price - fee), "WETH transfer failed");
            } else {
              (bool ok,) = payable(_seller).call{value: sale.price - fee}("");
              require(ok, "payment transfer failed. Please try again.");
            }
          } else {
            ownersERC20TokenAmount += fee;
            IERC20(sale.erc20Token).transferFrom(msg.sender,_seller, sale.price - fee);
          }
          
          if(sale.isERC721){
            IERC721(sale.tokenAddress).safeTransferFrom(_seller,msg.sender,sale.tokenId);
          }else{
            IERC1155(sale.tokenAddress).safeTransferFrom(_seller,msg.sender,sale.tokenId, 1,"");
          }

          delete sales[_seller];
        }

        function withdraw() external onlyOwner {
           uint256 etherAmount = ownersEtherAmount;
           ownersEtherAmount = 0;
           if(etherAmount > 0){
             uint256 wethBalance = weth.balanceOf(address(this));
             if(wethBalance > 0){
               weth.withdraw(wethBalance);  // Converts WETH to ETH
               (bool ok, ) = payable(owner()).call{value: wethBalance}("");
               require(ok, "WETH withdrawal failed");
             }else{
                (bool ok,) = payable(owner()).call{value: etherAmount}("");
                require(ok,"Trx failed");
             }
           } 
            
           uint256 erc20Amount = ownersERC20TokenAmount;
           ownersERC20TokenAmount = 0;
           if(erc20Amount > 0){
              IERC20(token).transfer(msg.sender , erc20Amount);
           }
        }

        function _createSale(
            address _token,
            uint256 _tokenId,
            address _erc20Token,
            uint256 _price,
            bool _isERC721
         ) internal {
            require(_erc20Token == address(token) , "not acceptable token address");
            sales[msg.sender] = Sale(_token, _tokenId,_erc20Token, _price,_isERC721);
          }

      function onERC1155Received(
        address ,
        address ,
        uint256 ,
        uint256 ,
        bytes calldata
      ) external pure returns (bytes4){
        revert("no need to transfer the asset to the marketplace contract");
      }

    function onERC1155BatchReceived(
        address ,
        address ,
        uint256[] calldata ,
        uint256[] calldata ,
        bytes calldata 
    ) external pure returns (bytes4) {
       revert("no need to transfer the asset to the marketplace contract");
    }

      function onERC721Received(
        address ,
        address ,
        uint256 ,
        bytes calldata 
    ) external pure returns (bytes4){
       revert("no need to transfer the asset to the marketplace contract");
    }
}  
    