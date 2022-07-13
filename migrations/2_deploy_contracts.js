const FreeLancerContract = artifacts.require("FreeLancerContract");

module.exports = function(deployer) {
  deployer.deploy(FreeLancerContract);
};
