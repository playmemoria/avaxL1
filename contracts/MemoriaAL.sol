// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721ABurnable.sol";
// import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "./ERC721AQueryable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ERC721Royalty is ERC2981, ERC721A {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721A, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

interface IERC4906A is IERC165, IERC721A {
    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    function supportsInterface(
        bytes4 interfaceId
    ) external view override(IERC165, IERC721A) returns (bool);
}

contract MemoriaAL is
    ERC721A,
    IERC4906A,
    ERC721ABurnable,
    ERC721AQueryable,
    ERC721Royalty,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    string private _name;
    string private _symbol;
    string private baseURI;

    address public mintPriceReceiver;
    bytes32 public mintMerkleRoot;
    uint256 public mintPrice;
    uint256 public minLockPeriod;
    bool public tokenLockEnabled;
    uint8 public mintCap;
    uint16 public maxSupply;

    mapping(address owner => uint8 quantity) public minted;
    mapping(uint256 tokenId => uint256 startTime) public tokenLockedSince;

    event Received(address, uint256);

    event Staked(address indexed user, uint256[] tokenIds, uint256 stakeTime);
    event Unstaked(address indexed user, uint256[] tokenIds);

    error InvalidMerkleProof();
    error MintMaxCap(uint8 minted, uint8 mintCap);
    error InsufficientETHReceived(uint256 received, uint256 required);
    error InsufficientETHBalance(uint256 balance, uint256 required);
    error InvalidMintPrice();
    error InvalidAmount();
    error ExceededMaxSupply(uint256 totalMinted, uint16 maxSupply);
    error TokenLocked(uint256 tokenId, uint256 expiry);
    error NotOwnerNorApproved(address caller);
    error TokenLockDisabled();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address _mintPriceReceiver,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFeeNumerator,
        uint16 _maxSupply,
        uint8 _mintCap,
        uint16 reserveAmount,
        uint256 _minLockPeriod
    ) ERC721A("", "") Ownable(_msgSender()) {
        _name = name_;
        _symbol = symbol_;
        baseURI = baseURI_;
        mintPriceReceiver = _mintPriceReceiver;
        _setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFeeNumerator);
        maxSupply = _maxSupply;
        mintCap = _mintCap;
        _mintERC2309(_msgSender(), reserveAmount);
        minLockPeriod = _minLockPeriod;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function name()
        public
        view
        virtual
        override(ERC721A, IERC721A)
        returns (string memory)
    {
        return _name;
    }

    function symbol()
        public
        view
        virtual
        override(ERC721A, IERC721A)
        returns (string memory)
    {
        return _symbol;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setName(string memory name_) external onlyOwner {
        _name = name_;
    }

    function setSymbol(string memory symbol_) external onlyOwner {
        _symbol = symbol_;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
        emit BatchMetadataUpdate(_startTokenId(), _sequentialUpTo());
    }

    function setMintPriceReceiver(
        address _mintPriceReceiver
    ) external onlyOwner {
        mintPriceReceiver = _mintPriceReceiver;
    }

    function setRoyaltyInfo(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    function setMaxSupply(uint16 _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }

    function setMintCap(uint8 _mintCap) external onlyOwner {
        mintCap = _mintCap;
    }

    function setMintConfig(
        bytes32 merkleRoot,
        uint256 _mintPrice
    ) external onlyOwner {
        mintMerkleRoot = merkleRoot;
        mintPrice = _mintPrice;
    }

    function setTokenLockEnabled(bool _tokenLockEnabled) external onlyOwner {
        tokenLockEnabled = _tokenLockEnabled;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // owner mint
    function mint(address to, uint8 quantity) external onlyOwner {
        _safeMint(to, quantity);
    }

    // merkleProof mint
    function mint(
        bytes32[] calldata mintMerkleProof,
        uint8 quantity
    ) external payable nonReentrant {
        if (mintPrice == 0) {
            revert InvalidMintPrice();
        }

        if (mintMerkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(
                bytes.concat(keccak256(abi.encode(_msgSender())))
            );
            if (!MerkleProof.verify(mintMerkleProof, mintMerkleRoot, leaf)) {
                revert InvalidMerkleProof();
            }
        }

        if (minted[_msgSender()] + quantity > mintCap) {
            revert MintMaxCap(minted[_msgSender()], mintCap);
        }

        if (_totalMinted() + quantity > maxSupply) {
            revert ExceededMaxSupply(_totalMinted(), maxSupply);
        }

        minted[_msgSender()] += quantity;

        _transferInETH(quantity * mintPrice);
        _transferOutETH(mintPriceReceiver, quantity * mintPrice);

        _safeMint(_msgSender(), quantity);
    }

    function lock(uint256[] calldata tokenIds) external {
        if (!tokenLockEnabled) {
            revert TokenLockDisabled();
        }

        for (uint256 i; i < tokenIds.length; i++) {
            if (_msgSender() != ownerOf(tokenIds[i]))
                if (!isApprovedForAll(ownerOf(tokenIds[i]), _msgSender()))
                    revert NotOwnerNorApproved(_msgSender());

            if (
                tokenLockedSince[tokenIds[i]] + minLockPeriod > block.timestamp
            ) {
                revert TokenLocked(tokenIds[i], tokenLockedSince[tokenIds[i]]);
            }

            tokenLockedSince[tokenIds[i]] = block.timestamp;
        }
        emit Staked(_msgSender(), tokenIds, block.timestamp);
    }

    function unlock(uint256[] calldata tokenIds) external {
        for (uint256 i; i < tokenIds.length; i++) {
            if (_msgSender() != ownerOf(tokenIds[i]))
                if (!isApprovedForAll(ownerOf(tokenIds[i]), _msgSender()))
                    revert NotOwnerNorApproved(_msgSender());

            if (
                tokenLockedSince[tokenIds[i]] + minLockPeriod > block.timestamp
            ) {
                revert TokenLocked(tokenIds[i], tokenLockedSince[tokenIds[i]]);
            }

            delete tokenLockedSince[tokenIds[i]];
        }
        emit Unstaked(_msgSender(), tokenIds);
    }

    function tokensOfOwnerLockedIn(
        address owner,
        uint256 start,
        uint256 stop
    )
        public
        view
        returns (
            uint256[] memory lockedTokenIds,
            uint256[] memory tokensLockedSince,
            bool[] memory unlockable
        )
    {
        uint256[] memory tokenIds;
        if (start != stop) {
            tokenIds = tokensOfOwnerIn(owner, start, stop);
        }

        lockedTokenIds = new uint256[](tokenIds.length);
        tokensLockedSince = new uint256[](tokenIds.length);
        unlockable = new bool[](tokenIds.length);
        uint256 lockedCount;

        for (uint256 i; i < tokenIds.length; i++) {
            if (tokenLockedSince[tokenIds[i]] != 0) {
                lockedTokenIds[lockedCount] = tokenIds[i];
                tokensLockedSince[lockedCount] = tokenLockedSince[tokenIds[i]];
                unlockable[lockedCount] =
                    tokenLockedSince[tokenIds[i]] + minLockPeriod <=
                    block.timestamp;
                lockedCount++;
            }
        }
        // Store the length of the array.
        assembly {
            mstore(lockedTokenIds, lockedCount)
            mstore(tokensLockedSince, lockedCount)
            mstore(unlockable, lockedCount)
        }
    }

    function tokensOfOwnerLocked(
        address owner
    )
        external
        view
        returns (
            uint256[] memory lockedTokenIds,
            uint256[] memory tokensLockedSince,
            bool[] memory unlockable
        )
    {
        if (_sequentialUpTo() != type(uint256).max) {
            _revert(NotCompatibleWithSpotMints.selector);
        }

        uint256 start = _startTokenId();
        uint256 stop = _nextTokenId();

        (lockedTokenIds, tokensLockedSince, unlockable) = tokensOfOwnerLockedIn(
            owner,
            start,
            stop
        );
    }

    // lock check
    function _beforeTokenTransfers(
        address from,
        address,
        uint256 tokenId,
        uint256 quantity
    ) internal view override whenNotPaused {
        // not mint
        if (from != address(0) && quantity == 1) {
            if (tokenLockedSince[tokenId] != 0) {
                revert TokenLocked(tokenId, tokenLockedSince[tokenId]);
            }
        }
    }

    function recover(
        uint256 amount,
        address recipient
    ) external payable onlyOwner {
        Address.sendValue(payable(recipient), amount);
    }

    function recover(
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(recipient, amount);
    }

    receive() external payable {
        emit Received(_msgSender(), msg.value);
    }

    function _transferInETH(uint256 amount) internal {
        if (msg.value < amount) {
            revert InsufficientETHReceived(msg.value, amount);
        }
    }

    function _transferOutETH(address receiver, uint256 amount) internal {
        if (amount == 0) {
            revert InvalidAmount();
        }

        if (address(this).balance < amount) {
            revert InsufficientETHBalance(address(this).balance, amount);
        }

        Address.sendValue(payable(receiver), amount);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721A, IERC4906A, IERC721A, ERC721Royalty)
        returns (bool)
    {
        return
            interfaceId == bytes4(0x49064906) ||
            super.supportsInterface(interfaceId);
    }
}
