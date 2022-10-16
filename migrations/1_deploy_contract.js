const TransportRegister_Contract = artifacts.require("TransportRegister");

module.exports = function(deployer) {
  deployer.deploy(TransportRegister_Contract);
};
