// SPDX-License-Identifier:MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//When we mint an NFT, we will trigger a chainlink vrf call to get a random number
//using that number , we will get a random nft
//pug, shiba, inu, st. bernard
//pug is super rare
//shiba is kinda of rare
//st. bernard is common

//users have to pay to mint and nft
// the owner of the contract can withdraw the ETH

error RandomIpfsNft_RangeOutOfBonds();
error RandomIpfsNft_NeedMoreETHSent();
error RandomIpfsNft_TransferFail();
error RandomIpfsNft__AlreadyInitialized();

contract RandomIpfsNft is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
    //Type declaration
    enum Breed {
        PUG,
        SHIBA_INU,
        ST_BERNARD
    }

    //VRF constansts
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subcriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //VRF HELPERS
    mapping(uint256 => address) public s_requestToSender;

    //NFT VARIABLES
    uint256 public s_tokenCounter;
    uint256 internal constant MAX_CHANCE_VALUE = 100;
    string[] internal s_dogTokenUris;
    uint256 internal immutable i_mintFee;
    bool private s_initialized;

    //Events
    event NftRequested(uint256 requestId, address requester);
    event NftMinted(Breed dogBreed, address dogOwner);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 mintFee,
        uint32 callbackGasLimit,
        string[3] memory dogTokenUris
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Random IPFS Nft", "RIN") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subcriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        s_dogTokenUris = dogTokenUris;
        i_mintFee = mintFee;
        s_tokenCounter = 0;
    }

    // users have to pay to request for the nft
    // the owner of the contract can withdraw ETH

    function requestNft() public payable returns (uint256 requestId) {
        if (msg.value < i_mintFee) {
            revert RandomIpfsNft_NeedMoreETHSent();
        }
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subcriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_requestToSender[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    //we cant mint by msg.sender here as this fullfillrandomwords function is called by the chainlink node so taht is the sendner here
    //so we create a mapping betweeb requestID and whoever called the resquest nft functrion
    //such that when fulfilllrandom words is called then we can map the owner

    //_setTokenUri is not gas efficient but we use it for customization

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        address dogOwner = s_requestToSender[requestId];
        uint256 newTokenId = s_tokenCounter;
        uint256 moddedRng = randomWords[0] % MAX_CHANCE_VALUE;

        //THIS moddedRng will be in range 0 -99
        // 0 - 9 PUG
        //10 - 29 shiba
        //30 - 99 st. bernard
        Breed dogBreed = getBreedFromModdedRng(moddedRng);
        s_tokenCounter += 1;
        _safeMint(dogOwner, newTokenId);
        _setTokenURI(newTokenId, s_dogTokenUris[uint256(dogBreed)]);
        emit NftMinted(dogBreed, dogOwner);
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert RandomIpfsNft_TransferFail();
        }
    }

    function getBreedFromModdedRng(
        uint256 moddedRng
    ) public pure returns (Breed) {
        uint256 cumulativeSum = 0;
        uint256[3] memory chanceArray = getChanceArray();
        for (uint256 i = 0; i < chanceArray.length; i++) {
            if (
                moddedRng >= cumulativeSum &&
                moddedRng < cumulativeSum + chanceArray[i]
            ) {
                return Breed(i);
            }
            cumulativeSum += chanceArray[i];
        }
        revert RandomIpfsNft_RangeOutOfBonds();
    }

    function getChanceArray() public pure returns (uint256[3] memory) {
        return [10, 30, MAX_CHANCE_VALUE];
        //array of chances 10%, 30%, 60%
    }

    function _initializeContract(string[3] memory dogTokenUris) private {
        if (s_initialized) {
            revert RandomIpfsNft__AlreadyInitialized();
        }
        s_dogTokenUris = dogTokenUris;
        s_initialized = true;
    }

    function getMintFee() public view returns (uint256) {
        return i_mintFee;
    }

    function getDogTokenUris(
        uint256 index
    ) public view returns (string memory) {
        return s_dogTokenUris[index];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function getInitialized() public view returns (bool) {
        return s_initialized;
    }
}
