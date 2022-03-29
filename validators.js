const web3 = require("web3")
const RLP = require('rlp');

// Configure
const validators = [
  {
    consensusAddr: "0x9fB29AAc15b9A4B7F17c3385939b007540f4d791",
    feeAddr: "0x9fB29AAc15b9A4B7F17c3385939b007540f4d791",
    bscFeeAddr: "0x9fB29AAc15b9A4B7F17c3385939b007540f4d791",
    votingPower: 0x0000000000000064
  }
];
const bLSPublicKeys = [
  "0xa3c03b91d566e1a790a54393818230b35c01102456a3c4d59995d110a9ee3c2035c2c1594b198e2172d4130970706318",
];

// ===============  Do not edit below ====
function generateExtradata(validators, bLSPublicKeys) {
  let extraVanity = Buffer.alloc(32);
  let validatorsBytes = extraDataSerialize(validators, bLSPublicKeys);
  let extraSeal = Buffer.alloc(65);
  return Buffer.concat([extraVanity, validatorsBytes, extraSeal]);
}

function extraDataSerialize(validators, bLSPublicKeys) {
  let n = validators.length;
  let arr = [];
  for (let i = 0; i < n; i++) {
    let validator = validators[i];
    let BLSPublicKey = bLSPublicKeys[i];
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.consensusAddr)));
    arr.push(Buffer.from(web3.utils.hexToBytes(BLSPublicKey)));
  }
  return Buffer.concat(arr);
}

function validatorUpdateRlpEncode(validators, bLSPublicKeys) {
  let n = validators.length;
  let vals = [];
  for (let i = 0; i < n; i++) {
    vals.push([
      validators[i].consensusAddr,
      validators[i].bscFeeAddr,
      validators[i].feeAddr,
      validators[i].votingPower,
      bLSPublicKeys[i]
    ]);
  }
  let pkg = [0x00, vals];
  return web3.utils.bytesToHex(RLP.encode(pkg));
}

extraValidatorBytes = generateExtradata(validators, bLSPublicKeys);
validatorSetBytes = validatorUpdateRlpEncode(validators, bLSPublicKeys);

exports = module.exports = {
  extraValidatorBytes: extraValidatorBytes,
  validatorSetBytes: validatorSetBytes,
};