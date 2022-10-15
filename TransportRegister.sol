// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Strings.sol";

contract TransportRegister {
        
    address public owner;

    // usado para gerar hashes dos pacotes
    uint256 public packagesCount;

    // struct básica de endereço
    struct StreetAddress {
        string name;
        string district;
        string city;
        string state;
        string number;
    }

    // struct principal do Package 
    struct Package {
        string packageId;
        string description;
        address sender;
        address receiver;
        StreetAddress deliveryAddress;
        bool complete;
        bool exists;
    }

    // DTO de entrada do pacote
    struct PackageData {
        string description;
        StreetAddress deliveryAddress;
    }

    // DTO do status do pacote
    struct PackageStatus {
        string statusMessage;
        bool isCompleted;
    }

    // Mappings
 
    mapping(address =>  string[]) sendersPackages;

    mapping(address =>  string[]) receiversPackages;

    mapping(string => Package) packagesIndex;

    //  Modifiers

    modifier isReceiver(string calldata packageId) {
        bool result = false;
        string[] memory packagesList = receiversPackages[msg.sender];

        for (uint i=0; i < packagesList.length; i++) {
            if (keccak256(bytes(packageId)) == keccak256(bytes(packagesList[i]))) {
                result = true;
                break;
            }
        }

        require(result , "Somente o destinatario do pacote pode executar essa operacao!");
        _;
    }

    modifier isSender(string calldata packageId) {
        bool result = false;
        string[] memory packagesList = sendersPackages[msg.sender];

        for (uint i=0; i < packagesList.length; i++) {
            if (keccak256(bytes(packageId)) == keccak256(bytes(packagesList[i]))) {
                result = true;
                break;
            }
        }

        require(result , "Somente o destinatario do pacote pode executar essa operacao!");
        _;
    }

    modifier isReceiverOrSender(string calldata packageId) {
        bool result = false;
        Package memory package = packagesIndex[packageId];

        
        if (package.exists) {
            if (msg.sender == package.sender || msg.sender == package.receiver) {
                result = true;
            }
        }

        require(result , "Somente o remente ou o destinatario do pacote podem executar essa operacao!");
        _;
    }
    
    constructor () {
        owner = msg.sender;

        packagesCount = 0;
    }

    // função que gera hash de id para um pacote com base no endereço do remetente e de um número sequencial
    function getPackageHashId(address senderAddress, uint256 number) private pure returns (string memory) {
        uint rand = uint(keccak256(abi.encodePacked(senderAddress, number)));
        return Strings.toString(rand);
    }

    // registrar um novo pacote, torna o sender da mensagem o remetente do pacote
    function registerPackage(PackageData calldata packageData, address receiver) public returns (string memory){
        
        // novo id
        string memory packageHashId = getPackageHashId(msg.sender, packagesCount);
        
        // objeto do pacote
        Package memory newPackage = Package({
            packageId: packageHashId,
            description: packageData.description,
            sender: msg.sender,
            receiver: receiver,
            deliveryAddress: packageData.deliveryAddress,
            complete: false,
            exists: true
        });


        // relaciona o rementente com o id do pacote        
        sendersPackages[msg.sender].push(packageHashId);

        // relaciona o destinatario com o id do pacote
        receiversPackages[receiver].push(packageHashId);

        // adiciona o pacote ao indice
        packagesIndex[packageHashId] = newPackage;

        packagesCount += 1;

        return packageHashId;

    }

    function getPackage(string calldata packageId) public view isReceiverOrSender(packageId) returns (Package memory) {
        Package memory package = packagesIndex[packageId];

        // retorna o pacote inteiro
        if (package.exists) {
            return package;
        }

        revert("Not found");
    } 

    function getPackageStatus(string calldata packageId) public view isReceiverOrSender(packageId) returns (PackageStatus memory){
        Package memory package = packagesIndex[packageId];
 
        // retorna o ultimo endereco registrado e o status do pacote como completo ou em rota
        if (package.exists) {
            if (package.complete) {
                return PackageStatus({
                  statusMessage: "Completed",
                  isCompleted: true
                });
            }
            
            return PackageStatus({
                statusMessage: "En route",
                isCompleted: false
            });
        }

        revert("Not found");
    } 

/*
    function getPackageTracking(string calldata packageId) public isReceiverOrSender(packageId) returns (StreetAddress[] memory){
        Package memory package = packagesIndex[packageId];

        // retorna a lista de enderecos por onde o pacote ja passou
        if (package.exists) { 
            return package.route;
        }

        revert("Not found");
    } 
*/
/*    // atualiza a rota do pacote
    function updatePackageRoute(string calldata packageId, StreetAddress calldata newAddress) public isSender(packageId) {
        Package storage package = packagesIndex[packageId];

        // atualiza e salva
        if (package.exists) {
            package.route.push(newAddress);

            packagesIndex[packageId] = package;
        }

        revert("Not found");

    } 
*/

    // confirma a entrega do pacote
    function confirmPackageDelivery(string calldata packageId) public isReceiver(packageId) {
        Package storage package = packagesIndex[packageId];

        // atualiza e salva
        if (package.exists) {
            package.complete = true;

            packagesIndex[packageId] = package;
        }

        revert("Not found");

    }

    // retorna todos os pacotes enviados pelo sender da mensagem
    function listMySentPackages() public view returns (Package[] memory) {
        string[] memory packagesIds = sendersPackages[msg.sender];

        if (packagesIds.length > 0) {
            Package[] memory packages = new Package[](packagesIds.length);
            for (uint i=0; i < packagesIds.length; i++) {
                Package memory package = packagesIndex[packagesIds[i]];
                
                packages[i] = package;
            }

            return packages;
        }

        revert("No packages sent found");
    }

    // retorna todos os pacotes a receber pelo sender da mensagem
    function listMyWaitingPackages() public view returns (Package[] memory) {
        string[] memory packagesIds = receiversPackages[msg.sender];

        if (packagesIds.length > 0) {
            Package[] memory packages = new Package[](packagesIds.length);
            for (uint i=0; i < packagesIds.length; i++) {
                Package memory package = packagesIndex[packagesIds[i]];
                
                packages[i] = package;
            }

            return packages;
        }
        revert("No packages to receive found");
    }
}
