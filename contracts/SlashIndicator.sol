pragma solidity 0.6.4;
import "./System.sol";
import "./lib/BytesToTypes.sol";
import "./lib/TypesToBytes.sol";
import "./lib/Memory.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/IApplication.sol";
import "./interface/IBSCValidatorSet.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/ICrossChain.sol";
import "./interface/ISystemReward.sol";
import "./lib/CmnPkg.sol";
import "./lib/RLPEncode.sol";

contract SlashIndicator is ISlashIndicator,System,IParamSubscriber, IApplication{
  using RLPEncode for *;

  uint256 public constant MISDEMEANOR_THRESHOLD = 50;
  uint256 public constant FELONY_THRESHOLD = 150;
  uint256 public constant BSC_RELAYER_REWARD = 1e16;
  uint256 public constant DECREASE_RATE = 4;
  uint256 public constant FINALITY_DISTANCE = 11;
  uint256 public constant FINALITY_REWARD_RATIO = 20;

  // State of the contract
  address[] public validators;
  mapping(address => Indicator) public indicators;
  uint256 public previousHeight;
  uint256 public  misdemeanorThreshold;
  uint256 public  felonyThreshold;
  uint256 public finalityDistance;
  uint256 public finalityRewardRatio;

  event validatorSlashed(address indexed validator);
  event indicatorCleaned();
  event paramChange(string key, bytes value);

  event knownResponse(uint32 code);
  event unKnownResponse(uint32 code);
  event crashResponse();

  struct Indicator {
    uint256 height;
    uint256 count;
    bool exist;
  }

  struct FinalityEvidence {
    uint256 numA;
    bytes32 headerA;
    bytes   sigA;
    uint256 numB;
    bytes32 headerB;
    bytes   sigB;
    address valAddr;
  }

  modifier oncePerBlock() {
    require(block.number > previousHeight, "can not slash twice in one block");
    _;
    previousHeight = block.number;
  }

  modifier onlyZeroGasPrice() {
    require(tx.gasprice == 0 , "gasprice is not zero");
    _;
  }

  modifier noReentrant() {
    require(!locked, "no re-entrancy");
    locked = true;
    _;
    locked = false;
  }
  
  function init() external onlyNotInit{
    misdemeanorThreshold = MISDEMEANOR_THRESHOLD;
    felonyThreshold = FELONY_THRESHOLD;
    finalityDistance = FINALITY_DISTANCE;
    finalityRewardRatio = FINALITY_REWARD_RATIO;
    alreadyInit = true;
  }

  /*********************** Implement cross chain app ********************************/
  function handleSynPackage(uint8, bytes calldata) external onlyCrossChainContract onlyInit override returns(bytes memory) {
    require(false, "receive unexpected syn package");
  }

  function handleAckPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract onlyInit override {
    (CmnPkg.CommonAckPackage memory response, bool ok) = CmnPkg.decodeCommonAckPackage(msgBytes);
    if (ok) {
      emit knownResponse(response.code);
    } else {
      emit unKnownResponse(response.code);
    }
    return;
  }

  function handleFailAckPackage(uint8, bytes calldata) external onlyCrossChainContract onlyInit override {
    emit crashResponse();
    return;
  }

  /*********************** External func ********************************/
  function slash(address validator) external onlyCoinbase onlyInit oncePerBlock onlyZeroGasPrice{
    if (!IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).isCurrentValidator(validator)) {
      return;
    }
    Indicator memory indicator = indicators[validator];
    if (indicator.exist) {
      indicator.count++;
    } else {
      indicator.exist = true;
      indicator.count = 1;
      validators.push(validator);
    }
    indicator.height = block.number;
    if (indicator.count % felonyThreshold == 0) {
      indicator.count = 0;
      IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(validator);
      ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(SLASH_CHANNELID, encodeSlashPackage(validator), 0);
    } else if (indicator.count % misdemeanorThreshold == 0) {
      IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).misdemeanor(validator);
    }
    indicators[validator] = indicator;
    emit validatorSlashed(validator);
  }


  // To prevent validator misbehaving and leaving, do not clean slash record to zero, but decrease by felonyThreshold/DECREASE_RATE .
  // Clean is an effective implement to reorganize "validators" and "indicators".
  function clean() external override(ISlashIndicator) onlyValidatorContract onlyInit{
    if(validators.length == 0){
      return;
    }
    uint i = 0;
    uint j = validators.length-1;
    for (;i <= j;) {
      bool findLeft = false;
      bool findRight = false;
      for(;i<j;i++){
        Indicator memory leftIndicator = indicators[validators[i]];
        if(leftIndicator.count > felonyThreshold/DECREASE_RATE){
          leftIndicator.count = leftIndicator.count - felonyThreshold/DECREASE_RATE;
          indicators[validators[i]] = leftIndicator;
        }else{
          findLeft = true;
          break;
        }
      }
      for(;i<=j;j--){
        Indicator memory rightIndicator = indicators[validators[j]];
        if(rightIndicator.count > felonyThreshold/DECREASE_RATE){
          rightIndicator.count = rightIndicator.count - felonyThreshold/DECREASE_RATE;
          indicators[validators[j]] = rightIndicator;
          findRight = true;
          break;
        }else{
          delete indicators[validators[j]];
          validators.pop();
        }
        // avoid underflow
        if(j==0){
          break;
        }
      }
      // swap element in array
      if (findLeft && findRight){
        delete indicators[validators[i]];
        validators[i] = validators[j];
        validators.pop();
      }
      // avoid underflow
      if(j==0){
        break;
      }
      // move to next
      i++;
      j--;
    }
    emit indicatorCleaned();
  }

  function handleFinalityReport(FinalityEvidence calldata _evidence) external onlyInit oncePerBlock noReentrant {
    uint256 _numA = _evidence.numA;
    uint256 _numB = _evidence.numB;


    require(_numA + finalityDistance >= _numB || _numB + finalityDistance >= _numA, "too long distance between blocks");
    require(
      _numA <= block.number() && _numA + 256 >= block.number() && _numB <= block.number() && _numB + 256 >= block.number(),
      "block number out of range"
    );

    uint256 index = IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).currentValidatorSetMap(_evidence.valAddr);
    require(index > 0, "validator not exist")
    ( , , , , , , bytes memory BLSKey) = IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).currentValidatorSet(index - 1)

    bytes[7] memory input;

    input[0] = TypesToBytes.uintToBytes(_evidence.numA);
    input[1] = TypesToBytes.bytes32ToBytes(_evidence.headerA);
    input[2] = TypesToBytes.uintToBytes(_evidence.numB);
    input[3] = TypesToBytes.bytes32ToBytes(_evidence.headerB);
    input[4] = _evidence.sigA;
    input[5] = _evidence.sigB;
    input[6] = BLSKey;

    assembly {
      if iszero(call(not(0), 0x13, 0, input, 0xe0, _, 0x20)) {
        revert(0, 0)
      }
    }

    bytes _headerA = blockhash(_numA);
    bytes _headerB = blockhash(_numB);

    if (_headerA != _evidence.headerA && _headerB != _evidence.headerB) {
      revert(string(abi.encodePacked("invalid header")));
    } else if (_headerA == _evidence.headerA && _headerB == _evidence.headerB) {
      revert(string(abi.encodePacked("invalid evidence")));
    } else {
      uint256 amount = (address(SYSTEM_REWARD_ADDR).balance * finalityRewardRatio) / 100;
      ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(msg.sender, amount);
      IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(_evidence.valAddr);
      ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(SLASH_CHANNELID, encodeSlashPackage(_evidence.valAddr), 0);
      emit validatorSlashed(_evidence.valAddr);
    }
  }

  function sendFelonyPackage(address validator) external override(ISlashIndicator) onlyValidatorContract onlyInit {
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(SLASH_CHANNELID, encodeSlashPackage(validator), 0);
  }

  /*********************** Param update ********************************/
  function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov{
    if (Memory.compareStrings(key,"misdemeanorThreshold")) {
      require(value.length == 32, "length of misdemeanorThreshold mismatch");
      uint256 newMisdemeanorThreshold = BytesToTypes.bytesToUint256(32, value);
      require(newMisdemeanorThreshold >= 1 && newMisdemeanorThreshold < felonyThreshold, "the misdemeanorThreshold out of range");
      misdemeanorThreshold = newMisdemeanorThreshold;
    } else if (Memory.compareStrings(key,"felonyThreshold")) {
      require(value.length == 32, "length of felonyThreshold mismatch");
      uint256 newFelonyThreshold = BytesToTypes.bytesToUint256(32, value);
      require(newFelonyThreshold <= 1000 && newFelonyThreshold > misdemeanorThreshold, "the felonyThreshold out of range");
      felonyThreshold = newFelonyThreshold;
    } else if (Memory.compareStrings(key, "finalityDistance")) {
      require(value.length == 32, "length of finalityDistance mismatch");
      uint256 newFinalityDistance = BytesToTypes.bytesToUint256(32, value);
      require(newFinalityDistance >= 1 && newFinalityDistance <= 21, "the finality distance out of range");
      finalityDistance = newFinalityDistance;
    } else if (Memory.compareStrings(key, "finalityRewardRatio")) {
      require(value.length == 32, "length of finalityRewardRatio mismatch");
      uint256 newFinalityRewardRatio = BytesToTypes.bytesToUint256(32, value);
      require(newFinalityRewardRatio >= 10 && newFinalityRewardRatio < 100, "the finality reward ratio out of range");
      finalityRewardRatio = newFinalityRewardRatio;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key,value);
  }

  /*********************** query api ********************************/
  function getSlashIndicator(address validator) external view returns (uint256,uint256) {
    Indicator memory indicator = indicators[validator];
    return (indicator.height, indicator.count);
  }

  function encodeSlashPackage(address valAddr) internal view returns (bytes memory) {
    bytes[] memory elements = new bytes[](4);
    elements[0] = valAddr.encodeAddress();
    elements[1] = uint256(block.number).encodeUint();
    elements[2] = uint256(bscChainID).encodeUint();
    elements[3] = uint256(block.timestamp).encodeUint();
    return elements.encodeList();
  }

  function getSlashThresholds() override(ISlashIndicator) external view returns (uint256, uint256) {
    return (misdemeanorThreshold, felonyThreshold);
  }
}
