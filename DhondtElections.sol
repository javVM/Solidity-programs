// SPDX-License-Identifier: GPL-3.0
//Javier Verde Marin
pragma solidity >=0.7.0 <0.8.0;
contract DhondtElectionRegion {
    mapping(uint => uint)private weights;
    uint  private regionId;
    uint[] internal results;
     
    constructor(uint _partido, uint region) { 
         regionId = region; 
         results = new uint[](_partido);
         savedRegionInfo();
         
    }
     
    function registerVote(uint _partido) internal  returns (bool){
         if(_partido >= results.length){
             return false;
         }
         else{
            results[_partido] = results[_partido] + weights[regionId];
         }
         
         return true;
    }
  
    function savedRegionInfo() private{
    weights[28] = 1; // Madrid
    weights[8] = 1; // Barcelona
    weights[41] = 1; // Sevilla
    weights[44] = 5; // Teruel
    weights[42] = 5; // Soria
    weights[49] = 4; // Zamora
    weights[9] = 4; // Burgos
    weights[29] = 2; // Malaga
    }
}

abstract contract PollingStation {
    bool public votingFinished;
    bool private votingOpen;
    address  president;
    bool private tableOpen;
    
    constructor (address _president) { 
        votingFinished = false;
        votingOpen = false;
        president = _president;
        tableOpen = true;
    }
    
    modifier onlyOwner {
      require(msg.sender == president);
      _;
    }
    
    modifier canVote {
      require(votingOpen == true);
      _;
    }
    
    modifier tableisOpen {
      require(tableOpen == true);
      _;
    }

    function openVoting() external onlyOwner tableisOpen {
        votingOpen = true;
    }
    
    function closeVoting() external onlyOwner {
        votingFinished = true;
        votingOpen = false;
    }
    
    function castVote(uint partido) external virtual;
 
    function getResults() external virtual returns (uint[] memory);
}

contract DhondtPollingStation is PollingStation, DhondtElectionRegion {
    
    constructor(address _president, uint _partido, uint _regionID) DhondtElectionRegion (_partido, _regionID) PollingStation(_president) {} 
    
    function castVote(uint partido) external canVote override {
         require(registerVote(partido)==true, "No has elegido un partido posible o la votacion no esta abierta.");
    }
 
    function getResults() external override returns (uint[] memory) {
        require(votingFinished==true, "No se han acabado las votaciones");
        return results;
        
    }
}

contract Election {
    mapping(uint=> DhondtPollingStation) private sedes;
    address private owneraddress;
    mapping(address=>bool) private votantes;
    uint private numpartidos;
    uint[] private regiones;
    
    modifier onlyAuthority {
         require(msg.sender == owneraddress, "No eres la Autoridad administrativa");
      _;
    }
    
    modifier freshId(uint _regionId) {
     require(address(sedes[_regionId]) == address(bytes20(0)));
      _;
    }
    
     modifier validId(uint _regionId) {
     require(address(sedes[_regionId]) != address(bytes20(0)));
      _;
    }
    
     modifier firstTimeVoting() {
     require(votantes[msg.sender] == false);
      _;
    }
    
    constructor(uint _partidos) {
      numpartidos = _partidos;
      owneraddress = msg.sender;
      
    }
    
   function createPollingStation(uint _regionId, address _president) external onlyAuthority freshId(_regionId) returns (address){
       sedes[_regionId] = new DhondtPollingStation(_president, numpartidos, _regionId);
       regiones.push(_regionId);
       return address(sedes[_regionId]);
   }
   
   function castVote(uint _regionId, uint partido) external validId(_regionId) firstTimeVoting {
      votantes[msg.sender] = true;
      sedes[_regionId].castVote(partido);
   }
   
   function getResults() external onlyAuthority returns (uint[] memory){
       uint[] memory resultados = new uint[](numpartidos);
       for(uint i = 0; i < regiones.length; i++){
           require(sedes[regiones[i]].votingFinished() == true, "Todavia no se ha terminado de votar");
               uint[] memory aux = sedes[regiones[i]].getResults();
               for(uint j=0; j < aux.length; j++){
                   resultados[j] = resultados[j] + aux[j];
                }
           
        }
        
        return resultados;
   }
   
}
