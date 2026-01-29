// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Simple wallet contract controlled by settlement contract
contract ControlledWallet {
    using SafeERC20 for IERC20;
    
    address public controller;
    
    constructor(address _controller) {
        require(_controller != address(0), "Invalid controller");
        controller = _controller;
    }
    
    modifier onlyController() {
        require(msg.sender == controller, "ControlledWallet: Not controller");
        _;
    }
    
    function transfer(IERC20 token, address to, uint256 amount) external onlyController {
        require(to != address(0), "ControlledWallet: Invalid recipient");
        require(amount > 0, "ControlledWallet: Invalid amount");
        
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "ControlledWallet: Insufficient balance");
        
        token.safeTransfer(to, amount);
    }
    
    function approve(IERC20 token, address spender, uint256 amount) external onlyController {
        require(spender != address(0), "ControlledWallet: Invalid spender");
        
        // USDT compatibility: reset approval to 0 first
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance > 0) {
            token.approve(spender, 0);
        }
        
        if (amount > 0) {
            token.approve(spender, amount);
        }
    }
    
    function callContract(address target, bytes calldata data) external onlyController returns (bytes memory) {
        require(target != address(0), "ControlledWallet: Invalid target");
        
        (bool success, bytes memory result) = target.call(data);
        require(success, "ControlledWallet: Call failed");
        
        return result;
    }
    
    function getBalance(IERC20 token) external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}


/// @notice Interface to your B2BRevenue contract
/// @dev Assumes the Revenue contract has a function to pull funds using transferFrom
interface IB2BOrder {
   function depositOrder(
       string memory orderId,
       string memory dpId,
       string memory productId,
       string memory purchaseUtr,
       string memory purchaseDate,
       uint256 quantity,
       uint256 amount
   ) external;
}


