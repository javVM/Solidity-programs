// SPDX-License-Identifier: GPL-3.0
//Javier Verde Marin
pragma solidity >=0.7.0 <0.8.0;
contract PiggyMapping2 {
    struct clientData {
        string name;
        uint value;
    }
    
    mapping(address=>clientData) clients;
    address[] adrr;
    
    function findClient() internal view returns (bool) {
        if(bytes(clients[msg.sender].name).length > 0) return true;
        else return false;
    }
    
    function addClient(string memory name) external payable {
        require(bytes(name).length != 0, "The name is empty");
        if(findClient()){
            revert();
        }
        else{
            clients[msg.sender] = clientData(name, msg.value);
            adrr.push(msg.sender);
        }
      
    }
    
    function deposit()external payable {
        if(!findClient()){
            revert();
        }
        else{
            clients[msg.sender].value = clients[msg.sender].value + msg.value;
        }
    }
    
    function withdraw(uint amountInWei)external{
         if(!findClient()){
            revert();
        }
        else{
            require(clients[msg.sender].value >= amountInWei, "No hay suficientes Wei");
            clients[msg.sender].value = clients[msg.sender].value - amountInWei;
            msg.sender.transfer(amountInWei);
        }
    }
    
    function getBalance()external view returns (uint){
         if(!findClient()){
            revert();
        }
        else{
            return clients[msg.sender].value;
        }
    }
    
    function checkBalances()external view returns (bool) {
        uint value = 0;
        for(uint i = 0; i < adrr.length; i++) {
            value = value + clients[adrr[i]].value;
        }
        
        if(value == address(this).balance) return true;
        else return false;
    
    }
}
