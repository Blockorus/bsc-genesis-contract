pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

interface IBSCValidatorSet {
  function misdemeanor(address validator) external;
  function felony(address validator) external;
  function isCurrentValidator(address validator) external view returns (bool);
  function getLivingValidators() external returns(address[] memory, bytes[] memory);
  function getMiningValidators() external returns(address[] memory, bytes[] memory);
}
