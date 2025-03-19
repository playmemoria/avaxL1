// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ALBERT_MEMORY_SPORES is ERC721, ERC721Enumerable, Ownable {
    bool public mintEnabled;
    bool internal _locked;
    bool internal _revealed;
    string private baseURI;
    uint256 public maxSupply;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        _revealed = false;
        mintEnabled = true;
        _locked = true;
        maxSupply = maxSupply_;
    }

    event Revealed();

    modifier IsMintAllowed() {
        require(mintEnabled, "MINTING DISABLED");
        _;
    }

    modifier IsTransferAllowed() {
        require(!_locked || tx.origin == owner(), "TRANSFERS LOCKED");
        _;
    }

    function reveal() external onlyOwner {
        _revealed = true;
        emit Revealed();
    }

    function disableMint() external onlyOwner {
        mintEnabled = false;
    }

    function locked() external view returns (bool) {
        return _locked;
    }

    function setLock(bool lock_) external onlyOwner {
        _locked = lock_;
    }

    function burn(uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId));
        _burn(tokenId);
    }

    function mintBatch() public onlyOwner IsMintAllowed {
        uint256 remaining = maxSupply - totalSupply();
        require(remaining > 0, "Nothing left to mint");

        uint256 batchSize = remaining >= 100 ? 100 : remaining;

        for (uint256 i = 0; i < batchSize; i++) {
            _safeMint(owner(), totalSupply());
        }
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function tokenURI(uint256 tokenId_)
        public
        view
        override
        returns (string memory)
    {
        if (!_revealed) {
            return
                "https://magenta-advanced-reptile-409.mypinata.cloud/ipfs/bafkreidzbs65tnedclqkk4fp3nugllftflc2elvzpsljzwge6yol665waa";
        }
        return
            string(
                abi.encodePacked(baseURI, Strings.toString(tokenId_), ".json")
            );
    }

    function approve(address to, uint256 tokenId)
        public
        override(ERC721, IERC721)
        IsTransferAllowed
    {
        super.approve(to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721, IERC721)
        IsTransferAllowed
    {
        super.setApprovalForAll(operator, approved);
    }

    // The following functions are overrides required by Solidity.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Enumerable)
        IsTransferAllowed
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
