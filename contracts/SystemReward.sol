pragma solidity 0.6.4;
import "./System.sol";
import "./interface/ISystemReward.sol";

contract SystemReward is System, ISystemReward{
  uint256 public constant MAX_REWARDS = 1e18;

  uint public numOperator;
  mapping(address => bool) operators;


  modifier doInit() {
    if (!alreadyInit) {
      operators[LIGHT_CLIENT_ADDR] = true;
      operators[INCENTIVIZE_ADDR] = true;
      numOperator = 2;
      alreadyInit = true;
    }
    _;
  }

  
  event rewardTo(address indexed to, uint256 amount);
  event rewardEmpty();
  event receiveDeposit(address indexed from, uint256 amount);
  event addOperator(address indexed operator);


  receive() external payable{
    if (msg.value>0) {
      emit receiveDeposit(msg.sender, msg.value);
    }
  }

  
  function claimRewards(address payable to, uint256 amount) external override(ISystemReward) doInit returns(uint256) {
    if (!operators[msg.sender]) {
      return -1;
    }

    uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
    if (actualAmount > MAX_REWARDS) {
      actualAmount = MAX_REWARDS;
    }
    if (actualAmount>0) {
      to.transfer(actualAmount);
      emit rewardTo(to, actualAmount);
    } else {
      emit rewardEmpty();
    }
    return actualAmount;
  }

  function isOperator(address addr) external view returns (bool) {
    return operators[addr];
  }

  function updateParam(string calldata key, bytes calldata value) onlyGov external override {
    if (Memory.compareStrings(key, "addOperator")) {
      bytes memory valueLocal = value;
      require(valueLocal.length == 32, "length of value for addOperator should be 32");
      address operatorAddr;
      assembly {
        handlerContract := mload(add(valueLocal, 32))
      }
      operators[operatorAddr] = true;
      emit addOperator(operatorAddr);
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }  
}