const web3 = require("web3")
const RLP = require('rlp');

// Configure
const validators = [
  
   {
     "consensusAddr": "0x14DE643980726167f9772623ce337940Bc2b0Aa0",
     "feeAddr": "0x14DE643980726167f9772623ce337940Bc2b0Aa0",
     "bscFeeAddr": "0x14DE643980726167f9772623ce337940Bc2b0Aa0",
     "votingPower": 0x0000000010000000,
   },
   {
     "consensusAddr": "0x3c2a0A9690A247c4DDc6f68EE5A41522996923DB",
     "feeAddr": "0x3c2a0A9690A247c4DDc6f68EE5A41522996923DB",
     "bscFeeAddr": "0x3c2a0A9690A247c4DDc6f68EE5A41522996923DB",
     "votingPower": 0x0000000010000000,
   },
   {
     "consensusAddr": "0x2b7C653375F4346336760A8066A6c871Aee70951",
     "feeAddr": "0x2b7C653375F4346336760A8066A6c871Aee70951",
     "bscFeeAddr": "0x2b7C653375F4346336760A8066A6c871Aee70951",
     "votingPower": 0x0000000010000000,
   },
];
const bLSPublicKeys = [
  
   "0x85e6972fc98cd3c81d64d40e325acfed44365b97a7567a27939c14dbc7512ddcf54cb1284eb637cfa308ae4e00cb5588",
   "0x8addebd6ef7609df215e006987040d0a643858f3a4d791beaa77177d67529160e645fac54f0d8acdcd5a088393cb6681",
   "0x89abcc45efe76bec679ca35c27adbd66fb9712a278e3c8530ab25cfaf997765aee574f5c5745dbb873dbf7e961684347",
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