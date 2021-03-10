pragma solidity >=0.6.0 <0.8.0;
// SPDX-License-Identifier: WWGOWGA
// Writen by the people for the people 

import "./tool-safemath.sol";
import "./trans-erc20.sol";

contract Fountain is Terc20  {
    //-------------------Libraries---------------------------
    using SafeMath for uint; 
    using SafeMath for uint16;
    using SafeMath for uint32;
    using SafeMath for uint64;
    //-------------------Storage-----------------------------    
    address payable private manager; // must keep for payment & contract setting
    address payable private stakeContract; // the address to the stakers pool 
    address payable private lotteryContract; // the address to the lottery pool
    Terc20 private rare; // declares an contract instance type, named rare
    uint private gasUsed; 
    uint8 public bountyRewardMultiplier;      
    uint64 private fee;
    uint64 public poolBalance;
    
    bool private regPeriod; // false = period 1, true = period 2  
    uint private claimerAmt;
    uint private claimerAmt2;    
    uint private regInc; 
    uint private regInc2;     
    
    //-------------------timer-----------------------------   
    uint16 public blocksPerDay; // 16600 is one day real @ avg block per day, 17280 is one day @ 5, 720 is one hour @ 5 , 60 is @ 5 
    uint public blockTarget; 
    uint16 public cycleCount; 
    
    struct Cycle {
        uint16 reg1; 
        uint16 reg2;
    }
     
     
    //-------------------Mappings---------------------------
    // A) creates a bool pair for adress sender 
    mapping(address => bool) private checkReg;
    mapping(address => bool) private checkReg2;
    mapping(address => Cycle) private cycleChk; 

    
    //-------------------Events-----------------------------      
    event NewReg(address indexed _adr,  bool indexed _period, bool indexed _regSuccess);  
    event RegClaim(address _adr,  bool  _period, bool indexed _claimSuccess);      
    event DailyBounty(address indexed _bountyAdr, uint indexed _day, bool indexed _bountySuccess); 
    event LastDay(uint indexed _day, uint indexed _finalBalance, bool indexed _lastday); 
    event OwnershipTransferred(address indexed _newManager);

    //-------------------Contructor-------------------------
    constructor() {
        manager = msg.sender;
        poolBalance = 1 ether; 
        blocksPerDay = 16600;
        fee = 0.05 ether;
        bountyRewardMultiplier = 1;        
        blockTarget = block.number.add(blocksPerDay);
    }
    
    
    //-------------------Payable Functions-----------------     
    // #regester for distrobution  
    function register() public alw payable returns (bool) {
        require(msg.value >= fee.add(0.01 ether), "You must cover the xDai transaction fee"); 
        // pays fee to manager
        manager.transfer(fee);
        
        // regesters user for appropertate period 
        if (regPeriod) { // do if in period 2
        require(!checkRegNext() || cycleChk[msg.sender].reg2 <= cycleCount.sub(2), "You already registerd today");        
        // Marks Player Registerd
        checkReg2[msg.sender] = true;
        // set cyclechk 
        cycleChk[msg.sender].reg2 = cycleCount;
        // incresses reg number 
        regInc2 = regInc2.add(1); 
        } else { // do if in period 1
        require(!checkRegNext() || cycleChk[msg.sender].reg1 <= cycleCount.sub(2), "You already registerd today");
        // Marks Player Registerd
        checkReg[msg.sender] = true;
        // set cyclechk 
        cycleChk[msg.sender].reg1 = cycleCount;        
        // incresses reg number 
        regInc = regInc.add(1); 
        }
        
    // sends a regestration notification 
    emit NewReg(msg.sender,regPeriod,true);
    return true;     
    }
    
    function claim() public alw returns (bool) { 
        
        if (regPeriod) { // do if in period 2
           // open claim for prior period            
           require(checkReg[msg.sender] == true && cycleChk[msg.sender].reg1 == cycleCount.sub(1), "You did not register for yesterday's period Or already claimed");
           checkReg[msg.sender] = false; 
           regInc = regInc.sub(1);           
           rare.transfer(payable(msg.sender), claimerAmt);  
           } else { // do if in period 1 
           // open claim for prior period            
           require(checkReg2[msg.sender] == true && cycleChk[msg.sender].reg2 == cycleCount.sub(1), "You did not register for yesterday's period Or already claimed");
           checkReg2[msg.sender] = false; 
           regInc2 = regInc2.sub(1);           
           rare.transfer(payable(msg.sender), claimerAmt2);             
        } 
    emit RegClaim(msg.sender,regPeriod,true);
    return true;
    }
    
    // triggers the next reg event and pays out contracts and rewards bounty hunter    
    function claimBounty() public blk returns (bool){
        
        // sets gas price for latter refund
        uint gasStart = gasleft();
        uint poolRemainder = 0; 
        uint regNum = getPoolNum(); 
        
        // resets the timer 
        blockTarget = block.number.add(blocksPerDay);
        cycleCount = uint16(cycleCount.add(1)); 
 
        // Increase Reward for bounty hunter 
        regNum = regNum.add(bountyRewardMultiplier); 
        
 
        // Calcs Based on current period 
        if (regPeriod) { // do if in period 2 still 
            // sets the final claim amount for current period 
            claimerAmt2 = poolBalance.div(regNum);
            // calcs unclaimed amount from last pool, sets value as lottery payout 
            poolRemainder = regInc.mul(claimerAmt);
        } else { // do if in period 1 still 
            // sets the final claim amount for current period 
            claimerAmt = poolBalance.div(regNum);
            // calcs unclaimed amount from last pool, sets value as lottery payout 
            poolRemainder = regInc2.mul(claimerAmt2); 
        }


        // as long as coins exsist, fountain can countinue
        require(getRareBalance() >= 2 ether, 'there is no more rare coin!'); 
        // Loads pools balances, distrubutes 2 rare coins 
        poolBalance = 1 ether;
        rare.transfer(stakeContract, 1 ether);
        rare.transfer(lotteryContract, poolRemainder); 


        
        // starts a new period, emits events & pays bounty hunter 
        if (regPeriod) { // do if in period 2 still 
            // reset counter
            regInc = 0; 
            // reset last amt 
            claimerAmt = 0; 
            // reset period 
            regPeriod = false; // if in period 2, switch to 1 
            //emits events 
            if (getRareBalance() < 2 ether) {
                emit LastDay(cycleCount,getRareBalance(),true);
                } else {
                emit DailyBounty(msg.sender,cycleCount,true);
            }   
            // pays bounty hunter 
            rare.transfer(payable(msg.sender), claimerAmt2.mul(bountyRewardMultiplier));             
        } else { // do if in period 1 still 
            // reset counter
            regInc2 = 0; 
            // reset last amt 
            claimerAmt2 = 0; 
            // reset period 
            regPeriod = true; // if in period 1, switch to 2 
            //emits events 
            if (getRareBalance() < 2 ether) {
                emit LastDay(cycleCount,getRareBalance(),true);
                } else {
                emit DailyBounty(msg.sender,cycleCount,true);
            }  
            // pays bounty hunter 
            rare.transfer(payable(msg.sender), claimerAmt.mul(bountyRewardMultiplier));             
        }
        
        // sets used gas for refund 
        gasUsed = gasStart.sub(gasleft()); // calc cumpute cost 
        gasUsed = gasUsed.add(53000); // add transaction cost 
        uint gasWei = gasUsed.mul(1000000000); // convert qwei to wei
        // refunds gas for bounty hunter claim
        msg.sender.transfer(gasWei);
        return true; 
    }
    
    //-------------------Manager Functions----------------------
    // sets a new manager of the contract 
    function setManager(address payable _newManager) public restricted {
        manager = _newManager;
        emit OwnershipTransferred(_newManager);
    }
    
    
    // #sets the erc20 address, only manager
    function setContracts(address _rareAddress, address payable _stakeAddress, address payable _lotteryContract) public restricted {
        rare = Terc20(_rareAddress);
        stakeContract = _stakeAddress;
        lotteryContract = _lotteryContract; 
    }
    
    // #sets number of blocks per day, only manager
    function setBlocksPerDay(uint16 _blks) public restricted {
        blocksPerDay = _blks;
    }
    
    // #sets the price of the fee, cant be over 1 doller, only manager  
    function setFee(uint64 _fee) public restricted {
        require(_fee < 0.1 ether, "Cant set the fee higher then 0.1 xDai");
        fee = _fee; 
    }
    
    // #sets blounty hunter reward multiplyer 
    function setBtnRewards(uint8 _setMultiplyer) public restricted {
        bountyRewardMultiplier = _setMultiplyer; 
    }

    // #gets how much gas was used on the last distrobution
    function getGasUsed() public restricted view returns (uint) { 
        return gasUsed; 
    }    
    
    // #gets balance of xdai contract adress has, only manager
    function getXdaiBalance() public restricted view returns (uint) {
        return uint(address(this).balance);
    }  
    
    // #Manager can pull funds to re-propergate 
    function adminWithdraw() public restricted {
        require(address(this).balance >= 111 ether, "Must have more then 111 xdai in contrat to safely remove 100 xdai");
        // pays fee to manager
        manager.transfer(100 ether);
    }
    
    // cheaks what period it is 
    function checkPeriod() public restricted view returns (string memory) {
        if(regPeriod){
          return "in period two";  
        } else {
          return "in period One";   
        }
    }
    
    //-------------------Public View Functions-----------------------    
    // #cheaks balance of total unceculating tokens this contract adress has left to distrobute
    function getRareBalance() public view returns (uint) {
        return uint(rare.balanceOf(address(this)));
    }

    // #gets current estimate of payout this period in rare coin inc btn multiplyer // 
    function calcDistAmt() view public returns (uint) {
        require(getPoolNum() >= 1, "Can't calculate balance because no one is in the pool"); 
        uint temp;
        temp = getPoolNum(); 
        temp = temp.add(bountyRewardMultiplier);
        return uint(poolBalance.div(temp)); 
    }    
    
    // #gets number of players in pool                           
    function getPoolNum() public view returns (uint32) {
        uint32 regNum; 
        if (regPeriod) { // gets users number for period 2 
            regNum = uint32(regInc2);           
        } else { // gets users number for period 1
            regNum = uint32(regInc);
        }
        return uint32(regNum);
    }   
    
    // #gets a true or false if user is regested for the this period claim
    function checkRegThis() public view returns (bool) { 
        bool isRegisterd; 
        if (regPeriod) { // gets users number for period 2 
           isRegisterd = checkReg[msg.sender];          
        } else { // gets users number for period 1
           isRegisterd = checkReg2[msg.sender];          
        }        
        return isRegisterd; 
    }    
    
    // #gets a true or false if user is regested for the next period claim
    function checkRegNext() public view returns (bool) { 
        bool isRegisterd; 
        if (regPeriod) { // gets users number for period 2 
           isRegisterd = checkReg2[msg.sender];           
        } else { // gets users number for period 1
           isRegisterd = checkReg[msg.sender];  
        }        
        return isRegisterd; 
    }    
    //-------------------timr Functions---------------------  
    
    
    function blocksLeft() public alw view returns (uint) {  
        return blockTarget.sub(blockNow());
    }
     
    function blockNow() public view returns (uint) { 
        return block.number;  
    }      
    
    
    //-------------------Modifiers Call Functions--------------------------- 
    //   while (blockTarget >= currentBlock) = true, unlocked 
    //   while (blockTarget <= currentBlock) = untrue, locked
    
    modifier alw() {
        require(blockTarget >= block.number, "Target Reached, No Blocks Left"); // allow before target reached
        _;
    }     


    modifier blk() {
        require(blockTarget <= block.number, "Locked until block target is achieved"); // allow after target reached
        _;
    }      


    // *creates a restricted fuction unless you are the manager
    modifier restricted() {
        require(msg.sender == manager, "Only the manager can perfom this fuction");
        _;
    }

    
    //-------------------Special Functions--------------------------- 
    
    
    //fallback function 
    receive () external payable {
        register();
    }
    
    
}
