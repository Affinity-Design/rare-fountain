pragma solidity >=0.6.0 <0.8.0;
// SPDX-License-Identifier: MIT

contract Terc20 {
   //-------------------Mappings---------------------------    
    mapping(address => uint) public balanceOf;
   
   //-------------------Events-----------------------------      
    event Transfer(address indexed _from, address indexed _to, uint _value); 
 
  
   //-------------------Public Functions-------------------  
   
   // transfer fuction 
    function transfer(address _to, uint _value) public returns (bool){
         // makes sure that user is not sending more then they have, if they try it fails 
        require(balanceOf[msg.sender] >= _value, "Not enough tokens in account");
         // makes sure amout being sent is greater then recipients starting balance
        assert(balanceOf[_to] + _value >= balanceOf[_to]);
         // makes sure amout being deducted is less then senders starting balance
        assert(balanceOf[msg.sender] - _value <= balanceOf[msg.sender]);
         // removes balance from sender
        balanceOf[msg.sender] -= _value;
         // incresses balance of recipient 
        balanceOf[_to] += _value;
         // creates a transfer event, returns arguments as an event 
        emit Transfer(msg.sender, _to, _value);
         // returns true if succesful 
        return true; 
    }
    
//-- end of contract --
}


