// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

        function WETH() external pure returns (address);
}

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";


contract NFT1 is ERC721Enumerable, Ownable, IERC2981 { 
  using Strings for uint256;

  string baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 80 ether;
  uint256 public maxSupply = 10000;
  uint256 public maxMintAmount = 10;
  bool public paused = false;
  IERC20 public MMToken = IERC20(0x6Ca26833b23b9BdbCBd64Be9d708bA768FBe69Cb);
  uint8 public ROYALTY_PERCENT = 5;
  address public uniswapV2Router = 0x8954AfA98594b838bda56FE4C12a09D7739D179b;
  IERC721Enumerable public MMLogo = IERC721Enumerable(0x7FeadA4c25b0149b9BAD68c682400938907AA4BF);

  mapping(bytes32 => address) requestToSender;
  address[] public minters;
  bool public presale = true;
  mapping(address => bool) whitelist;
  uint256 minBalance = 10 * 10**18;

  /**
  * Use an interval in seconds and a timestamp to slow execution of Upkeep
  */
  uint256 public interval = 3600;
  uint256 public lastTimeStamp = 100;


  function checkUpkeep(bytes calldata /* checkData */) external view returns (bool upkeepNeeded, bytes memory /* performData */) {
    if (address(this).balance < minBalance) { //MMToken.balanceOf(address(this))
      upkeepNeeded = false;
    }
    else {
      upkeepNeeded = ((block.timestamp - lastTimeStamp) > interval);
    }
    // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
  }

  function performUpkeep(bytes calldata /* performData */) external {
    //We highly recommend revalidating the upkeep in the performUpkeep function
    require((block.timestamp - lastTimeStamp) > interval && address(this).balance > minBalance);
    lastTimeStamp = block.timestamp;
    distribute();
      // We don't use the performData in this example. The performData is generated by the Keeper's call to your checkUpkeep function
  }
    
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI
  )
  ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
  }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public
  function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address, uint256) {
    return(address(this), (salePrice * ROYALTY_PERCENT) / 100);
  }

  function distribute() internal {
    IUniswapV2Router Uniswap = IUniswapV2Router(uniswapV2Router);
    address[] memory path = new address[](2); 
    path[0] = Uniswap.WETH();
    path[1] = address(MMToken);
    uint[] memory amounts = Uniswap.swapExactETHForTokens{value: address(this).balance}(0, path, address(this), block.timestamp + 60);
  
    uint256 supply = MMLogo.totalSupply();
    MMToken.transfer(owner(), (MMToken.balanceOf(address(this))/2));
    uint256 rewardPerToken = MMToken.balanceOf(address(this))/supply;
    for (uint8 i = 1; i <= supply; i++) {
      address holder = MMLogo.ownerOf(i);
      MMToken.transfer(holder, rewardPerToken);
    }
  }

  function mint(uint256 _mintAmount) public payable {
    if(presale){
      require(whitelist[msg.sender]);
    }
    uint256 supply = totalSupply();
    require(!paused);
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);

    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }
    else {
    (bool os, ) = payable(owner()).call{value: cost * _mintAmount}("");
    require(os);
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
      minters.push(msg.sender);
    }
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  //only owner
  function publicSaleOn() external onlyOwner{
    presale = false;
  }

  function addMultiWhitelist(address[] memory _addresses) external onlyOwner{
  for(uint8 i = 0; i < _addresses.length; i++){
        whitelist[_addresses[i]] = true;
    }
  }
  function removeMultiWhitelist(address[] memory _addresses) external onlyOwner{
  for(uint8 i = 0; i < _addresses.length; i++){
      whitelist[_addresses[i]] = false;
    }
  }

  function airdrop(address[] memory _addresses) external onlyOwner{
    uint256 supply = totalSupply();
    for(uint8 i = 0; i < _addresses.length; i++) {
        _safeMint(_addresses[i], supply + i + 1);
    }
  }
  
  function setCost(uint256 _newCost) public onlyOwner {
    cost = _newCost;
  }

  function setRoyalty(uint8 _royalty_percent) public onlyOwner {
    ROYALTY_PERCENT = _royalty_percent;
  }

  function setInterval(uint256 _interval) public onlyOwner {
    interval = _interval; //in seconds
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
 
  function acceptEther() public payable {
        // Some function which accepts ether
  }
}