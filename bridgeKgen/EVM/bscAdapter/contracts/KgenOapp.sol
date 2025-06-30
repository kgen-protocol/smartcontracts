//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/* ─────────── OpenZeppelin ─────────── */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
/* ─────────── LayerZero ─────────── */
import {OAppUpgradeable} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {OAppOptionsType3Upgradeable} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {OApp, MessagingFee, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {KgenStorage} from "./proxy/storage/kgenStorage.sol";
import "hardhat/console.sol";

contract KgenOApp is
    OAppUpgradeable,
    OAppOptionsType3Upgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    KgenStorage
{
    using SafeERC20 for IERC20;

    /* ─────────── Events ─────────── */
    event BridgeInitiated(bytes payload);
    event BridgeSuccessful(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /* ─────────── Constructor ─────────── */
    constructor(address _endpoint) OAppUpgradeable(_endpoint) {}

    function Initialize() public initializer {
        __OApp_init(msg.sender);
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /* ─────────── Admin ─────────── */
    function setApprovedToken(address _token, bool _status) external onlyOwner {
        approvedToken[_token] = _status;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawErc20(
        address token,
        address receiver,
        uint256 amount
    ) external onlyOwner {
        // it should be whitelisted address only
        IERC20(token).safeTransfer(receiver, amount);
    }


    /* ─────────── Outbound ─────────── */
    function send(
        uint32 _dstEid,
        string memory _message,
        bytes calldata _options,
        address token
    )
        external
        payable
        onlyOwner
        whenNotPaused
        nonReentrant
        returns (MessagingReceipt memory receipt)
    {

        require(token != address(0), "BRIDGE: ZERO_TOKEN_ADDRESS");
        require(approvedToken[token], "BRIDGE: TOKEN_NOT_ALLOWED");
        bytes memory payload = abi.encode(_message);
        (bytes32 aptosAddrBytes32, bytes32 toAddrBytes32, uint256 amount) = decodePackedHexString(_message);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        require(amount > 0, "BRIDGE: INVALID_AMOUNT");
        receipt = _lzSend(_dstEid, payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
        emit BridgeInitiated(payload);
    }

    /* ─────────── Inbound ─────────── */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address, // _executor
        bytes calldata // _extraData
    ) internal override whenNotPaused nonReentrant {
        require(!processed[_guid], "BRIDGE: DUPLICATE_PACKET");
        processed[_guid] = true;

        (address token, address to, uint256 amount) = abi.decode(
            _message,
            (address, address, uint256)
        );

        require(approvedToken[token], "BRIDGE: TOKEN_NOT_ALLOWED");
        require(to != address(0), "BRIDGE: INVALID_RECIPIENT");
        require(amount > 0, "BRIDGE: INVALID_AMOUNT");

        IERC20(token).safeTransfer(to, amount);
        emit BridgeSuccessful(token, to, amount);
    }

    /* ─────────── Utility ─────────── */
    function quote(
        uint32 _dstEid,
        string memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(_message);
        fee = _quote(_dstEid, payload, _options, _payInLzToken);
    }
      function decodePackedHexString(string memory hexString)
        internal
        pure
        returns (bytes32 aptosAddress, bytes32 toAddress, uint256 amount)
    {
        bytes memory raw = hexStringToBytes(hexString);
        require(raw.length == 96, "Invalid packed payload length");

        assembly {
            aptosAddress := mload(add(raw, 32))
            toAddress := mload(add(raw, 64))
            amount := mload(add(raw, 96))
        }
    }

    function hexStringToBytes(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length >= 2 && ss[0] == "0" && (ss[1] == "x" || ss[1] == "X"), "Must start with 0x");
        require((ss.length - 2) % 2 == 0, "Hex string length must be even");

        uint len = (ss.length - 2) / 2;
        bytes memory result = new bytes(len);

        for (uint i = 0; i < len; ++i) {
            result[i] = bytes1(
                (fromHexChar(uint8(ss[2 + i * 2])) << 4) |
                 fromHexChar(uint8(ss[3 + i * 2]))
            );
        }

        return result;
    }

    function fromHexChar(uint8 c) internal pure returns (uint8) {
        if (c >= 48 && c <= 57) return c - 48;        // '0'–'9'
        if (c >= 97 && c <= 102) return c - 87;       // 'a'–'f'
        if (c >= 65 && c <= 70) return c - 55;        // 'A'–'F'
        revert("Invalid hex char");
    }
}
