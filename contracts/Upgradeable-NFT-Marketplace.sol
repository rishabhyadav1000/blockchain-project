
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interface/IWETH.sol";

contract NFTMarketplace is  Initializable, OwnableUpgradeable, ERC1155SupplyUpgradeable {
    /// @notice Structure to represent a sale of an NFT
    struct Sale {
        address tokenAddress;  // Address of the token (ERC721/1155)
        uint256 tokenId;       // Token ID of the NFT
        address erc20Token;    // ERC20 token used for payment
        uint256 price;         // Price of the NFT in the ERC20 token
        bool isERC721;         // Is the NFT an ERC721 token
    }

    IWETH public weth;
    uint256 public constant FEE_PERCENTAGE = 55;  // 0.55% fee (55/10000)
    uint256 public ownersEtherAmount;             // Accumulated Ether fee for the owner
    uint256 public ownersWethAmount;              // Accumulated WETH fee for the owner

    mapping(address => mapping(uint256 => Sale)) public sales;  // Mapping to track sales
    mapping(address => uint256) public tokensSold;              // Track number of tokens sold by address
    mapping(IERC20 => uint256) public erc20FeesAmounts;         // Fees accumulated in different ERC20 tokens

    /// @notice Emitted when an NFT is listed for sale
    event SaleCreated(address indexed seller, address indexed tokenAddress, uint256 tokenId, uint256 price, bool isERC721);

    /// @notice Emitted when an NFT is bought
    event NFTBought(address indexed buyer, address indexed seller, address tokenAddress, uint256 tokenId, uint256 price, bool isERC721);

    /// @notice Emitted when the owner withdraws accumulated Ether
    event EtherWithdrawn(address indexed owner, uint256 amount);

    /// @notice Emitted when the owner withdraws accumulated WETH
    event WethWithdrawn(address indexed owner, uint256 amount);

    /// @notice Emitted when the owner withdraws accumulated ERC20 tokens
    event ERC20Withdrawn(address indexed owner, address tokenAddress, uint256 amount);

    /* /// @param _weth The address of the WETH contract
    /// @param baseURI The base URI for the ERC1155 tokens
    constructor(IWETH _weth, string memory baseURI) Ownable(msg.sender) ERC1155(baseURI) {
        weth = _weth;
    } */

    function initiazer(IWETH _weth, string memory baseURI) initializer external {
        __ERC1155_init(baseURI);
        __Ownable_init(msg.sender);
        weth = _weth;
    }

    /// @notice Function to list an ERC721 token for sale
    /// @param _token721 Address of the ERC721 contract
    /// @param _tokenId721 Token ID of the ERC721 token
    /// @param _erc20Token Address of the ERC20 token used for payment
    /// @param _price Sale price of the ERC721 token
    function saleForERC721(
        address _token721,
        uint256 _tokenId721,
        address _erc20Token,
        uint256 _price
    ) external {
        require(
            IERC721(_token721).getApproved(_tokenId721) == address(this) ||
            IERC721(_token721).isApprovedForAll(msg.sender, address(this)),
            "not approved the ERC721Tokens"
        );
        require(
            IERC721(_token721).ownerOf(_tokenId721) == msg.sender,
            "ERC721: not the owner"
        );
        _createSale(_token721, _tokenId721, _erc20Token, _price, true);
    }

    /// @notice Function to list an ERC1155 token for sale
    /// @param _token1155 Address of the ERC1155 contract
    /// @param _tokenId1155 Token ID of the ERC1155 token
    /// @param _erc20Token Address of the ERC20 token used for payment
    /// @param _price Sale price of the ERC1155 token
    function saleForERC1155(
        address _token1155,
        uint256 _tokenId1155,
        address _erc20Token,
        uint256 _price
    ) external {
        require(totalSupply(_tokenId1155) == 1, "erc1155: not an NFT");
        require(_price > 0, "price not set in the sale");
        require(
            IERC1155(_token1155).isApprovedForAll(msg.sender, address(this)),
            "not approved the ERC721tokens"
        );
        _createSale(_token1155, _tokenId1155, _erc20Token, _price, false);
    }

    /// @notice Function to buy an NFT
    /// @param _seller Address of the seller
    /// @param _id Token ID of the NFT being bought
    function buy(address _seller, uint256 _id) external payable {
        Sale memory sale = sales[_seller][_id];

        uint256 fee = (sale.price * FEE_PERCENTAGE) / 10000;  // Calculate fee (0.55%)

        tokensSold[msg.sender] += 1;
        if (sale.erc20Token == address(0)) {
            ownersEtherAmount += fee;
            require(msg.value == sale.price, "Not enough eth value supplied");

            (bool ok, ) = payable(_seller).call{value: sale.price - fee}("");
            require(ok, "payment transfer failed");

        } else if (sale.erc20Token == address(weth)) {
            require(msg.value == sale.price, "Not enough eth value supplied");
            ownersWethAmount += fee;
            weth.deposit{value: msg.value}();
            require(weth.transfer(_seller, sale.price - fee), "WETH transfer failed");

        } else {
            erc20FeesAmounts[IERC20(sale.erc20Token)] += fee;
            require(
                IERC20(sale.erc20Token).allowance(msg.sender, address(this)) >= sale.price,
                "erc20 allowance too low"
            );
            IERC20(sale.erc20Token).transferFrom(
                msg.sender,
                _seller,
                sale.price - fee
            );
        }

        if (sale.isERC721) {
            IERC721(sale.tokenAddress).safeTransferFrom(
                _seller,
                msg.sender,
                sale.tokenId
            );
        } else {
            IERC1155(sale.tokenAddress).safeTransferFrom(
                _seller,
                msg.sender,
                sale.tokenId,
                1,
                ""
            );
        }

        emit NFTBought(msg.sender, _seller, sale.tokenAddress, sale.tokenId, sale.price, sale.isERC721);
        delete sales[_seller][_id];
    }

    /// @notice Function for the owner to withdraw accumulated Ether fees
    function withdrawEther() external onlyOwner {
        uint256 etherAmount = ownersEtherAmount;
        ownersEtherAmount = 0;

        if (etherAmount > 0) {
            (bool ok, ) = payable(owner()).call{value: etherAmount}("");
            require(ok, "Trx failed");
            emit EtherWithdrawn(owner(), etherAmount);
        }

        uint256 wethAmount = ownersWethAmount;
        ownersWethAmount = 0;

        if (wethAmount > 0) {
            require(weth.balanceOf(address(this)) >= wethAmount, "Insufficient WETH balance");
            weth.withdraw(wethAmount);
            (bool ok, ) = payable(owner()).call{value: wethAmount}("");
            require(ok, "WETH withdrawal failed");
            emit WethWithdrawn(owner(), wethAmount);
        }
    }

    /// @notice Function for the owner to withdraw accumulated ERC20 fees
    /// @param _token Address of the ERC20 token
    function withdrawERC20(address _token) external onlyOwner {
        uint256 erc20Amount = erc20FeesAmounts[IERC20(_token)];
        erc20FeesAmounts[IERC20(_token)] = 0;

        if (erc20Amount > 0) {
            require(IERC20(_token).balanceOf(address(this)) >= erc20Amount, "Insufficient ERC20 tokens");
            IERC20(_token).transfer(owner(), erc20Amount);
            emit ERC20Withdrawn(owner(), _token, erc20Amount);
        }
    }

    /// @notice Internal function to create a sale
    /// @param _token Address of the NFT token (ERC721 or ERC1155)
    /// @param _tokenId ID of the NFT
    /// @param _erc20Token Address of the ERC20 token used for payment
    /// @param _price Sale price of the NFT
    /// @param _isERC721 True if the NFT is an ERC721 token, false if it's ERC1155
    function _createSale(
        address _token,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _price,
        bool _isERC721
    ) internal {
        require(_token != address(0), "invalid token address");
        require(_erc20Token != address(0), "invalid token address");
        require(_price > 0, "price == 0");

        sales[msg.sender][_tokenId] = Sale(_token, _tokenId, _erc20Token, _price, _isERC721);
        emit SaleCreated(msg.sender, _token, _tokenId, _price, _isERC721);
    }

    /// @notice Prevents ERC1155 tokens from being transferred directly to the marketplace contract
    /// @dev This function reverts any attempt to transfer ERC1155 tokens to the contract.
    function onERC1155Received(
        address ,
        address ,
        uint256 ,
        uint256 ,
        bytes calldata 
    ) external pure returns (bytes4) {
        revert("no need to transfer the asset to the marketplace contract");
    }

    /// @notice Prevents batch ERC1155 tokens from being transferred directly to the marketplace contract
    /// @dev This function reverts any attempt to transfer a batch of ERC1155 tokens to the contract.
    function onERC1155BatchReceived(
        address ,
        address ,
        uint256[] calldata ,
        uint256[] calldata ,
        bytes calldata 
    ) external pure returns (bytes4) {
        revert("no need to transfer the asset to the marketplace contract");
    }

    /// @notice Prevents ERC721 tokens from being transferred directly to the marketplace contract
    /// @dev This function reverts any attempt to transfer ERC721 tokens to the contract.
    function onERC721Received(
        address ,
        address ,
        uint256 ,
        bytes calldata 
    ) external pure returns (bytes4) {
        revert("no need to transfer the asset to the marketplace contract");
    }

}