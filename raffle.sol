// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;
//Javier Verde Marin

library SafeArray {
    
    function contains(address[] storage arr, address elem) external view returns (bool) {
      for (uint i = 0; i < arr.length; i++){
        if (arr[i] == elem) return true;
        }
       return false;
    }
    
}

library Random {
    function getRandNumer(uint256 range) public view returns(uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp)));
        uint256 scaling = (uint256(0) - uint256(1))/range;
        uint256 scaled = seed / scaling;
        return scaled;
    }
}

contract Raffle {
    
    //Person who starts the raffle, etc
    address private administrator;
    
    //Cost of participating in the raffle (in wei)
    uint256 private participationCost;
    
    //Mapping of users and their respective numbers
    address[] private participants;
    
    //People will only participate in the raffle if it is open
    bool private raffleOpen = false;
    
    //People cannot be added if the raffle is going on (it is going to act as a lock)
    bool private raffleActive = false;
    
    //Check if the user executing the function is the admin
    modifier onlyAdministrator() {
     require(msg.sender == administrator, "You are not the admin");
      _;
    }
    
     //Check that the user executing the function is not the admin
    modifier onlyParticipant() {
     require(msg.sender != administrator, "The admin cannot participate in the raffle");
      _;
    }
    
    //Check that someone is participating
    modifier notEmpty(){
        require(participants.length > 0, "There is no participant");
      _;
    }
    
    //Check if the raffle is open
    modifier isRaffleOpen(){
     require(raffleOpen, "Raffle has not started yet!");
     _;
    }
    
    //Check if the new participant isn't already in the raffle
    modifier newParticipant(){
        require(!SafeArray.contains(participants, msg.sender), "You are already participating");
        _;
    }
    
    //Check that you are inserting the correct price of entering the raffle
    modifier correctPrice(){
        require(msg.value == participationCost, "You did not pay the correct price");
        _;
    }
    
    
    
    //The person who deploys the contract will be the administrator
    constructor(uint256 _cost) {
      participationCost = _cost;
      administrator = msg.sender;
    }
    
    //Only the admin can start the raffle
    function StartRaffle() external onlyAdministrator {
        require(!raffleOpen, "Raffle is already open.");
        raffleOpen = true;
    }
    
    //People can only participate if the raffle is open, the participant isn't already in and the raffle is not going on
    function Participate() external payable onlyParticipant isRaffleOpen newParticipant correctPrice{
        require(!raffleActive, "You cannot join while the raffle is already going on!");
        participants.push(msg.sender);
    }
    
    
    //Winner gets chosen "Randomly", only the admin can execute it and at least someone has to participate. The winning number will be returned.
    function GetWinner() external onlyAdministrator isRaffleOpen notEmpty returns (uint256){
        raffleActive = true;
        uint256 winner = Random.getRandNumer(participants.length - 1);
        payable(participants[winner]).transfer(address(this).balance);
        delete participants;
        raffleActive = false;
        raffleOpen = false;
        return winner;
    }
    
}
