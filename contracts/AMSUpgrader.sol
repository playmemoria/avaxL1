// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Nonces.sol";

contract AMSUpgrader is AccessControl, Nonces, EIP712, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bool public enabled;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    bytes32 private constant UPGRADE_TYPEHASH =
        keccak256(
            "Upgrade(address signerAddress,address senderAddress,address nftUpgradeAddress,uint256 nftUpgradeTokenId,address nftBurnAddress,address nftBurnRecipient,uint256 nftBurnTokenId,address tokenBurnAddress,address tokenBurnRecipient,uint256 tokenBurnAmount,uint256 deadline,uint256 nonce)"
        );

    mapping(address nftAddress => mapping(uint256 tokenId => uint256 level))
        public nftLevels;

    error ContractDisabled();
    error InvalidSignature();
    error ExpiredSignature(uint256 deadline);

    event NftUpgrade(address nftAddress, uint256 tokenId, uint256 newLevel);

    constructor() EIP712("AMSUpgrader", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setEnabled(bool _enabled) external onlyRole(OPERATOR_ROLE) {
        enabled = _enabled;
    }

    function upgrade(
        address signerAddress,
        address nftUpgradeAddress,
        uint256 nftUpgradeTokenId,
        address nftBurnAddress,
        address nftBurnRecipient,
        uint256 nftBurnTokenId,
        address tokenBurnAddress,
        address tokenBurnRecipient,
        uint256 tokenBurnAmount,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant {
        if (!enabled) {
            revert ContractDisabled();
        }

        bytes32 structHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    UPGRADE_TYPEHASH,
                    signerAddress,
                    _msgSender(),
                    nftUpgradeAddress,
                    nftUpgradeTokenId,
                    nftBurnAddress,
                    nftBurnRecipient,
                    nftBurnTokenId,
                    tokenBurnAddress,
                    tokenBurnRecipient,
                    tokenBurnAmount,
                    deadline,
                    _useNonce(signerAddress, _msgSender())
                )
            )
        );

        if (
            !SignatureChecker.isValidSignatureNow(
                signerAddress,
                structHash,
                signature
            )
        ) {
            revert InvalidSignature();
        }

        if (!hasRole(OPERATOR_ROLE, signerAddress)) {
            revert AccessControlUnauthorizedAccount(
                signerAddress,
                OPERATOR_ROLE
            );
        }

        if (block.timestamp > deadline) {
            revert ExpiredSignature(deadline);
        }

        IERC721(nftBurnAddress).transferFrom(
            _msgSender(),
            nftBurnRecipient,
            nftBurnTokenId
        );

        IERC20(tokenBurnAddress).safeTransferFrom(
            _msgSender(),
            tokenBurnRecipient,
            tokenBurnAmount
        );

        emit NftUpgrade(
            nftUpgradeAddress,
            nftUpgradeTokenId,
            ++nftLevels[nftUpgradeAddress][nftUpgradeTokenId]
        );
    }
}