contract B2BSettlementV2 is Ownable, ReentrancyGuard, Pausable {
   using SafeERC20 for IERC20;


   /// ================================
   /// EVENTS
   /// ================================
 event PartnerCreated(string indexed dpId, uint256 timestamp , string aliasToMaster);
   event BankCreated(bytes32 indexed bankId, uint256 timestamp);
  
   event SettlementExecuted(
       bytes32 indexed orderId,
       string indexed dpId,
       uint256 amount,
       bytes32 indexed bankId,
       address token,
       uint256 timestamp
   );
  
   event RevenueDeposited(
       address indexed revenueContract,
       address indexed token,
       uint256 amount,
       uint256 timestamp
   );


   event BankWithdrawal(
       bytes32 indexed bankId,
       address recipient,
       uint256 amount,
       address token
   );
  
   event SuperAdminTransferred(address indexed oldAdmin, address indexed newAdmin);
   event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
   event RevenueContractUpdated(address indexed oldContract, address indexed newContract);
   event PartnerStatusChanged(string indexed dpId, bool status);
   event BankStatusChanged(bytes32 indexed bankId, bool status);
   event BankFunded(bytes32 indexed bankId, address indexed token, uint256 amount);


   /// ================================
   /// STRUCTS
   /// ================================
   struct PartnerInfo {
       string dpId;
       address wallet;
       bool exists;
       bool isActive;
   }


   struct BankInfo {
       string bankId; 
       address wallet;
       bool exists;
       bool isActive;
   }


   struct PartnerDetail {
       string dpId;
       address wallet;
       bool isActive;
       string[] aliases;
   }


   struct AssetBalance {
       address asset_metadata;
       uint256 balance;
   }


   struct PartnerReport {
       string dp_id;
       bool is_active;
       address resource_account;
       string[] alias_names;
       AssetBalance[] balances;
   }


   /// ================================
   /// STATE VARIABLES
   /// ================================
   address public superAdmin;      // multisig wallet
   address public admin;           // operator (cron job)
   IB2BOrder public revenueContract;



   // Mappings for data storage
   mapping(string => PartnerInfo) public partners;
   mapping(bytes32 => BankInfo) public banks;
  
   // Alias management - maps alias ID to master partner ID
   mapping(string => string) public aliasToMaster;
  
   // Prevent double-spending of Order IDs
   mapping(bytes32 => bool) public processedOrders;
   string[] private dpIdList;
   string[] private bankIdList;
  
   // Track assets for balance reporting
   address[] public trackedAssets;
   uint256 public maxTrackedAssets = 100;


   /// ================================
   /// MODIFIERS
   /// ================================
   modifier onlyAdmin() {
       require(msg.sender == admin, "NotAdmin");
       _;
   }


   modifier onlySuperAdmin() {
       require(msg.sender == superAdmin, "NotSuperAdmin");
       _;
   }


   /// ================================
   /// CONSTRUCTOR
   /// ================================
   constructor(address _revenueContract, address _superAdmin, address _admin) Ownable(_superAdmin) {
       require(_revenueContract != address(0), "Revenue contract zero");
       require(_superAdmin != address(0), "SuperAdmin zero");
       require(_admin != address(0), "Admin zero");

       revenueContract = IB2BOrder(_revenueContract);
       superAdmin = _superAdmin;
       admin = _admin;

       emit SuperAdminTransferred(address(0), _superAdmin);
       emit AdminUpdated(address(0), _admin);
   }


   /// ================================
   /// ADMIN FUNCTIONS
   /// ================================
   function update_admin(address newAdmin) external onlySuperAdmin {
       require(newAdmin != address(0), "Invalid address");
       emit AdminUpdated(admin, newAdmin);
       admin = newAdmin;
   }


   function update_revenue_contract(address _newRevenue) external onlySuperAdmin {
       require(_newRevenue != address(0), "Invalid address");
       emit RevenueContractUpdated(address(revenueContract), _newRevenue);
       revenueContract = IB2BOrder(_newRevenue);
   }


   function transfer_super_admin(address newSuperAdmin) external onlySuperAdmin {
       require(newSuperAdmin != address(0), "Invalid address");
       emit SuperAdminTransferred(superAdmin, newSuperAdmin);
       superAdmin = newSuperAdmin;
   }




   /// ================================
   /// REGISTRATION
   /// ================================
   function create_partner(string calldata dpId) external onlyAdmin {
       require(!partners[dpId].exists, "Partner already exists");
       require(bytes(aliasToMaster[dpId]).length == 0, "ID already used as alias");
       
       // Create controlled wallet contract
       ControlledWallet wallet = new ControlledWallet(address(this));
       address walletAddress = address(wallet);
       
       // Address collision is extremely unlikely with new contracts, skip check
       
       partners[dpId] = PartnerInfo(dpId, walletAddress, true, true);
       dpIdList.push(dpId);
       emit PartnerCreated(dpId, block.timestamp, "");
   }
  
   function create_partner_alias(string calldata newAliasId, string calldata existingDpId) external onlyAdmin {
       require(bytes(newAliasId).length > 0, "Invalid alias ID");
       require(bytes(existingDpId).length > 0, "Invalid existing DP ID");
       require(partners[existingDpId].exists, "Master partner does not exist");
       require(!partners[newAliasId].exists, "Alias ID already exists as partner");
       require(bytes(aliasToMaster[newAliasId]).length == 0, "Alias already exists");
      
       // Simple circular reference check with depth limit
       string memory currentId = existingDpId;
       uint256 depth = 0;
       
       while (bytes(aliasToMaster[currentId]).length > 0) {
           require(depth < 10, "Alias chain too deep");
           require(keccak256(abi.encodePacked(currentId)) != keccak256(abi.encodePacked(newAliasId)), "Circular alias detected");
           currentId = aliasToMaster[currentId];
           depth++;
       }
      
       aliasToMaster[newAliasId] = existingDpId;
       dpIdList.push(newAliasId);
      
       emit PartnerCreated(newAliasId, block.timestamp, existingDpId);
   }


   function create_bank(string calldata bankId) external onlyAdmin {
       bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
       require(!banks[bankIdHash].exists, "Bank already exists");
       
       // Create controlled wallet contract
       ControlledWallet wallet = new ControlledWallet(address(this));
       address walletAddress = address(wallet);
       
       // Address collision is extremely unlikely with new contracts, skip check
       
       banks[bankIdHash] = BankInfo(bankId, walletAddress, true, true);
       bankIdList.push(bankId);
       emit BankCreated(bankIdHash, block.timestamp);
   }





   function set_partner_status(string calldata dpId, bool status) external onlyAdmin {
       require(partners[dpId].exists, "Partner does not exist");
       partners[dpId].isActive = status;
       emit PartnerStatusChanged(dpId, status);
   }


   function set_bank_status(string calldata bankId, bool status) external onlyAdmin {
       bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
       require(banks[bankIdHash].exists, "Bank does not exist");
       banks[bankIdHash].isActive = status;
       emit BankStatusChanged(bankIdHash, status);
   }


   /// ================================
   /// FUND BANK (DEPOSIT)
   /// ================================
   function fund_bank(string calldata bankId, uint256 amount, IERC20 token)
       external
       nonReentrant
       whenNotPaused
   {
       bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
       BankInfo storage bank = banks[bankIdHash];
       require(bank.exists && bank.isActive, "Bank not found or inactive");
       require(amount > 0, "InvalidAmount");

       // Transfer directly to bank's controlled wallet
       token.safeTransferFrom(msg.sender, bank.wallet, amount);
       
       // Auto-register asset for tracking
       _registerAsset(address(token));

       emit BankFunded(bankIdHash, address(token), amount);
   }


   /// ================================
   /// SETTLEMENT (CORE LOGIC)
   /// ================================
   function execute_single_settlement(
       string calldata orderId,
       string calldata dpId,
       string calldata bankId,
       uint256 amount,
       IERC20 token,
       string calldata productId,
       string calldata purchaseUtr,
       string calldata purchaseDate,
       uint256 quantity
   )
       external
       onlyAdmin
       nonReentrant
       whenNotPaused
   {
       require(amount > 0, "Invalid amount");
       require(bytes(orderId).length > 0, "Invalid order ID");
       require(bytes(productId).length > 0, "Invalid product ID");
       require(bytes(purchaseUtr).length > 0, "Invalid UTR");
       require(quantity > 0, "Invalid quantity");
       require(bytes(bankId).length > 0, "Invalid bank ID");
      
       bytes32 orderIdHash = keccak256(abi.encodePacked(orderId));
       require(!processedOrders[orderIdHash], "Order already processed");
      
       // Resolve partner (check if it's an alias)
       string memory masterDpId = dpId;
       if (!partners[dpId].exists) {
           require(bytes(aliasToMaster[dpId]).length > 0, "Invalid partner");
           masterDpId = aliasToMaster[dpId];
       }
      
       PartnerInfo storage partner = partners[masterDpId];
       require(partner.exists && partner.isActive, "Invalid partner");
      
       // Validate bank
       bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
       BankInfo storage bank = banks[bankIdHash];
       require(bank.exists && bank.isActive, "Invalid bank");
       
       // Check if bank's controlled wallet has sufficient balance
       require(token.balanceOf(bank.wallet) >= amount, "Insufficient bank wallet balance");
      
       // Mark order as processed
       processedOrders[orderIdHash] = true;
      
       // Execute settlement: Bank -> Partner -> Revenue
       
       // Step 1: Bank wallet transfers to partner wallet
       ControlledWallet(bank.wallet).transfer(token, partner.wallet, amount);
       
       // Step 2: Partner wallet approves revenue and calls depositOrder
       ControlledWallet(partner.wallet).approve(token, address(revenueContract), amount);
      
       // Step 3: Settlement contract approves revenue and calls depositOrder (depositOrder should be a method inside ControlledWallet)
       
       bytes memory callData = abi.encodeWithSelector(
           IB2BOrder.depositOrder.selector,
           orderId,
           dpId,
           productId,
           purchaseUtr,
           purchaseDate,
           quantity,
           amount
       );
       
       ControlledWallet(partner.wallet).callContract(address(revenueContract), callData);
      
       emit SettlementExecuted(
           orderIdHash,
           dpId,
           amount,
           bankIdHash,
           address(token),
           block.timestamp
       );
      
       emit RevenueDeposited(address(revenueContract), address(token), amount, block.timestamp);
   }


   /// ================================
   /// BANK WITHDRAWAL
   /// ================================
   /// @notice Withdraw from bank's controlled wallet
   function withdraw_from_bank(
       string calldata bankId,
       IERC20 token,
       uint256 amount,
       address recipient
   )
       external
       onlySuperAdmin
       nonReentrant
       whenNotPaused
   {
       require(recipient != address(0), "Invalid recipient");

       bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
       BankInfo storage bank = banks[bankIdHash];
       require(bank.exists, "Bank not found");

       // Withdraw directly from bank's controlled wallet
       ControlledWallet(bank.wallet).transfer(token, recipient, amount);

       emit BankWithdrawal(bankIdHash, recipient, amount, address(token));
   }


   /// ================================
   /// VIEW FUNCTIONS
   /// ================================


   function is_order_processed(string calldata orderId) external view returns (bool) {
       bytes32 orderIdHash = keccak256(abi.encodePacked(orderId));
       return processedOrders[orderIdHash];
   }

   function get_all_banks() external view returns (BankInfo[] memory) {
       BankInfo[] memory details = new BankInfo[](bankIdList.length);
       for (uint256 i = 0; i < bankIdList.length; i++) {
           string memory bId = bankIdList[i];
           bytes32 bHash = keccak256(abi.encodePacked(bId));
           details[i] = banks[bHash];
       }
       return details;
   }

   function get_bank_detail(string calldata bankId) external view returns (BankInfo memory bankInfo, uint256[] memory balances) {
       bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
       BankInfo storage bank = banks[bankIdHash];
       require(bank.exists, "Bank does not exist");
      
       uint256[] memory assetBalances = new uint256[](trackedAssets.length);
       for (uint256 i = 0; i < trackedAssets.length; i++) {
           assetBalances[i] = IERC20(trackedAssets[i]).balanceOf(bank.wallet);
       }
      
       return (bank, assetBalances);
   }


   function get_all_partners() external view returns (PartnerDetail[] memory) {
       uint256 masterCount = 0;
       // Count master partners only (skip aliases)
       for (uint256 i = 0; i < dpIdList.length; i++) {
           if (partners[dpIdList[i]].exists) {
               masterCount++;
           }
       }
       
       PartnerDetail[] memory details = new PartnerDetail[](masterCount);
       uint256 index = 0;
       
       // Only return master partners with their aliases
       for (uint256 i = 0; i < dpIdList.length; i++) {
           string memory id = dpIdList[i];
           if (partners[id].exists) {
               // Find aliases for this master partner
               string[] memory aliases = new string[](dpIdList.length);
               uint256 aliasCount = 0;
               
               for (uint256 j = 0; j < dpIdList.length; j++) {
                   string memory aliasId = dpIdList[j];
                   if (bytes(aliasToMaster[aliasId]).length > 0 && 
                       keccak256(abi.encodePacked(aliasToMaster[aliasId])) == keccak256(abi.encodePacked(id))) {
                       aliases[aliasCount] = aliasId;
                       aliasCount++;
                   }
               }
               
               // Resize aliases array
               string[] memory finalAliases = new string[](aliasCount);
               for (uint256 k = 0; k < aliasCount; k++) {
                   finalAliases[k] = aliases[k];
               }
               
               details[index] = PartnerDetail(
                   id, 
                   partners[id].wallet,
                   partners[id].isActive, 
                   finalAliases
               );
               index++;
           }
       }
       return details;
   }
  
  
   function get_partner_detail(string calldata dpId) external view returns (PartnerReport memory) {
       // Resolve partner (check if it's an alias)
       string memory masterDpId = dpId;
       if (!partners[dpId].exists) {
           require(bytes(aliasToMaster[dpId]).length > 0, "Invalid partner");
           masterDpId = aliasToMaster[dpId];
       }
      
       PartnerInfo storage partner = partners[masterDpId];
       require(partner.exists, "Partner does not exist");
      
       // Find aliases for this master partner
       string[] memory aliases = new string[](dpIdList.length);
       uint256 aliasCount = 0;
       
       for (uint256 j = 0; j < dpIdList.length; j++) {
           string memory aliasId = dpIdList[j];
           if (bytes(aliasToMaster[aliasId]).length > 0 && 
               keccak256(abi.encodePacked(aliasToMaster[aliasId])) == keccak256(abi.encodePacked(masterDpId))) {
               aliases[aliasCount] = aliasId;
               aliasCount++;
           }
       }
       
       // Resize aliases array
       string[] memory finalAliases = new string[](aliasCount);
       for (uint256 k = 0; k < aliasCount; k++) {
           finalAliases[k] = aliases[k];
       }
      
       // Get actual token balances from partner's wallet
       AssetBalance[] memory assetBalances = new AssetBalance[](trackedAssets.length);
       for (uint256 i = 0; i < trackedAssets.length; i++) {
           assetBalances[i] = AssetBalance({
               asset_metadata: trackedAssets[i],
               balance: IERC20(trackedAssets[i]).balanceOf(partner.wallet)
           });
       }
      
       return PartnerReport({
           dp_id: dpId,
           is_active: partner.isActive,
           resource_account: partner.wallet,
           alias_names: finalAliases,
           balances: assetBalances
       });
   }

    function get_registry_info() external view returns (address, address, address) {
       return (superAdmin, admin, address(revenueContract));
   }
  
   function get_tracked_assets() external view returns (address[] memory) {
       return trackedAssets;
   }
  
  
   /// ================================
   /// EMERGENCY FUNCTIONS
   /// ================================
   function pause() external onlySuperAdmin {
       _pause();
   }

   function unpause() external onlySuperAdmin {
       _unpause();
   }

   function emergencyWithdraw(IERC20 token, address recipient) external onlySuperAdmin {
       require(recipient != address(0), "Invalid recipient");
       uint256 balance = token.balanceOf(address(this));
       require(balance > 0, "No balance to withdraw");
       token.safeTransfer(recipient, balance);
   }

   /// ================================
   /// INTERNAL FUNCTIONS
   /// ================================
   function _registerAsset(address asset) internal {
       require(asset != address(0), "Invalid asset address");
       require(trackedAssets.length < maxTrackedAssets, "Too many tracked assets");
      
       // Check if asset is already tracked
       for (uint256 i = 0; i < trackedAssets.length; i++) {
           if (trackedAssets[i] == asset) {
               return; // Already tracked
           }
       }
      
       trackedAssets.push(asset);
   }
  
   function set_max_tracked_assets(uint256 newLimit) external onlySuperAdmin {
       require(newLimit >= trackedAssets.length, "Limit below current count");
       require(newLimit <= 1000, "Limit too high");
       maxTrackedAssets = newLimit;
   }

   function remove_tracked_asset(address asset) external onlySuperAdmin {
       for (uint256 i = 0; i < trackedAssets.length; i++) {
           if (trackedAssets[i] == asset) {
               trackedAssets[i] = trackedAssets[trackedAssets.length - 1];
               trackedAssets.pop();
               break;
           }
       }
   }
}

