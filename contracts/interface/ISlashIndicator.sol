pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

interface ISlashIndicator {
  struct FinalityEvidence {
    uint256 numA;
    bytes32 headerA;
    bytes sigA;
    uint256 numB;
    bytes32 headerB;
    bytes sigB;
    address valAddr;
  }
  function clean() external;
  function sendFelonyPackage(address validator) external;
  function getSlashThresholds() external view returns (uint256, uint256);
  function submitFinalityViolationEvidence(FinalityEvidence calldata _evidence) external onlyInit onlyRelayer;
}
