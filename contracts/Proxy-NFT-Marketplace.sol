// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract NFTMarketplaceProxy is TransparentUpgradeableProxy {
    /**
     * @dev The constructor of the proxy contract
     * @param _logic The address of the initial logic (implementation) contract
     * @param admin_ The address of the admin (ProxyAdmin contract or account)
     * @param _data Any initialization data, if needed
     */
    constructor(
        address _logic,          // Address of the logic (implementation) contract
        address admin_,          // Admin (can be a ProxyAdmin or another address)
        bytes memory _data       // Optional data to initialize the logic contract
    ) TransparentUpgradeableProxy(_logic, admin_, _data) {
        // Proxy initialization happens here.
        // `TransparentUpgradeableProxy` constructor does the actual proxy setup.
    }
}


/**
 * @title MarketplaceAdmin
 * @dev This contract is used to manage and upgrade the proxy for the NFT Marketplace.
 * It inherits from OpenZeppelin's ProxyAdmin, which allows for controlling the proxy's logic contract.
 */
contract MarketplaceAdmin is ProxyAdmin {

    /**
     * @dev Constructor that sets the deployer as the admin of the ProxyAdmin.
     * ProxyAdmin inherits the ownership functionality, so only the admin can manage upgrades.
     */
    constructor() ProxyAdmin(msg.sender) {
        // The constructor is inheriting behavior from ProxyAdmin.
        // This will set the deployer (the one who deploys this contract) as the admin.
    }

    /**
     * @dev Function to renounce admin ownership.
     * Only the current owner (admin) can call this function.
     * This will transfer ownership of the ProxyAdmin to the zero address, disabling any further upgrades.
     */
    function renounceAdminOwnership() external onlyOwner {
        renounceOwnership();  // Provided by OpenZeppelin's Ownable.sol
    }

    /**
     * @dev Allows the admin to transfer ownership of the ProxyAdmin.
     * Only the current admin can transfer ownership.
     * @param newAdmin The address of the new admin.
     */
    function transferAdminOwnership(address newAdmin) external onlyOwner {
        transferOwnership(newAdmin);  // Provided by OpenZeppelin's Ownable.sol
    }
}

