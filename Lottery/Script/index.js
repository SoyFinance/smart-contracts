const Web3 = require('web3');
require('dotenv').config(); // if use .env file for environment variables
const {RandomNumberGenerator_ABI, SoyLottery_ABI} = require('./abi.js');

const pk = process.env.SYSTEM_PK;  // Private key should be hidden

