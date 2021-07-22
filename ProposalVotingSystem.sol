// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./ERC20.sol";

//ALUMNO: Javier Verde Marin

/*Se usa esta biblioteca para calcular en numero de votos resultantes en stakeAllToProposal*/
library Utility {
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

/* Se utlizara la biblioteca SafeMath de OpenZeppelin para evitar los casos de underflow u overflow */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */

  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

/****** INTERFAZ DE LAS PROPUESTAS *************/
interface ExecutableProposal {
    //Las funciones de las interfaces por defecto son virtual
    function executeProposal(uint256 proposalId) external payable;
}

//Contrato que implementa la interfaz
contract ProposalContract is ExecutableProposal {
    //He decicido crear dos eventos, uno que indique que se esta ejecutando la propuesta y otro que indica cual se esta ejecutando aprovechando el pid
    event exec_prop(string execution_message);
    event num_prop(uint256 pid);
     function executeProposal(uint256 proposalId) override external payable {
         emit exec_prop("Propuesta ejecutandose");
         emit num_prop(proposalId);
         
     }
}


//Se define el contrato de la votación
contract QuadraticVoting {
    
    //Definicio de una propuesta: titulo y su descripcion, dinero necesario para financiacion, si está aprobada o no y
    //contrato de transferencia.
    struct Proposal{
        string title;
        string description;
        uint256 budget;
        bool approved;
        //Pasa a true cuando se aprueba o es retirada
        bool notPending;
        address creator;
        address contractProposal;
    }
    
    //Para saber si ha votado un participante y cuantas veces lo ha hecho
    struct Voted{
        bool didvote;
        uint256 numvotes;
    }
    
    //Propietario del contrato
    address payable contractOwner;
    //Maximas tokens que se van a poner a la venta
    uint256 private maxTokens;
    //Tokens en venta, cuando se vayan vendiendo se reduce
    uint256 private tokens_sold;
    //Precio inicial de las tokens
    uint256 private tokenPrice;
    //Booleano para saber si la votación está abierta o no
    bool private votingOpen;
   
    //Participantes y propuestas
    //Participantes:
    //Participantes con sus tokens
    mapping(address => uint256) private participants;
    //Comprobacion de que el participante se ha añadido:
    mapping (address => bool) private added;
    //lista de participantes para interar
    address[] private participant_list = new address[](0);
    //Veces que ha votado el participante en cada propuesta
    mapping(address=>mapping(uint256=>Voted)) private votesRegister;
    /********************************************/
    //Propuestas:
    //Numero de propuestas pending
    uint256 private numPending = 0;
    //Numero de propuestas de signaling
    uint256 private numSignaling = 0;
    //Valor de proposals único de proposals, en nuestro caso comenzara en uno
    uint256 private idcounter = 1;
    //Propuestas con su informacion
    mapping(uint256 => Proposal) private proposals;
    //Tokens de totales de cada propuesta
    mapping(uint256 => uint256) private propTokens;
    //Referencia para busquedas, contiene todos los ids de peticiones aprobadas
    uint256[] private proposals_approved;
    //Referencia para busquedas, cotienen todos los ides de peticiones pendientes
    uint256[] private proposals_pending;
   
    //Contrato de gestion de tokens
    ERC20 tokencontract;
    
    //Presupuesto original
    uint256 private total_budget;
    
    //Para evitar reentrancy a la hora de ejecutar la Propuesta
    bool lock = false;
    
    /*Declaramos el constructo que inicializa el contrato de ERC20 y prepara el resto de variables*/
     constructor(uint256 price_wei, uint256 max) payable{
      contractOwner = payable(msg.sender);
      tokenPrice = price_wei;
      maxTokens =  max;
      votingOpen = false;
      tokencontract = new ERC20("Project Token", "PT", address(this));
      //Usamos la funcion externa que hemos creado que llama a la funcion interna _mint para poder crear los tokens
      tokencontract.createTokens(address(this),maxTokens);
      //Almacenamos el presupuesto original
      total_budget = msg.value;
    }
    
    /******* MODIFICADORES ********/
    modifier onlyOwner {
         require(msg.sender == contractOwner, "No eres el propietario del contrato.");
      _;
    }
    
    modifier _votingOpen {
         require(votingOpen == true, "No ha comenzado el periodo de votacion");
      _;
    }
    
     modifier validAddition {
         require(msg.value >= tokenPrice, "No se han introducido el minimo de wei.");
      _;
    }
    
    modifier isNew {
          require(added[msg.sender] != true, "Este participante ya se ha aniadido.");
      _;  
    }
    
    modifier tokensAvailable {
          require(tokens_sold < maxTokens, "Ya no se pueden comprar mas tokens.");
        _;
    }
    
    modifier onlyCreator(uint256 pid) {
          require(msg.sender == proposals[pid].creator, "No eres el creador de la propuesta.");
        _;
    }
    
    modifier notApproved(uint256 pid) {
          require(bytes(proposals[pid].title).length > 0 && proposals[pid].approved == false && proposals[pid].notPending == false
          , "La propuesta ya ha sido aprobadao cancelada");
        _;
    }
    
    modifier proposalExists(uint256 pid) {
          require(bytes(proposals[pid].title).length > 0, "La propuesta no existe");
        _;
    }
    
    modifier participantExists() {
          require(added[msg.sender] == true, "El participante no existe");
        _;
    }
    

    /******** AQUI EMPIEZAN LAS FUNCIONES **********/
    
    function openVoting() public onlyOwner{
        if(!votingOpen) votingOpen = true;
    }
    
    //se añade al participante: se comprueba que se pueda comprar al menos un token y que no exista ya el participante
    //Tambien tenemos en cuenta que se puedan comprar mas tokens
    function addParticipants() external payable validAddition isNew tokensAvailable{
        //Calculamos el numero de tokens que podria comprar utilizando la libreria SafeMath
        uint256 aux = SafeMath.div(msg.value, tokenPrice);
        uint256 prop;
        require(tokens_sold + aux <= maxTokens, "Se ha excedido el numero de tokens");
        //Añadimos el numero de tokens para tenerlos mas a mano
        participants[msg.sender] = aux;
        //Se transfieren los tokens al usuario desde el contrato al usuario
        tokencontract.transfer(msg.sender, aux);
        //Se añade el participante
        added[msg.sender] = true;
        //Se añade a la lista
        participant_list.push(msg.sender);
        //aumentamos el numero de tokens vendidos
        tokens_sold = tokens_sold + aux;
         //El numero de participantes afecta al calculo del umbral
        //Ahora habria un participante mas. Por lo que se deben recorrer las propuestas ya que se ha modificado un umbral
       //*!* Si una se aprueba se hace i = 0 ya que se tienen que volver a comprobar todas las demas por eso se modifica la variable de control
        for(uint256 i = 0; i < proposals_pending.length; i++){
                prop = proposals_pending[i];
                if(!proposals[prop].notPending){
                    if(_executeProposal(prop)) i = 0;
                }
        }
            
    }
    
    //Funcion para aniadir una propuesta
    //Se ha decicido que los parámetros de tipo string estén en memory pues es menos costoso
    function addProposal(string memory _title, string memory _description, uint256 _budget, address contractProposal) participantExists external returns (uint256){
        //cogemos el id unico por el que vamos
        uint256 propid = idcounter;
        uint256 aux;
        //guardamos la nueva propuesta en el mapping
        proposals[propid] = Proposal(_title, _description, _budget, false, false, msg.sender, contractProposal);
        //actualizamos el id unico para la siguiente propuesta creada
        //No usamos SafeMath porque el usuario no puede introducir este valor
        idcounter++;
        //Aniadimos automaticamente la nueva propuesta a la lista de propuestas pendientes
        proposals_pending.push(propid);
        //Si el budget introducido es 0, pasa a ser una propuesta de signaling si no es una propuesta pendiente
        if(_budget == 0) numSignaling++;
        else{ 
            numPending++;
            //El numero de propuestas afecta al calculo del umbral
            //Ahora habria una propuesta mas, por lo que se deben recorrer ya que se ha modificado un umbral
           //*!* Si una se aprueba se hace i = 0 ya que se tienen que volver a comprobar todas las demas por eso se modifica la variable de control
            for(uint256 i = 0; i < proposals_pending.length; i++){
                aux = proposals_pending[i];
                if(!proposals[aux].notPending){
                    if(_executeProposal(aux)) i = 0;
                }
            }
        }
        //Se devuelve el id
        return propid;
    }
    

    //Funcion para cancelar la propuesta
    //Se comprueba que la realiza el creador de la propuesta y que no haya sido aprobada aun
    //Se recorre la lista de participantes y si han votado se devuelven los tokens basado en el numero de votos que haya realizado
    function cancelProposal(uint256 _proposalId) external onlyCreator(_proposalId) proposalExists(_proposalId) notApproved(_proposalId){
        //Se usan estas variables para ahorrar accesos a storage
        uint256 aux;
        address uid;
        for(uint256 i = 0; i < participant_list.length; i++){
            uid = participant_list[i];
            if(votesRegister[uid][_proposalId].didvote == true) {
              tokencontract.transfer(uid,  votesRegister[uid][_proposalId].numvotes**2);
              participants[uid]+= votesRegister[uid][_proposalId].numvotes**2;
              votesRegister[uid][_proposalId].didvote = false;
               tokens_sold +=votesRegister[uid][_proposalId].numvotes**2;
              votesRegister[uid][_proposalId].numvotes = 0;
            }
        }
        numPending--;
        proposals[_proposalId].notPending = true;
        
        //Ahora habria una propuesta menos, por lo que se deben recorrer todas las demas ya que se ha modificado un umbral
        //*!* Si una se aprueba se hace i = 0 ya que se tienen que volver a comprobar todas las demas por eso se modifica la variable de control
        for(uint256 i = 0; i < proposals_pending.length; i++){
            aux = proposals_pending[i];
            if(!proposals[aux].notPending){
                if(_executeProposal(aux)) i = 0;
            }
        }
        
    }
    
    //Funcion para comprar tokens, se comprueba que ese usuario ya existe y que no se supera el numero de tokens en circulacion
    function buyTokens()  participantExists tokensAvailable external payable {
        //De nuevo, como en addParticipants volvemos a utilizar la biblioteca SafeMath
         uint256 aux = SafeMath.div(msg.value, tokenPrice);
         require(tokens_sold + aux <= maxTokens, "Se supera el limite de tokens en circulacion");
         tokencontract.transfer(msg.sender, aux);
         participants[msg.sender] += aux;
         tokens_sold = tokens_sold + aux;
    }
    
    //Funcion para poder intercambiar los tokens por dinero
    //Primero nos aseguramos de que el participante exista
    function sellTokens() participantExists external {
        require(participants[msg.sender] > 0, "No hay tokens que vender");
        require(tokencontract.allowance(msg.sender,address(this)) >= participants[msg.sender], "No hay permiso para transferir tantas tokens");
          //Se envian al contrato
          tokencontract.transferFrom(msg.sender,address(this), participants[msg.sender]);
          //Se transfiere el dinero (numero de tokens * el precio del esta) y el participante pasa a tener 0 tokens
          //No nos exponemos a reentrancy porque se usa transfer, no call
          uint256 amount = participants[msg.sender]*tokenPrice;
          require(address(this).balance >= amount);
          payable(msg.sender).transfer(amount);
          //Se reduce el numero de tokens que hay en circulacion
          tokens_sold -= participants[msg.sender];
          //Se convierte a 0 
          participants[msg.sender] = 0;
          
    }
    
    //Se devuelve la direccion del contrato ERC20
    function getERC20Voting()  public view participantExists returns (address) {
        return address(tokencontract);
    }
    
    //Devuelve las propuestas pendientes
    //Se utiliza variable de estado en memory para que cueste menos gas
    //Se ha usado public view no se desea modificar el estado
    //Se introducen las de signaling tambien en pending pero no cuentan a la hora de mostrarse en el getter
    function getPendingProposals() public view returns (uint256[] memory) {
        uint256[] memory pending = new uint[](numPending);
        uint256 j = 0;
        uint256 pid;
        for(uint256 i = 0; i < proposals_pending.length ; i++){
             pid = proposals_pending[i];
            if(proposals[pid].budget != 0 && !proposals[pid].notPending){
                pending[j] = proposals_pending[i];
                j++;
            }
        }
        return pending;
    }
    
    //Devuelve las propuestas aprobadas
    //Se utiliza variable de estado en memory para que cueste menos gas
    //Se ha usado public view no se desea modificar el estado
    function getApprovedProposals() public view returns (uint256[] memory) {
        uint256[] memory appr = new uint[](proposals_approved.length);
        for(uint256 i = 0; i < proposals_approved.length ; i++){
            appr[i] = proposals_approved[i];
        }
        return appr;
    }
    
    //Devuelve las porpuestas de signaling
    //Necesitamos saber todas las propuestas de signaling por lo que buscamos entre las pendientes que tengan 0 budget
    //Creamos la varibale que vamos a devolver en memory para ahorrar gas
    //Recorremos ambos arrays (pending y approved) y si la propuesta a la que se accede tiene presupuesto 0, se añade 
    function getSignalingProposals() public view returns (uint256[] memory){
        uint256[] memory signaling = new uint[](numSignaling);
        uint256 j = 0;
        uint256 pid;
        for(uint256 i = 0; i < proposals_pending.length ; i++){
            pid = proposals_pending[i];
            if(proposals[pid].budget == 0 && !proposals[pid].notPending){
                signaling[j] = proposals_pending[i];
                j++;
            }
        }
        return signaling;
    }
    
    //Devuelve los datos de una propuesta, es decir, el struct con los datos de asociado a un id
    //Comprobamos que la porpuesta exista, se busca en el mapping y se devuelve. Se usa el parametro en memory
    //para ahorrar gas
    function getProposalInfo(uint256 pid) public view proposalExists(pid) returns (Proposal memory) {
        Proposal memory aux = proposals[pid];
        return aux;
    }
    
    //Funcion para votar una propuesta un determinado numero de veces dado su id.
    //Se comprueba que la propuesta y participante existan, que no haya sido aprobada y que el periodo de votacion este abierto
    function stake(uint256 pid, uint256 numvotos) public _votingOpen participantExists proposalExists(pid) notApproved(pid){
      //Evitamos que se hagan votos nulos
       require(numvotos >= 1, "Quieres hacer 0 votos!");
       uint256 aux = votesRegister[msg.sender][pid].numvotes;
       bool voted = votesRegister[msg.sender][pid].didvote;
       //Se comprueba en todos los casos si hay suficientes tokens
           //Si ya ha votado antes aumentamos el numero de veces que ha votado y se transfieren los tokens
           //Se comprueba que haya suficientes despues de calcular los tokens. Se calcula el cuadrado total y se le resta el cuadrado en base
           //a los votos anteriores.
           uint256 prop;
           uint256 totaltokens = SafeMath.sub((SafeMath.add(numvotos,aux))**2, aux**2);
           require(tokencontract.allowance(msg.sender, address(this)) >= totaltokens, "No hay permiso para transferir tantas tokens");
           require(participants[msg.sender] >= totaltokens, "No tienes suficientes Tokens");
           votesRegister[msg.sender][pid].numvotes = SafeMath.add(votesRegister[msg.sender][pid].numvotes, numvotos);
           tokencontract.transferFrom(msg.sender, address(this) , totaltokens);
           participants[msg.sender]-= totaltokens;
           //Se reduce el numero de tokens en circulacion
           tokens_sold -= totaltokens;
           if(!voted) votesRegister[msg.sender][pid].didvote = true;
           propTokens[pid] += totaltokens;
           
           //Se llama a la funcion para comprobar si quiza se pueda aprobar y si se aprueba se comprueban las demas
           //*!*Se hacen mas iteraciones, es decir, vuelve a 0 cuando una funcion se aprueba para volver a comprobar todas ya que habria
           //una propuesta menos. (Es decir, se modifica la variable de control)
           if(_executeProposal(pid)){
               for(uint256 i = 0; i < proposals_pending.length; i++){
                prop = proposals_pending[i];
                    if(!proposals[prop].notPending){
                        if(_executeProposal(prop)) i = 0;
                    }
                }
           }
    }
    
      //Funcion para votar con los mayores votos posibles una propuesta
    //Se comprueba que la propuesta y participante existan, que no haya sido aprobada y que el periodo de votacion este abierto
    //Se busca el maximo numero de votos (se van acumulando las tokens hasta llegar al maximo que pueda el participante)
    //En caso de que no se pueda realizar ninguno sale mensaje
    //Aumentamos el numero de veces que ha votado el participante esa propuesta y le restamos el numero de tokens.
    function stakeAllToProposal(uint256 pid) public _votingOpen participantExists proposalExists(pid) notApproved(pid) {
       uint256 aux = votesRegister[msg.sender][pid].numvotes;
       bool voted = votesRegister[msg.sender][pid].didvote;
       //Se comprueba en todos los casos si hay suficientes tokens
           //Tiene que haber al menos tokens suficientes para un voto mas
           require(participants[msg.sender] >= ((aux+1)**2 - aux**2), "No hay sufientes tokens para votar");
           //Calculamos el numero de votos
           uint256 tokens_usados = aux**2;
           uint256 prop;
           uint256 max_votos = Utility.sqrt(participants[msg.sender] +  tokens_usados);
            //Se comprueba que el contrato tenga permiso
            //Lo que se quedaria la cuenta
            uint256 substraction = SafeMath.sub(participants[msg.sender] +  tokens_usados, max_votos**2);
            //Lo que se va a transferir
            uint256 transferAmount = SafeMath.sub(participants[msg.sender], substraction);
            require(tokencontract.allowance(msg.sender, address(this)) > transferAmount, "No hay permiso para transferir tantas tokens");
           //Se mantiene lo que sobre (porque no llega para otro token)
           tokencontract.transferFrom(msg.sender, address(this), transferAmount);
           tokens_sold -= transferAmount;
           participants[msg.sender] = substraction;
           votesRegister[msg.sender][pid].numvotes =  max_votos;
           if(!voted) votesRegister[msg.sender][pid].didvote = true;
           propTokens[pid] += transferAmount;
           
           //Se llama a la funcion para comprobar si quiza se pueda aprobar y si se aprueba se deben comprobar las demas
           //No obstante, si otra propuesta se aprueba, se deben volver a comprobar todas las demas: por eso se hace i = 0
           //*!* Se modifica la variable de control
           if(_executeProposal(pid)){
               for(uint256 i = 0; i < proposals_pending.length; i++){
                prop = proposals_pending[i];
                if(!proposals[prop].notPending){
                    if(_executeProposal(prop)) i = 0;
                }
               }   
           }
    }
    
    //Funcion para extraer votos de una propuesta un determinado numero de veces dado su id.
    //Se comprueba que la propuesta y participante existan, que no haya sido aprobada y que el periodo de votacion siga abierto
    function withdrawFromProposal(uint256 pid, uint256 numvotos) public _votingOpen participantExists proposalExists(pid) notApproved(pid){
       uint256 aux = votesRegister[msg.sender][pid].numvotes;
       bool voted = votesRegister[msg.sender][pid].didvote;
       //Se comprueba que se haya votado, que haya tantos votos como se pide y que no se pierda el tiempo pidiendo quitar 0 votos
       require(voted == true && (numvotos >= 1) && (numvotos <= aux), "No has votado esta propuesta o no hay tantos votos");
       //Obtenemos el numero total de tokens que nos han costado todos los votos y le restamos el total de la diferencia al cuadrado con
       //los votos que queremos conseguir, asi obtenemos las tokens que nos deben devolver.
           uint256 total_tokens = SafeMath.sub(aux**2, SafeMath.sub(aux,numvotos)**2);
           //Transferimos las tokens y le restamos el numero de votos de ese participante a la propuesta
           tokencontract.transfer(msg.sender, total_tokens);
           votesRegister[msg.sender][pid].numvotes = SafeMath.sub(votesRegister[msg.sender][pid].numvotes, numvotos);
           participants[msg.sender] += total_tokens;
           //Si se ha quedado en 0 votos entonces no ha votado
           if(votesRegister[msg.sender][pid].numvotes == 0) votesRegister[msg.sender][pid].didvote = false;
           tokens_sold += total_tokens;
           propTokens[pid] -= total_tokens;
       
    }
    
    //Funcion para extraer todos los votos una propuesta dado su id.
    //Se comprueba que la propuesta y participante existan, que aun no haya sido aprobada y que el periodo de votacion siga abierto
    function withdrawAllFromProposal(uint256 pid) public _votingOpen participantExists proposalExists(pid) notApproved(pid){
       uint256 aux = votesRegister[msg.sender][pid].numvotes;
       bool voted = votesRegister[msg.sender][pid].didvote;
       //Se comprueba que se haya votado
       require(voted == true, "No has votado esta propuesta");
           uint256 value = aux**2;
           //Transferimos los valores
           tokencontract.transfer(msg.sender, value);
           //Ya no tiene ningun voto en esa propuesta
           votesRegister[msg.sender][pid] = Voted(false, 0);
           //Sumamos el numero de tokens que tiene el participante
          participants[msg.sender] += value;
          tokens_sold += value;
          propTokens[pid] -= value;
       
    }
    
    //Funcion interna que comprueba que se cumplen las condiciones para ejecutarse la propuesta (supera el umbral)
    function _executeProposal(uint256 pid) proposalExists(pid) notApproved(pid) internal returns (bool){
        //Para evitar ataques de reentrancy se ha implementado un mutex para que se bloquee la funcion hasta que se pueda ejecutar.
        //Asi nos aseguramos de que siempre se acceda a informacion actualizada
        require(!lock, "Bloqueado, ya hay una ejecucion en curso");
        bool sent;
        //Se aplica la formula en caso de que sea una propuesta que no sea de signaling
        if(proposals[pid].budget == 0 || (total_budget*10 + (propTokens[pid]*tokenPrice)*10)>= (2 + (SafeMath.div(proposals[pid].budget,
            total_budget)*10)) * (participant_list.length*10) + (numPending*10)){
            lock = true;
            (sent,) = proposals[pid].contractProposal.call{value : proposals[pid].budget} (abi.encodeWithSignature("executeProposal(uint256)",pid));
            //Si los votos que tiene pueden no pagar la ejecucion hay que usar los wei empleados como presupuesto
             if(proposals[pid].budget != 0){
                 if(propTokens[pid]*tokenPrice < proposals[pid].budget){
                    //No hace falta controlar underflows porque ya se ha comprobado como condicion que debe ser mayor la suma del budget y de los votos
                     total_budget -= (proposals[pid].budget - propTokens[pid]*tokenPrice);
                    //La propuesta pasa a ser aprobada
                     proposals[pid].approved = true;
                     proposals_approved.push(pid);
                     //Hay una propuesta menos en pending
                     numPending--;
                     proposals[pid].notPending = true;
                }
            }
           lock = false;
            //No se borran los tokens porque se transfieren al contrato de nuevo
            require(sent, "La llamada al contrato de propuestas ha fallado");
            return true;
        }
        return false;
        
    }
    
    //Funcion para cerrar la votacion: Solo la puede realizar el propietario y debe aberse abierto el periodo de votacion en primer lugar
    function closeVoting() public _votingOpen onlyOwner{
        if(votingOpen) votingOpen = false;
        //Se usan estas variables para reducir el numero de accesos a storage
        uint256 pid;
        address uid;
        //Se devuelve el saldo de las propuestas no aprobadas (pendientes) y de signaling
        for(uint256 i = 0; i < proposals_pending.length; i++){
            for(uint256 j=0; j < participant_list.length; j++){
                pid = proposals_pending[i];
                uid = participant_list[j];
                if(!proposals[pid].notPending){
                    if(votesRegister[uid][pid].didvote == true) {
                    uint256 amount = (votesRegister[uid][pid].numvotes**2)*tokenPrice;
                    require(address(this).balance >= amount);
                    payable(uid).transfer(amount);
                    }
                
                //Se ejecutan las funciones de signaling 
                if(proposals[pid].budget == 0) _executeProposal(pid);
                }
                
                
            }
        }
        
        //Se devuelve lo gastado en tokens
        for(uint256 k = 0; k < participant_list.length; k++){
            uint256 val = participants[participant_list[k]]*tokenPrice;
             require(address(this).balance >= val);
            payable(participant_list[k]).transfer(val);
        }
        //Se devuelve el presupuesto restante al propietario
        contractOwner.transfer(address(this).balance);
        
        //Se ha decidido no transferir tokens al owner cuando el propietario porque se ha supuesto que closeVoting() es el
        //fin de la votacion y se debe hacer un nuevo deploy del contrato
        //No se emplea burn porque se crean todas las tokens en el constructor y van fluctuando mediante las operaciones.
    }
}
