// SPDX-License-Identifier: GPL-3.0
//Javier Verde Marin
pragma solidity >=0.7.0 <0.8.0;

import "./ERC721simplified.sol";

library ArrayUtils {
    function contains(string[] storage arr, string memory val)
    external view returns (bool) {
        for (uint i = 0; i < arr.length; i++){
        if (sha256(bytes(arr[i])) == sha256(bytes(val))) return true;
        }
        return false;
    }
    
    function increment(uint[] storage arr, uint8 percentage)
    external {
        for (uint i = 0; i < arr.length; i++){
            arr[i] = arr[i]  + (arr[i] * percentage)/100;
        }
    }
    
    function sum(uint[] storage arr)
    external view returns (uint) {
        uint total = 0;
        for (uint i = 0; i < arr.length; i++){
           total = total + arr[i];
        }
        return total;
    }
}

contract MonsterTokens is ERC721simplified{
    
    struct Weapons {
     string[] names; // name of the weapon
     uint[] firePowers; // capacity of the weapon
    }
    struct Character {
     string name; // character name
     Weapons weapons; // weapons assigned to this character
     uint256 tokenId;
     address tokenOwner;
    } 
    
    //numeroinicial
    uint256 constant private ini = 0xFFFF;
   //numeroConsecutivo
    uint256 private acum = 0;

    //Direccion del propietario del contrato
    address private ContractOwner;
   
   //token con sus respectivos datos
    mapping(uint256 => Character) private tokens;
  //usuario con el numero de tokens
    mapping(address => uint256)  private propietarios;
  //approvals
  mapping (uint256 => address) private _tokenApprovals;
    
    constructor() {
      ContractOwner = msg.sender;
    }
    
    
    modifier onlyOwner {
         require(msg.sender == ContractOwner, "No eres el propietario.");
      _;
    }
    
    modifier freshId(uint256 _tokenID) {
     require(bytes(tokens[_tokenID].name).length == 0, "Ese token ya existe.");
      _;
    }
    
    modifier exists(uint256 _tokenID) {
     require(bytes(tokens[_tokenID].name).length > 0, "No existe ese token.");
      _;
    }
    
    modifier weaponExists(uint256 _tokenID, string memory w_name) {
     require(!ArrayUtils.contains(tokens[_tokenID].weapons.names, w_name), "Ese arma ya existe.");
      _;
    }
    
    modifier isTokenOwner(uint256 _tokenID) {
     require(msg.sender == tokens[_tokenID].tokenOwner, "No es el propietario del token");
      _;
    }
    
    modifier isTokenOwnerOrAuthorized(address addr, uint256 _tokenID) {
     require(addr == tokens[_tokenID].tokenOwner || addr == _tokenApprovals[_tokenID], 
     "No es el propietario del token o no estas autorizado");
      _;
    }
    
    
    function createMonsterToken(string memory name, address t_owner) external onlyOwner returns (uint256){
        uint256 tokenId = ini + acum;
        acum = acum + 1;
        if(propietarios[t_owner] > 0){
            propietarios[t_owner] = propietarios[t_owner] + 1;
        }
        else{
            propietarios[t_owner] = 1;
        }
        Character memory char;
        char.name = name;
        char.tokenOwner = t_owner;
        char.tokenId = tokenId;
        char.weapons.names =  new string[](0);
        char.weapons.firePowers =  new uint[](0);
        tokens[tokenId] = char;
        return tokenId;
    }
    
    function addWeapon(uint256 _tokenID, string memory w_name, uint firepower) external exists(_tokenID) weaponExists(_tokenID, w_name) {
        tokens[_tokenID].weapons.names.push(w_name);
        tokens[_tokenID].weapons.firePowers.push(firepower);

    }
    
    function incrementFirePower(uint256 _tokenID, uint8 percentage) external exists(_tokenID) {
        ArrayUtils.increment(tokens[_tokenID].weapons.firePowers, percentage);
    }
    
    /* Aqui se empiezan a definir las funciones de la interfaz*/
    
    function approve(address approved, uint256 tokenId) override external payable isTokenOwner(tokenId){
       _tokenApprovals[tokenId] = approved;
       emit Approval(msg.sender, approved, tokenId);
       if(msg.value < ArrayUtils.sum(tokens[tokenId].weapons.firePowers)){
           revert();
       }
    }
    
    function transferFrom(address _from, address _to, uint256 tokenId) override external payable 
    isTokenOwnerOrAuthorized(msg.sender,tokenId) {
        require(_to != address(0), "Transferencia a la direccion nula");
        emit  Transfer(_from, _to, tokenId);
        propietarios[_from] = propietarios[_from] - 1;
        propietarios[_to] = propietarios[_to] + 1;
        tokens[tokenId].tokenOwner = _to;
        _tokenApprovals[tokenId] = address(0);
        if(msg.value < ArrayUtils.sum(tokens[tokenId].weapons.firePowers)){
           revert();
        }
    }
    
    
    function balanceOf(address owner) override external view returns (uint256) {
        require(owner != address(0), "Balance de la direccion nula");
        return propietarios[owner];
    }
    
    function ownerOf(uint256 tokenId)  override external view returns (address) {
        require(tokens[tokenId].tokenOwner != address(0), "Direccion nula");
        return tokens[tokenId].tokenOwner;
    }
    
    function getApproved(uint256 tokenId) override external view exists(tokenId) returns (address)  {
        return _tokenApprovals[tokenId];
    }

}
